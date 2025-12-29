#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(yaml)
  library(DatastreamDSWS2R)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(lubridate)
  library(arrow)
  library(tibble)
  library(stringr)
  library(xts)
  library(zoo)
})

`%||%` <- function(x, y) if (is.null(x) || is.na(x) || identical(x, "")) y else x

option_list <- list(
  optparse::make_option(c("-c", "--config"), type = "character",
                        default = "config/instruments/etf_universe_datastream.yml",
                        help = "YAML config with Datastream universe."),
  optparse::make_option(c("-s", "--start"), type = "character", default = NA,
                        help = "Override start date (YYYY-MM-DD)."),
  optparse::make_option(c("-e", "--end"), type = "character", default = NA,
                        help = "Override end date (YYYY-MM-DD)."),
  optparse::make_option(c("-o", "--output"), dest = "output",
                        type = "character", default = "data/raw/datastream/raw_series.parquet",
                        help = "Parquet path for combined raw series."),
  optparse::make_option(c("--per-ticker-dir"), dest = "per_ticker_dir",
                        type = "character", default = NA,
                        help = "Optional directory to also store one parquet per ticker.")
)

opts <- optparse::parse_args(optparse::OptionParser(option_list = option_list))

dsws_username <- Sys.getenv("DSWS_USERNAME")
dsws_password <- Sys.getenv("DSWS_PASSWORD")
if (dsws_username != "" && dsws_password != "") {
  options(Datastream.Username = dsws_username, Datastream.Password = dsws_password)
} else {
  stop("Datastream credentials missing: set DSWS_USERNAME and DSWS_PASSWORD.")
}

cfg <- yaml::read_yaml(opts$config)
universe <- cfg$universe
price_field_default <- cfg$price_field %||% "P"
frequency <- cfg$frequency %||% "daily"

if (is.null(universe) || length(universe) == 0) {
  stop("Universe in config is empty: ", opts$config)
}

start_override <- opts$start
end_override <- opts$end

if (!dir.exists(dirname(opts$output))) dir.create(dirname(opts$output), recursive = TRUE)
if (!is.na(opts$per_ticker_dir) && !dir.exists(opts$per_ticker_dir)) {
  dir.create(opts$per_ticker_dir, recursive = TRUE)
}

ds <- DatastreamDSWS2R::dsws$new()

extract_ts <- function(res) {
  if (xts::is.xts(res)) {
    return(tibble::tibble(
      date = lubridate::as_date(zoo::index(res)),
      raw_value = as.numeric(res[, 1])
    ))
  }

  df <- tibble::as_tibble(res)
  date_col <- names(df)[stringr::str_detect(names(df), regex("^date$", ignore_case = TRUE))][1] %||% names(df)[1]
  value_cols <- setdiff(names(df), date_col)
  if (length(value_cols) == 0) stop("No value column detected in Datastream response.")
  tibble::tibble(
    date = lubridate::as_date(df[[date_col]]),
    raw_value = as.numeric(df[[value_cols[1]]])
  )
}

fetch_series <- function(dsws, ticker, field, start_date, end_date, freq) {
  instrument_expr <- sprintf("%s(%s)", ticker, field)
  res <- dsws$timeSeriesRequest(
    instrument = instrument_expr,
    startDate = start_date,
    endDate = end_date,
    frequency = toupper(substr(freq, 1, 1))
  )
  extract_ts(res)
}

raw_rows <- purrr::map_dfr(universe, function(entry) {
  ticker <- entry$ticker
  ds_ticker <- entry$datastream_ticker %||% ticker
  field <- entry$price_field %||% price_field_default
  start_date <- start_override %||% entry$start_date %||% "2000-01-01"
  end_date <- end_override
  currency <- entry$currency %||% entry$quote_currency %||% NA_character_

  message(sprintf("Fetching %s (%s) from %s", ticker, ds_ticker, start_date))
  ts_df <- fetch_series(
    dsws = ds,
    ticker = ds_ticker,
    field = field,
    start_date = start_date,
    end_date = end_date,
    freq = frequency
  ) %>%
    dplyr::arrange(date) %>%
    dplyr::mutate(
      ticker = ticker,
      datastream_ticker = ds_ticker,
      asset_class = entry$asset_class %||% NA_character_,
      price_field = field,
      currency = currency,
      base_currency = entry$base_currency %||% ifelse(entry$asset_class == "fx", "USD", NA_character_),
      quote_currency = entry$quote_currency %||% currency,
      start_date_config = entry$start_date %||% NA_character_,
      download_ts = Sys.time(),
      source = "datastream",
      frequency = frequency
    ) %>%
    dplyr::select(
      ticker, datastream_ticker, asset_class, price_field,
      currency, base_currency, quote_currency,
      date, raw_value, source, frequency, start_date_config, download_ts
    )

  message(sprintf("Fetched %s: %d rows", ticker, nrow(ts_df)))

  if (!is.na(opts$per_ticker_dir)) {
    arrow::write_parquet(ts_df, file.path(opts$per_ticker_dir, paste0(ticker, ".parquet")))
  }

  ts_df
})

arrow::write_parquet(raw_rows, opts$output)

message("Raw Datastream series written to ", opts$output)
if (!is.na(opts$per_ticker_dir)) {
  message("Per-ticker parquet files written to ", opts$per_ticker_dir)
}
