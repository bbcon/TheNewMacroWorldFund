#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(lubridate)
})

source(file.path("scripts", "R", "trade_performance.R"))

weights_file <- Sys.getenv("TAA_WEIGHTS_FILE", unset = "data/reference/taa_weights_history.csv")
price_dir <- Sys.getenv("PRICE_DIR", unset = "data/raw/yahoo")
output_dir <- Sys.getenv("OUTPUT_DIR", unset = "data/outputs/performance/trades")
cash_ticker <- Sys.getenv("CASH_TICKER", unset = "CASH")

if (!file.exists(weights_file)) {
  stop("Weights file not found: ", weights_file)
}

weights <- readr::read_csv(weights_file, show_col_types = FALSE) %>%
  dplyr::filter(!is.na(trade_id) & trade_id != "")

if (nrow(weights) == 0) {
  stop("No trade_id rows found in ", weights_file)
}

trade_ids <- unique(weights$trade_id)

for (tid in trade_ids) {
  rows <- weights %>% dplyr::filter(trade_id == tid)

  entry_date <- suppressWarnings(lubridate::as_date(min(rows$effective_date)))
  exit_chr <- rows$exit_date
  if (inherits(exit_chr, "Date")) exit_chr <- as.character(exit_chr)
  exit_chr <- trimws(exit_chr)
  exit_vals <- exit_chr[!is.na(exit_chr) & exit_chr != "" & exit_chr != "Open"]
  exit_date_chr <- if (length(exit_vals)) exit_vals[1] else NA_character_
  exit_date <- suppressWarnings(lubridate::as_date(exit_date_chr))

  long_rows <- rows %>% dplyr::filter(weight > 0)
  short_rows <- rows %>% dplyr::filter(weight < 0)

  long_ticker <- if (nrow(long_rows)) long_rows %>% dplyr::arrange(dplyr::desc(weight)) %>% dplyr::pull(ticker) %>% .[1] else NA
  short_ticker <- if (nrow(short_rows)) short_rows %>% dplyr::arrange(weight) %>% dplyr::pull(ticker) %>% .[1] else NA

  weight_sum <- sum(rows$weight, na.rm = TRUE)

  missing <- c()
  if (is.na(entry_date)) missing <- c(missing, "entry_date")
  if (is.na(long_ticker) || long_ticker == "") missing <- c(missing, "long_ticker (>0 weight)")
  if (is.na(short_ticker) || short_ticker == "") missing <- c(missing, "short_ticker (<0 weight)")
  if (abs(weight_sum) > 1e-6) missing <- c(missing, "weights not zero-sum")

  if (length(missing)) {
    message("Skipping trade_id ", tid, " due to: ", paste(missing, collapse = ", "))
    next
  }

  message("Running trade_performance.R for ", tid, " (source: ", weights_file, ")")
  run_trade_performance(
    trade_id = tid,
    long_ticker = long_ticker,
    short_ticker = short_ticker,
    entry_date = entry_date,
    exit_date = exit_date,
    price_dir = price_dir,
    output_dir = output_dir,
    cash_ticker = cash_ticker
  )
}
