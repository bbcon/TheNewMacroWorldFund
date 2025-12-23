#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(dplyr)
  library(lubridate)
  library(readr)
  library(purrr)
  library(arrow)
  library(tidyr)
})

read_price_returns <- function(ticker, price_dir, cash_ticker) {
  if (!dir.exists(price_dir)) {
    stop("Price directory not found: ", price_dir)
  }
  if (ticker == cash_ticker) {
    return(tibble::tibble(ticker = ticker, date = NA, return = NA) %>% dplyr::filter(FALSE))
  }
  file_path <- file.path(price_dir, paste0(ticker, ".parquet"))
  if (!file.exists(file_path)) {
    stop("Missing price file for ticker ", ticker, ". Expected at ", file_path)
  }
  arrow::read_parquet(file_path) %>%
    dplyr::mutate(date = lubridate::as_date(date)) %>%
    dplyr::arrange(date) %>%
    dplyr::mutate(return = adjusted / dplyr::lag(adjusted) - 1) %>%
    dplyr::select(date, return) %>%
    dplyr::filter(!is.na(return)) %>%
    dplyr::mutate(ticker = ticker)
}

run_trade_performance <- function(trade_id,
                                  long_ticker,
                                  short_ticker = "CASH",
                                  entry_date,
                                  exit_date = NA,
                                  price_dir = "data/raw/yahoo",
                                  output_dir = "data/outputs/performance/trades",
                                  cash_ticker = "CASH") {
  if (is.null(trade_id) || trade_id == "") stop("trade_id is required")
  if (is.null(long_ticker) || long_ticker == "") stop("long_ticker is required")
  entry_date <- lubridate::as_date(entry_date)
  if (is.na(entry_date)) stop("entry_date is required")
  exit_date <- ifelse(is.na(exit_date) || exit_date == "", NA, lubridate::as_date(exit_date))

  long_df <- read_price_returns(long_ticker, price_dir, cash_ticker)
  if (nrow(long_df) == 0) {
    stop("No return history for long ticker ", long_ticker)
  }

  if (short_ticker == cash_ticker) {
    short_df <- tibble::tibble(
      date = long_df$date,
      return = 0,
      ticker = short_ticker
    )
  } else {
    short_df <- read_price_returns(short_ticker, price_dir, cash_ticker)
  }

  if (nrow(short_df) == 0) {
    stop("No return history for short ticker ", short_ticker)
  }

  if (is.na(exit_date)) {
    exit_date <- min(max(long_df$date), max(short_df$date), na.rm = TRUE)
  }

  trade_returns <- long_df %>%
    dplyr::rename(long_return = return) %>%
    dplyr::inner_join(
      short_df %>% dplyr::rename(short_return = return),
      by = "date"
    ) %>%
    dplyr::filter(date >= entry_date, date <= exit_date) %>%
    dplyr::arrange(date) %>%
    dplyr::mutate(
      spread_return = long_return - short_return,
      spread_nav = cumprod(1 + tidyr::replace_na(spread_return, 0)),
      peak_nav = cummax(spread_nav),
      drawdown = spread_nav / peak_nav - 1
    )

  if (nrow(trade_returns) == 0) {
    stop("No overlapping return history between entry and exit dates.")
  }

  summary_tbl <- tibble::tibble(
    trade_id = trade_id,
    long_ticker = long_ticker,
    short_ticker = short_ticker,
    entry_date = entry_date,
    exit_date = exit_date,
    days_held = nrow(trade_returns),
    long_total_return = prod(1 + trade_returns$long_return, na.rm = TRUE) - 1,
    short_total_return = prod(1 + trade_returns$short_return, na.rm = TRUE) - 1,
    spread_total_return = prod(1 + trade_returns$spread_return, na.rm = TRUE) - 1,
    max_drawdown = min(trade_returns$drawdown, na.rm = TRUE)
  )

  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  daily_path <- file.path(output_dir, paste0(trade_id, "_daily.csv"))
  summary_path <- file.path(output_dir, paste0(trade_id, "_summary.csv"))

  readr::write_csv(trade_returns, daily_path)
  readr::write_csv(summary_tbl, summary_path)

  message("Daily analytics written to ", daily_path)
  message("Summary analytics written to ", summary_path)

  invisible(list(daily = trade_returns, summary = summary_tbl, daily_path = daily_path, summary_path = summary_path))
}

if (sys.nframe() == 0) {
  option_list <- list(
    optparse::make_option(c("--trade-id"), dest = "trade_id", type = "character",
                          help = "Unique trade identifier used in output filenames."),
    optparse::make_option(c("--long"), dest = "long_ticker", type = "character",
                          help = "Ticker used for the long leg."),
    optparse::make_option(c("--short"), dest = "short_ticker", type = "character", default = "CASH",
                          help = "Ticker used for the short leg (default CASH=0 return)."),
    optparse::make_option(c("--entry"), dest = "entry_date", type = "character",
                          help = "Entry date (YYYY-MM-DD)."),
    optparse::make_option(c("--exit"), dest = "exit_date", type = "character", default = NA,
                          help = "Exit date (YYYY-MM-DD). Omit for open trades."),
    optparse::make_option(c("-p", "--price-dir"), dest = "price_dir", type = "character",
                          default = "data/raw/yahoo",
                          help = "Directory containing parquet price files."),
    optparse::make_option(c("-o", "--output-dir"), dest = "output_dir", type = "character",
                          default = "data/outputs/performance/trades",
                          help = "Directory where trade analytics will be written."),
    optparse::make_option(c("--cash-ticker"), dest = "cash_ticker", type = "character", default = "CASH",
                          help = "Synthetic ticker name to treat as 0 return.")
  )

  opts <- optparse::parse_args(optparse::OptionParser(option_list = option_list))

  run_trade_performance(
    trade_id = opts$trade_id,
    long_ticker = opts$long_ticker,
    short_ticker = opts$short_ticker,
    entry_date = opts$entry_date,
    exit_date = opts$exit_date,
    price_dir = opts$price_dir,
    output_dir = opts$output_dir,
    cash_ticker = opts$cash_ticker
  )
}
