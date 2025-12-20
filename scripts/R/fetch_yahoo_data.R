#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(yaml)
  library(quantmod)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(lubridate)
  library(arrow)
  library(zoo)
})


a 

`%||%` <- function(x, y) if (is.null(x) || is.na(x) || identical(x, "")) y else x

option_list <- list(
  optparse::make_option(c("-c", "--config"), type = "character", default = "config/etf_universe.yml",
                        help = "Path to ETF universe config (YAML)."),
  optparse::make_option(c("-s", "--start"), type = "character", default = NA,
                        help = "Override start date (YYYY-MM-DD)."),
  optparse::make_option(c("-e", "--end"), type = "character", default = NA,
                        help = "Override end date (YYYY-MM-DD)."),
  optparse::make_option(c("-o", "--output-dir"), dest = "output_dir",
                        type = "character", default = "data/raw/yahoo",
                        help = "Directory to store parquet files.")
)

opts <- optparse::parse_args(optparse::OptionParser(option_list = option_list))

stopifnot(file.exists(opts$config))
if (!dir.exists(opts$output_dir)) dir.create(opts$output_dir, recursive = TRUE)

cfg <- yaml::read_yaml(opts$config)
universe <- cfg$universe

if (is.null(universe) || length(universe) == 0) {
  stop("ETF universe config is empty; nothing to download.")
}

fetch_symbol <- function(entry) {
  symbol <- entry$yahoo_symbol %||% entry$ticker
  start_date <- opts$start %||% entry$start_date %||% "2000-01-01"
  end_date <- opts$end

  message(sprintf("Downloading %s from %s", symbol, start_date))
  xt <- quantmod::getSymbols(Symbols = symbol, src = "yahoo", auto.assign = FALSE,
                             from = start_date, to = end_date)
  df <- tibble::tibble(
    date = lubridate::as_date(zoo::index(xt)),
    open = as.numeric(xt[, 1]),
    high = as.numeric(xt[, 2]),
    low = as.numeric(xt[, 3]),
    close = as.numeric(xt[, 4]),
    adjusted = as.numeric(xt[, 6]),
    volume = as.numeric(xt[, 5])
  ) %>%
    dplyr::mutate(ticker = entry$ticker, yahoo_symbol = symbol) %>%
    dplyr::select(ticker, yahoo_symbol, date, dplyr::everything())

  output_file <- file.path(opts$output_dir, paste0(entry$ticker, ".parquet"))
  arrow::write_parquet(df, output_file)
  message(sprintf("Saved %s (%d rows)", output_file, nrow(df)))
  invisible(df)
}

purrr::walk(universe, fetch_symbol)
