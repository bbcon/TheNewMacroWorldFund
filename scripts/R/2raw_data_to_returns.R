#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(purrr)
  library(arrow)
  library(readr)
  library(yaml)
  library(stringr)
})

`%||%` <- function(x, y) if (is.null(x) || is.na(x) || identical(x, "")) y else x

option_list <- list(
  optparse::make_option(c("-r", "--raw-data"), dest = "raw_data",
                        default = "data/raw/datastream/raw_series.parquet",
                        help = "Parquet with raw Datastream pulls from 1fetch_raw_data.R."),
  optparse::make_option(c("-c", "--config"), dest = "config",
                        default = "config/instruments/etf_universe_datastream.yml",
                        help = "Universe config (used for metadata fallbacks)."),
  optparse::make_option(c("-o", "--output-returns"), dest = "output_returns",
                        default = "data/processed/returns/asset_returns.parquet",
                        help = "Parquet for USD/local returns per asset."),
  optparse::make_option(c("--currency-output"), dest = "currency_output",
                        default = "data/processed/returns/currency_returns.parquet",
                        help = "Parquet for currency carry/spot returns (long foreign currency vs USD)."),
  optparse::make_option(c("--summary-output"), dest = "summary_output",
                        default = "data/outputs/performance/return_summary.csv",
                        help = "CSV with summary stats for sanity checks.")
)

opts <- optparse::parse_args(optparse::OptionParser(option_list = option_list))

if (!file.exists(opts$raw_data)) stop("Raw data parquet missing: ", opts$raw_data)
if (!dir.exists(dirname(opts$output_returns))) dir.create(dirname(opts$output_returns), recursive = TRUE)
if (!dir.exists(dirname(opts$currency_output))) dir.create(dirname(opts$currency_output), recursive = TRUE)
if (!dir.exists(dirname(opts$summary_output))) dir.create(dirname(opts$summary_output), recursive = TRUE)

cfg_tbl <- tryCatch({
  cfg <- yaml::read_yaml(opts$config)
  purrr::map_dfr(cfg$universe, function(entry) {
    tibble::tibble(
      ticker = entry$ticker,
      asset_class = entry$asset_class %||% NA_character_,
      currency = entry$currency %||% entry$quote_currency %||% NA_character_,
      base_currency = entry$base_currency %||% ifelse(entry$asset_class == "fx", "USD", NA_character_),
      quote_currency = entry$quote_currency %||% entry$currency %||% NA_character_,
      price_field = entry$price_field %||% cfg$price_field %||% "P",
      start_date = entry$start_date %||% NA_character_
    )
  })
}, error = function(e) tibble::tibble())

raw <- arrow::read_parquet(opts$raw_data) %>%
  dplyr::mutate(date = lubridate::as_date(date))

raw <- raw %>%
  dplyr::left_join(cfg_tbl, by = "ticker", suffix = c("", "_cfg")) %>%
  dplyr::mutate(
    asset_class = dplyr::coalesce(asset_class, asset_class_cfg),
    currency = dplyr::coalesce(currency, currency_cfg),
    base_currency = dplyr::coalesce(base_currency, base_currency_cfg),
    quote_currency = dplyr::coalesce(quote_currency, quote_currency_cfg),
    price_field = dplyr::coalesce(price_field, price_field_cfg)
  ) %>%
  dplyr::select(-dplyr::ends_with("_cfg"))

if (!("raw_value" %in% names(raw))) {
  stop("raw_value column missing in raw parquet; re-run 1fetch_raw_data.R")
}

normalize_cash_rate <- function(value, price_field) {
  out <- value
  mask <- price_field %in% c("IO", "RY", "RYLD")
  out[mask] <- out[mask] / 100
  out
}

raw_with_returns <- raw %>%
  dplyr::group_by(ticker) %>%
  dplyr::arrange(date, .by_group = TRUE) %>%
  dplyr::mutate(
    price_local = raw_value,
    rate_decimal = dplyr::if_else(asset_class == "cash",
                                  normalize_cash_rate(price_local, price_field),
                                  price_local),
    return_local = dplyr::case_when(
      asset_class == "cash" ~ rate_decimal / 252,
      TRUE ~ price_local / dplyr::lag(price_local) - 1
    )
  ) %>%
  dplyr::ungroup()

fx_tbl <- raw_with_returns %>%
  dplyr::filter(asset_class == "fx") %>%
  dplyr::transmute(
    fx_ticker = ticker,
    fx_currency = dplyr::coalesce(quote_currency, currency),
    date,
    fx_rate = price_local,
    fx_return = return_local
  )

cash_tbl <- raw_with_returns %>%
  dplyr::filter(asset_class == "cash") %>%
  dplyr::transmute(
    cash_ticker = ticker,
    currency,
    date,
    cash_return = return_local
  )

usd_cash <- cash_tbl %>%
  dplyr::filter(currency == "USD") %>%
  dplyr::select(date, usd_cash_return = cash_return)

asset_returns <- raw_with_returns %>%
  dplyr::filter(asset_class != "fx") %>%
  dplyr::left_join(fx_tbl, by = c("currency" = "fx_currency", "date")) %>%
  dplyr::left_join(cash_tbl %>% dplyr::rename(local_cash_return = cash_return), by = c("currency", "date")) %>%
  dplyr::left_join(usd_cash, by = "date") %>%
  dplyr::group_by(ticker) %>%
  dplyr::arrange(date, .by_group = TRUE) %>%
  dplyr::mutate(
    hedged_fx_carry = dplyr::case_when(
      asset_class == "rates" & currency != "USD" ~ (1 + tidyr::replace_na(usd_cash_return, 0)) /
        (1 + tidyr::replace_na(local_cash_return, 0)) - 1,
      TRUE ~ NA_real_
    ),
    return_usd = dplyr::case_when(
      asset_class == "rates" & currency != "USD" ~ (1 + tidyr::replace_na(return_local, 0)) *
        (1 + tidyr::replace_na(hedged_fx_carry, 0)) - 1,
      currency == "USD" ~ return_local,
      TRUE ~ (1 + tidyr::replace_na(return_local, 0)) *
        (1 + tidyr::replace_na(fx_return, 0)) - 1
    ),
    price_usd = dplyr::case_when(
      asset_class == "rates" & currency != "USD" ~ cumprod(1 + tidyr::replace_na(return_usd, 0)),
      currency == "USD" ~ price_local,
      TRUE ~ price_local * tidyr::replace_na(fx_rate, 1)
    ),
    nav = cumprod(1 + tidyr::replace_na(return_usd, 0))
  ) %>%
  dplyr::ungroup() %>%
  dplyr::select(
    ticker, asset_class, currency, date,
    return_local, return_usd,
    price_local, price_usd,
    fx_rate, fx_return, local_cash_return, usd_cash_return, nav
  )

currency_returns <- fx_tbl %>%
  dplyr::left_join(cash_tbl %>% dplyr::rename(local_cash_return = cash_return), by = c("fx_currency" = "currency", "date")) %>%
  dplyr::left_join(usd_cash, by = "date") %>%
  dplyr::mutate(
    ticker = paste0("CCY_", fx_currency),
    asset_class = "currency",
    currency = fx_currency,
    return_usd = (1 + tidyr::replace_na(fx_return, 0)) *
      (1 + tidyr::replace_na(local_cash_return, 0)) /
      (1 + tidyr::replace_na(usd_cash_return, 0)) - 1
  ) %>%
  dplyr::group_by(ticker) %>%
  dplyr::arrange(date, .by_group = TRUE) %>%
  dplyr::mutate(nav = cumprod(1 + tidyr::replace_na(return_usd, 0))) %>%
  dplyr::ungroup() %>%
  dplyr::select(ticker, asset_class, currency, date, return_usd, fx_rate, fx_return, local_cash_return, usd_cash_return, nav)

all_summaries <- dplyr::bind_rows(
  asset_returns %>% dplyr::mutate(series_type = "asset"),
  currency_returns %>% dplyr::mutate(series_type = "currency")
) %>%
  dplyr::group_by(ticker, asset_class, series_type) %>%
  dplyr::summarise(
    start_date = min(date, na.rm = TRUE),
    end_date = max(date, na.rm = TRUE),
    observations = dplyr::n(),
    total_return_usd = prod(1 + tidyr::replace_na(return_usd, 0)) - 1,
    annualized_return = (1 + mean(return_usd, na.rm = TRUE))^252 - 1,
    annualized_vol = stats::sd(return_usd, na.rm = TRUE) * sqrt(252),
    sharpe = ifelse(annualized_vol > 0, (mean(return_usd, na.rm = TRUE) * 252) / annualized_vol, NA_real_),
    missing_values = sum(is.na(return_usd)),
    .groups = "drop"
  )

arrow::write_parquet(asset_returns, opts$output_returns)
arrow::write_parquet(currency_returns, opts$currency_output)
readr::write_csv(all_summaries, opts$summary_output)

message("USD returns written to ", opts$output_returns)
message("Currency long returns written to ", opts$currency_output)
message("Summary stats written to ", opts$summary_output)
