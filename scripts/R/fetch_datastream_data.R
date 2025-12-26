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
  library(stringr)
  library(tibble)
  library(xts)
  library(zoo)
})

`%||%` <- function(x, y) if (is.null(x) || is.na(x) || identical(x, "")) y else x

# Credentials: set DSWS_USERNAME and DSWS_PASSWORD in the environment (e.g., via
# GitHub Actions secrets) before running this script.
dsws_username <- Sys.getenv("DSWS_USERNAME")
dsws_password <- Sys.getenv("DSWS_PASSWORD")
if (dsws_username != "" && dsws_password != "") {
  options(Datastream.Username = dsws_username, Datastream.Password = dsws_password)
}
if (dsws_username == "" || dsws_password == "") {
  stop("Datastream credentials missing: set DSWS_USERNAME and DSWS_PASSWORD in the environment.")
}

option_list <- list(
  optparse::make_option(c("-c", "--config"), type = "character",
                        default = "config/instruments/etf_universe_datastream.yml",
                        help = "Path to Datastream universe config (YAML)."),
  optparse::make_option(c("-s", "--start"), type = "character", default = NA,
                        help = "Override start date (YYYY-MM-DD)."),
  optparse::make_option(c("-e", "--end"), type = "character", default = NA,
                        help = "Override end date (YYYY-MM-DD)."),
  optparse::make_option(c("-o", "--output-dir"), dest = "output_dir",
                        type = "character", default = "data/raw/datastream",
                        help = "Directory to store parquet files.")
)

opts <- optparse::parse_args(optparse::OptionParser(option_list = option_list))

stopifnot(file.exists(opts$config))
if (!dir.exists(opts$output_dir)) dir.create(opts$output_dir, recursive = TRUE)

cfg <- yaml::read_yaml(opts$config)
universe <- cfg$universe
price_field <- cfg$price_field %||% "P"
frequency <- cfg$frequency %||% "daily"

if (is.null(universe) || length(universe) == 0) {
  stop("Datastream universe config is empty; nothing to download.")
}

ds <- DatastreamDSWS2R::dsws$new()

# Convert various return shapes from DSWS into a tidy tibble with date/value.
extract_ts <- function(res) {
  if (xts::is.xts(res)) {
    df <- tibble::tibble(
      date = lubridate::as_date(zoo::index(res)),
      value = as.numeric(res[, 1])
    )
    return(dplyr::arrange(df, date))
  }

  df <- tibble::as_tibble(res)
  date_col <- names(df)[stringr::str_detect(names(df), regex("^date$", ignore_case = TRUE))][1] %||% names(df)[1]
  value_cols <- setdiff(names(df), date_col)
  if (length(value_cols) == 0) stop("No value column detected in Datastream response.")
  value_col <- value_cols[1]

  df %>%
    dplyr::rename(date = !!date_col, value = !!value_col) %>%
    dplyr::mutate(date = lubridate::as_date(date)) %>%
    dplyr::arrange(date)
}

fetch_series <- function(dsws, ticker, field, start_date, end_date, freq) {
  instrument_expr <- sprintf("%s(%s)", ticker, field)
  res <- dsws$timeSeriesRequest(
    instrument = instrument_expr,
    startDate = start_date,
    endDate = end_date,
    frequency = toupper(substr(freq, 1, 1)) # D/W/M...
  )
  extract_ts(res)
}

start_override <- opts$start
end_override <- opts$end

fx_entries <- purrr::keep(universe, ~ .x$asset_class == "fx")

message("Fetching FX series for USD conversions...")
fx_series <- purrr::map(fx_entries, function(entry) {
  fx_df <- fetch_series(
    dsws = ds,
    ticker = entry$datastream_ticker,
    field = price_field,
    start_date = start_override %||% entry$start_date %||% "2000-01-01",
    end_date = end_override,
    freq = frequency
  )
  fx_df <- fx_df %>% dplyr::rename(fx_rate = value)
  list(
    quote_currency = entry$quote_currency %||% entry$currency,
    base_currency = entry$base_currency %||% "USD",
    data = fx_df
  )
})

fx_lookup <- purrr::map(fx_series, ~ .x) %>% setNames(map_chr(fx_series, "quote_currency"))

fetch_and_save <- function(entry) {
  ticker <- entry$ticker
  ds_ticker <- entry$datastream_ticker %||% ticker
  start_date <- start_override %||% entry$start_date %||% "2000-01-01"
  end_date <- end_override
  currency <- entry$currency %||% entry$quote_currency %||% "USD"

  message(sprintf("Downloading %s (%s) from %s", ticker, ds_ticker, start_date))
  ts_df <- fetch_series(
    dsws = ds,
    ticker = ds_ticker,
    field = price_field,
    start_date = start_date,
    end_date = end_date,
    freq = frequency
  ) %>%
    dplyr::rename(price_local = value) %>%
    dplyr::mutate(currency = currency)

  if (entry$asset_class == "fx") {
    ts_df <- ts_df %>%
      dplyr::mutate(
        price_usd = price_local,
        return_usd = price_usd / dplyr::lag(price_usd) - 1
      )
  } else if (currency == "USD") {
    ts_df <- ts_df %>%
      dplyr::mutate(
        price_usd = price_local,
        return_usd = price_usd / dplyr::lag(price_usd) - 1
      )
  } else {
    fx_for_ccy <- fx_lookup[[currency]]
    if (is.null(fx_for_ccy)) {
      stop(sprintf("Missing FX pair for currency %s; add it to the universe as USD/%s", currency, currency))
    }
    if (!identical(fx_for_ccy$base_currency, "USD")) {
      stop(sprintf("FX pair for %s must have base_currency USD to compute USD prices.", currency))
    }
    ts_df <- ts_df %>%
      dplyr::left_join(fx_for_ccy$data, by = "date") %>%
      dplyr::mutate(
        price_usd = price_local * fx_rate,
        return_usd = price_usd / dplyr::lag(price_usd) - 1
      )
  }

  output_file <- file.path(opts$output_dir, paste0(ticker, ".parquet"))
  arrow::write_parquet(
    ts_df %>% dplyr::mutate(ticker = ticker, datastream_ticker = ds_ticker) %>%
      dplyr::select(ticker, datastream_ticker, date, currency, price_local, price_usd, return_usd, dplyr::everything()),
    output_file
  )
  message(sprintf("Saved %s (%d rows)", output_file, nrow(ts_df)))
  invisible(ts_df)
}

non_fx_entries <- purrr::discard(universe, ~ .x$asset_class == "fx")
purrr::walk(non_fx_entries, fetch_and_save)

message("Done.")
