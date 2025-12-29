#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(readr)
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(purrr)
  library(arrow)
})

option_list <- list(
  optparse::make_option(c("-w", "--weights"), dest = "taa_weights", type = "character",
                        default = "data/reference/taa_weights_history.csv",
                        help = "CSV with historical TAA deviations (must sum to zero)."),
  optparse::make_option(c("--saa-weights"), dest = "saa_weights", type = "character",
                        default = "data/reference/saa_weights_history.csv",
                        help = "CSV with SAA baseline weights (must sum to one)."),
  optparse::make_option(c("-p", "--price-dir"), dest = "price_dir",
                        type = "character", default = "data/raw/datastream",
                        help = "Directory with price parquet files."),
  optparse::make_option(c("--price-format"), dest = "price_format",
                        type = "character", default = "datastream",
                        help = "Price format: datastream (price_usd/return_usd) or yahoo (adjusted)."),
  optparse::make_option(c("-o", "--output"), type = "character",
                        default = "data/outputs/performance/taa_portfolio_returns.parquet",
                        help = "Parquet path for aggregated portfolio returns."),
  optparse::make_option(c("--weights-log"), dest = "weights_log",
                        type = "character", default = "logs/tactical_trades/latest_weights.csv",
                        help = "Where to store the latest weights snapshot."),
  optparse::make_option(c("--cash-ticker"), dest = "cash_ticker",
                        type = "character", default = "CASH",
                        help = "Ticker used for the cash sleeve (assumed 0 return unless data provided).")
)

opts <- optparse::parse_args(optparse::OptionParser(option_list = option_list))

stopifnot(file.exists(opts$taa_weights))
stopifnot(file.exists(opts$saa_weights))
stopifnot(dir.exists(opts$price_dir))
if (!dir.exists(dirname(opts$output))) dir.create(dirname(opts$output), recursive = TRUE)
if (!dir.exists(dirname(opts$weights_log))) dir.create(dirname(opts$weights_log), recursive = TRUE)

price_format <- tolower(opts$price_format)
if (!price_format %in% c("datastream", "yahoo")) {
  stop("price-format must be either 'datastream' or 'yahoo'")
}

saa_weights <- readr::read_csv(opts$saa_weights, show_col_types = FALSE) %>%
  dplyr::mutate(effective_date = lubridate::as_date(effective_date))

saa_sums <- saa_weights %>%
  dplyr::group_by(strategy, effective_date) %>%
  dplyr::summarise(total_weight = sum(weight), .groups = "drop")

if (any(abs(saa_sums$total_weight - 1) > 1e-4)) {
  stop("SAA weights must sum to 1.0 for every effective date.")
}

taa_weights <- readr::read_csv(opts$taa_weights, show_col_types = FALSE) %>%
  dplyr::mutate(effective_date = lubridate::as_date(effective_date))

taa_sums <- taa_weights %>%
  dplyr::group_by(strategy, effective_date) %>%
  dplyr::summarise(total_weight = sum(weight), .groups = "drop")

if (any(abs(taa_sums$total_weight) > 1e-4)) {
  stop("TAA deviation weights must sum to zero for every effective date.")
}

price_files <- list.files(opts$price_dir, pattern = "\\.parquet$", full.names = TRUE)
if (length(price_files) == 0) {
  stop("No price files found in ", opts$price_dir, "; fetch data before building the portfolio.")
}

prices <- purrr::map_dfr(price_files, function(path) {
  ticker <- tools::file_path_sans_ext(basename(path))
  df <- arrow::read_parquet(path)
  df <- dplyr::mutate(df, ticker = ticker, date = lubridate::as_date(date))
  if (price_format == "datastream") {
    if (!("price_usd" %in% names(df))) {
      stop("Datastream price file missing price_usd: ", path)
    }
    df <- dplyr::arrange(df, date)
    if ("return_usd" %in% names(df)) {
      df <- dplyr::mutate(df, return = return_usd)
    } else {
      df <- dplyr::mutate(df, return = price_usd / dplyr::lag(price_usd) - 1)
    }
    dplyr::select(df, ticker, date, adjusted = price_usd, return)
  } else {
    if (!("adjusted" %in% names(df))) {
      stop("Yahoo price file missing adjusted column: ", path)
    }
    dplyr::arrange(df, date) %>%
      dplyr::group_by(ticker) %>%
      dplyr::mutate(return = adjusted / dplyr::lag(adjusted) - 1) %>%
      dplyr::ungroup() %>%
      dplyr::select(ticker, date, adjusted, return)
  }
})



start_date <- min(saa_weights$effective_date, na.rm = TRUE)
prices <- dplyr::filter(prices, date >= start_date)
calendar_dates <- tibble::tibble(date = sort(unique(prices$date)))
if (nrow(calendar_dates) == 0) {
  stop("No price dates available on/after the earliest SAA effective date.")
}

extend_weights <- function(df, fill_zeros = FALSE) {
  out <- df %>%
    dplyr::select(strategy, ticker, weight, effective_date) %>%
    dplyr::rename(date = effective_date) %>%
    dplyr::group_by(strategy, ticker) %>%
    tidyr::complete(date = calendar_dates$date) %>%
    dplyr::arrange(date, .by_group = TRUE) %>%
    tidyr::fill(weight, .direction = "down")
  if (fill_zeros) {
    out <- out %>% tidyr::replace_na(list(weight = 0))
  } else {
    out <- out %>% dplyr::filter(!is.na(weight))
  }
  dplyr::ungroup(out)
}

saa_daily <- extend_weights(saa_weights, fill_zeros = FALSE) %>%
  dplyr::rename(weight_saa = weight)

taa_daily <- extend_weights(taa_weights, fill_zeros = TRUE) %>%
  dplyr::rename(weight_taa = weight)

weights_combined <- dplyr::full_join(
  saa_daily, taa_daily,
  by = c("strategy", "ticker", "date")
) %>%
  dplyr::mutate(
    weight_saa = dplyr::coalesce(weight_saa, 0),
    weight_taa = dplyr::coalesce(weight_taa, 0),
    net_weight = weight_saa + weight_taa
  )

net_sums <- weights_combined %>%
  dplyr::group_by(strategy, date) %>%
  dplyr::summarise(total_weight = sum(net_weight), .groups = "drop")

if (any(abs(net_sums$total_weight - 1) > 1e-4)) {
  warning("Net weights deviate from 1.0 for at least one date; check SAA + TAA inputs.")
}

available_price_tickers <- unique(prices$ticker)
if (!opts$cash_ticker %in% available_price_tickers) {
  cash_returns <- tibble::tibble(
    ticker = opts$cash_ticker,
    date = calendar_dates$date,
    return = 0
  )
  prices <- dplyr::bind_rows(prices, cash_returns)
} else {
  message(sprintf("Cash ticker %s found in price files; using provided returns.", opts$cash_ticker))
}

missing_price_tickers <- setdiff(unique(weights_combined$ticker), unique(prices$ticker))
if (length(missing_price_tickers) > 0) {
  stop(
    "Missing price data for: ",
    paste(missing_price_tickers, collapse = ", "),
    ". Fetch data or provide synthetic series."
  )
}

portfolio_returns <- prices %>%
  dplyr::select(ticker, date, return) %>%
  dplyr::inner_join(weights_combined, by = c("ticker", "date")) %>%
  dplyr::group_by(strategy, date) %>%
  dplyr::summarise(
    portfolio_return = sum(net_weight * return, na.rm = TRUE),
    gross_exposure = sum(abs(net_weight)),
    .groups = "drop"
  ) %>%
  dplyr::group_by(strategy) %>%
  dplyr::arrange(date, .by_group = TRUE) %>%
  dplyr::mutate(
    nav = cumprod(1 + tidyr::replace_na(portfolio_return, 0)),
    rebal_flag = if_else(date %in% taa_weights$effective_date, TRUE, FALSE)
  ) %>%
  dplyr::ungroup()

arrow::write_parquet(portfolio_returns, opts$output)

latest_dates <- weights_combined %>%
  dplyr::group_by(strategy) %>%
  dplyr::summarise(latest_date = max(date), .groups = "drop")

latest_weights <- weights_combined %>%
  dplyr::inner_join(latest_dates, by = c("strategy", "date" = "latest_date")) %>%
  dplyr::select(strategy, date, ticker, weight_saa, weight_taa, net_weight)

readr::write_csv(latest_weights, opts$weights_log)

message("Portfolio returns written to ", opts$output)
message("Latest weights snapshot written to ", opts$weights_log)
