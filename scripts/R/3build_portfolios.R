#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(yaml)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(lubridate)
  library(purrr)
  library(rlang)
  library(arrow)
})

`%||%` <- function(x, y) if (is.null(x) || is.na(x) || identical(x, "")) y else x

option_list <- list(
  optparse::make_option(c("-r", "--returns"), dest = "returns",
                        default = "data/processed/returns/asset_returns.parquet",
                        help = "Parquet with USD returns from 2raw_data_to_returns.R."),
  optparse::make_option(c("-c", "--config"), dest = "config",
                        default = "config/instruments/etf_universe_datastream.yml",
                        help = "Universe config used for SAA/benchmark weights."),
  optparse::make_option(c("-t", "--taa-weights"), dest = "taa_weights",
                        default = "data/reference/taa_weights_history.csv",
                        help = "CSV with TAA trades/overlays (must sum to zero per date)."),
  optparse::make_option(c("--saa-output"), dest = "saa_output",
                        default = "data/reference/saa_weights_history.csv",
                        help = "CSV where SAA weights derived from config will be written."),
  optparse::make_option(c("-o", "--portfolio-output"), dest = "portfolio_output",
                        default = "data/outputs/performance/taa_portfolio_returns.parquet",
                        help = "Parquet path for portfolio returns (SAA, TAA, fund, benchmark)."),
  optparse::make_option(c("--weights-log"), dest = "weights_log",
                        default = "data/outputs/performance/latest_weights.csv",
                        help = "CSV snapshot of latest weights."),
  optparse::make_option(c("--start-date"), dest = "start_date",
                        default = NA,
                        help = "Optional override for portfolio start date (YYYY-MM-DD).")
)

opts <- optparse::parse_args(optparse::OptionParser(option_list = option_list))

if (!file.exists(opts$returns)) stop("Returns parquet not found: ", opts$returns)
if (!file.exists(opts$config)) stop("Config not found: ", opts$config)
if (!file.exists(opts$taa_weights)) stop("TAA weights CSV not found: ", opts$taa_weights)
if (!dir.exists(dirname(opts$portfolio_output))) dir.create(dirname(opts$portfolio_output), recursive = TRUE)
if (!dir.exists(dirname(opts$weights_log))) dir.create(dirname(opts$weights_log), recursive = TRUE)
if (!dir.exists(dirname(opts$saa_output))) dir.create(dirname(opts$saa_output), recursive = TRUE)

cfg <- yaml::read_yaml(opts$config)
universe <- cfg$universe
if (is.null(universe) || length(universe) == 0) {
  stop("Universe in config is empty: ", opts$config)
}

weights_cfg <- purrr::map_dfr(universe, function(entry) {
  tibble::tibble(
    ticker = entry$ticker,
    asset_class = entry$asset_class %||% NA_character_,
    currency = entry$currency %||% entry$quote_currency %||% NA_character_,
    start_date = lubridate::as_date(entry$start_date %||% NA_character_),
    saa_weight = (entry$saa_weight_pct %||% 0) / 100,
    benchmark_weight = (entry$benchmark_weight_pct %||% 0) / 100,
    comment = entry$role %||% NA_character_
  )
})

if (abs(sum(weights_cfg$saa_weight, na.rm = TRUE) - 1) > 1e-4) {
  stop("SAA weights from config must sum to 1.0")
}
if (abs(sum(weights_cfg$benchmark_weight, na.rm = TRUE) - 1) > 1e-4) {
  stop("Benchmark weights from config must sum to 1.0")
}

taa_weights <- readr::read_csv(opts$taa_weights, show_col_types = FALSE) %>%
  dplyr::mutate(
    effective_date = lubridate::as_date(effective_date),
    exit_date = lubridate::as_date(exit_date)
  )

returns <- arrow::read_parquet(opts$returns) %>%
  dplyr::mutate(date = lubridate::as_date(date))

all_needed_tickers <- unique(c(weights_cfg$ticker, taa_weights$ticker))

returns_needed <- returns %>%
  dplyr::filter(ticker %in% all_needed_tickers)

if (nrow(returns_needed) == 0) stop("No returns available for tickers in weights/taa files.")

start_dates_from_data <- returns_needed %>%
  dplyr::group_by(ticker) %>%
  dplyr::summarise(first_date = min(date, na.rm = TRUE), .groups = "drop") %>%
  dplyr::pull(first_date)

data_start <- max(start_dates_from_data, na.rm = TRUE)
weights_start <- if (all(is.na(weights_cfg$start_date))) as.Date(NA) else max(weights_cfg$start_date, na.rm = TRUE)

start_date_candidates <- c(data_start)
if (!is.na(weights_start)) start_date_candidates <- c(start_date_candidates, weights_start)

if (!is.na(opts$start_date)) {
  start_date_candidates <- c(start_date_candidates, lubridate::as_date(opts$start_date))
}

portfolio_start <- max(start_date_candidates, na.rm = TRUE)
portfolio_end <- max(returns_needed$date, na.rm = TRUE)

calendar <- tibble::tibble(date = seq.Date(from = portfolio_start, to = portfolio_end, by = "day"))

expand_static_weights <- function(df, weight_col) {
  weight_sym <- rlang::sym(weight_col)
  df %>%
    dplyr::mutate(start_date = dplyr::coalesce(start_date, portfolio_start)) %>%
    dplyr::rowwise() %>%
    dplyr::mutate(data = list(tibble::tibble(
      date = calendar$date[calendar$date >= start_date],
      weight = !!weight_sym
    ))) %>%
    tidyr::unnest(data) %>%
    dplyr::ungroup() %>%
    dplyr::transmute(ticker, date, !!weight_col := weight)
}

saa_daily <- expand_static_weights(weights_cfg, "saa_weight")
benchmark_daily <- expand_static_weights(weights_cfg, "benchmark_weight")

taa_daily <- taa_weights %>%
  dplyr::mutate(
    effective_date = dplyr::coalesce(effective_date, portfolio_start),
    exit_date = dplyr::coalesce(exit_date, portfolio_end),
    start_date = pmax(effective_date, portfolio_start),
    end_date = pmin(exit_date, portfolio_end)
  ) %>%
  dplyr::rowwise() %>%
  dplyr::mutate(data = list(tibble::tibble(
    date = calendar$date[calendar$date >= start_date & calendar$date <= end_date],
    weight_taa = weight
  ))) %>%
  tidyr::unnest(data) %>%
  dplyr::ungroup() %>%
  dplyr::select(ticker, date, weight_taa)

taa_sum_check <- taa_daily %>%
  dplyr::group_by(date) %>%
  dplyr::summarise(total_weight = sum(weight_taa, na.rm = TRUE), .groups = "drop")

if (any(abs(taa_sum_check$total_weight) > 1e-4)) {
  warning("TAA weights do not sum to zero on all dates; check inputs.")
}

returns_calendar <- returns_needed %>%
  dplyr::filter(date >= portfolio_start) %>%
  dplyr::select(ticker, date, return_usd)

compute_portfolio <- function(weights_df, weight_col, label) {
  weights_df %>%
    dplyr::inner_join(returns_calendar, by = c("ticker", "date")) %>%
    dplyr::group_by(date) %>%
    dplyr::summarise(
      portfolio_return = sum(.data[[weight_col]] * return_usd, na.rm = TRUE),
      gross_exposure = sum(abs(.data[[weight_col]]), na.rm = TRUE),
      .groups = "drop"
    ) %>%
    dplyr::arrange(date) %>%
    dplyr::mutate(
      strategy = label,
      nav = cumprod(1 + tidyr::replace_na(portfolio_return, 0))
    ) %>%
    dplyr::select(strategy, date, portfolio_return, nav, gross_exposure)
}

saa_portfolio <- compute_portfolio(saa_daily, "saa_weight", "saa")
benchmark_portfolio <- compute_portfolio(benchmark_daily, "benchmark_weight", "benchmark")

taa_portfolio <- compute_portfolio(
  taa_daily %>% dplyr::mutate(weight_taa = dplyr::coalesce(weight_taa, 0)),
  "weight_taa",
  "taa"
)

net_weights <- dplyr::full_join(
  saa_daily, taa_daily,
  by = c("ticker", "date")
) %>%
  dplyr::mutate(
    weight_saa = dplyr::coalesce(saa_weight, 0),
    weight_taa = dplyr::coalesce(weight_taa, 0),
    net_weight = weight_saa + weight_taa
  ) %>%
  dplyr::select(ticker, date, weight_saa, weight_taa, net_weight)

fund_portfolio <- compute_portfolio(net_weights, "net_weight", "fund")

portfolio_all <- dplyr::bind_rows(
  saa_portfolio,
  benchmark_portfolio,
  taa_portfolio,
  fund_portfolio
) %>%
  dplyr::arrange(strategy, date)

arrow::write_parquet(portfolio_all, opts$portfolio_output)

latest_date <- max(net_weights$date, na.rm = TRUE)
latest_weights <- net_weights %>%
  dplyr::filter(date == latest_date) %>%
  dplyr::left_join(benchmark_daily %>% dplyr::filter(date == latest_date),
                   by = c("ticker", "date")) %>%
  dplyr::rename(weight_benchmark = benchmark_weight)

readr::write_csv(latest_weights, opts$weights_log)

saa_history <- weights_cfg %>%
  dplyr::mutate(
    effective_date = portfolio_start,
    strategy = "saa"
  ) %>%
  dplyr::select(effective_date, strategy, ticker, weight = saa_weight, comment)

readr::write_csv(saa_history, opts$saa_output)

message("Portfolio returns written to ", opts$portfolio_output)
message("Latest weights snapshot written to ", opts$weights_log)
message("SAA weights (from config) written to ", opts$saa_output)
