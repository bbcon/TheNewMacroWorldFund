#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(readr)
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(purrr)
  library(arrow)
  library(ggplot2)
  library(scales)
})

option_list <- list(
  optparse::make_option(c("--saa-weights"), dest = "saa_weights", type = "character",
                        default = "data/reference/saa_weights_history.csv",
                        help = "CSV with SAA baseline weights."),
  optparse::make_option(c("--taa-weights"), dest = "taa_weights", type = "character",
                        default = "data/reference/taa_weights_history.csv",
                        help = "CSV with TAA deviation weights."),
  optparse::make_option(c("-p", "--price-dir"), dest = "price_dir",
                        default = "data/raw/yahoo",
                        help = "Directory with parquet price files."),
  optparse::make_option(c("-o", "--output"), dest = "output",
                        default = "data/outputs/performance/attribution.parquet",
                        help = "Parquet output for attribution series."),
  optparse::make_option(c("--figure-dir"), dest = "figure_dir",
                        default = "reports/figures",
                        help = "Directory where ggplot charts will be saved."),
  optparse::make_option(c("--cash-ticker"), dest = "cash_ticker",
                        default = "CASH",
                        help = "Cash ticker name (assumed 0 return if missing).")
)

opts <- optparse::parse_args(optparse::OptionParser(option_list = option_list))

stopifnot(file.exists(opts$saa_weights))
stopifnot(file.exists(opts$taa_weights))
stopifnot(dir.exists(opts$price_dir))
if (!dir.exists(dirname(opts$output))) dir.create(dirname(opts$output), recursive = TRUE)
if (!dir.exists(opts$figure_dir)) dir.create(opts$figure_dir, recursive = TRUE)

saa <- readr::read_csv(opts$saa_weights, show_col_types = FALSE) %>%
  dplyr::mutate(effective_date = lubridate::as_date(effective_date))
taa <- readr::read_csv(opts$taa_weights, show_col_types = FALSE) %>%
  dplyr::mutate(effective_date = lubridate::as_date(effective_date))

price_files <- list.files(opts$price_dir, pattern = "\\.parquet$", full.names = TRUE)
if (length(price_files) == 0) stop("No price files found in ", opts$price_dir)

prices <- purrr::map_dfr(price_files, function(path) {
  ticker <- tools::file_path_sans_ext(basename(path))
  df <- arrow::read_parquet(path)
  dplyr::mutate(df, ticker = ticker)
}) %>%
  dplyr::mutate(date = lubridate::as_date(date)) %>%
  dplyr::select(ticker, date, adjusted) %>%
  dplyr::arrange(ticker, date) %>%
  dplyr::group_by(ticker) %>%
  dplyr::mutate(return = adjusted / dplyr::lag(adjusted) - 1) %>%
  dplyr::ungroup()

calendar_dates <- tibble::tibble(date = sort(unique(prices$date)))

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

saa_daily <- extend_weights(saa, fill_zeros = FALSE) %>% dplyr::rename(weight_saa = weight)
taa_daily <- extend_weights(taa, fill_zeros = TRUE) %>% dplyr::rename(weight_taa = weight)

weights <- dplyr::full_join(saa_daily, taa_daily, by = c("strategy", "ticker", "date")) %>%
  dplyr::mutate(
    weight_saa = dplyr::coalesce(weight_saa, 0),
    weight_taa = dplyr::coalesce(weight_taa, 0),
    net_weight = weight_saa + weight_taa
  )

available_price_tickers <- unique(prices$ticker)
if (!opts$cash_ticker %in% available_price_tickers) {
  cash_returns <- tibble::tibble(
    ticker = opts$cash_ticker,
    date = calendar_dates$date,
    return = 0
  )
  prices <- dplyr::bind_rows(prices, cash_returns)
}

missing_price_tickers <- setdiff(unique(weights$ticker), unique(prices$ticker))
if (length(missing_price_tickers) > 0) {
  stop("Missing price data for: ", paste(missing_price_tickers, collapse = ", "))
}

attrib <- prices %>%
  dplyr::select(ticker, date, return) %>%
  dplyr::inner_join(weights, by = c("ticker", "date")) %>%
  dplyr::group_by(strategy, date) %>%
  dplyr::summarise(
    return_saa = sum(weight_saa * return, na.rm = TRUE),
    return_taa = sum(weight_taa * return, na.rm = TRUE),
    portfolio_return = sum(net_weight * return, na.rm = TRUE),
    gross_exposure = sum(abs(net_weight)),
    .groups = "drop"
  ) %>%
  dplyr::group_by(strategy) %>%
  dplyr::arrange(date, .by_group = TRUE) %>%
  dplyr::mutate(
    nav = cumprod(1 + tidyr::replace_na(portfolio_return, 0)),
    nav_saa_only = cumprod(1 + tidyr::replace_na(return_saa, 0)),
    nav_taa_only = cumprod(1 + tidyr::replace_na(return_taa, 0)),
    peak_nav = cummax(nav),
    drawdown = nav / peak_nav - 1
  ) %>%
  dplyr::ungroup()

arrow::write_parquet(attrib, opts$output)

attribution_plot <- ggplot(attrib %>% filter(date>=today()-days(2*365)), aes(x = date)) +
  geom_col(aes(y = return_saa, fill = "SAA"), alpha = 0.7) +
  geom_col(aes(y = return_taa, fill = "TAA"), alpha = 0.7) +
  facet_wrap(~strategy, ncol = 1, scales = "free_y") +
  scale_fill_manual(values = c("SAA" = "#1b9e77", "TAA" = "#d95f02"), name = "Source") +
  scale_y_continuous(labels = scales::percent_format(accuracy = 0.1)) +
  labs(title = "Daily Return Attribution", x = NULL, y = "Return") +
  theme_minimal(base_size = 12)

ggsave(file.path(opts$figure_dir, "attribution_daily.png"), attribution_plot, width = 10, height = 6, dpi = 150)

message("Attribution written to ", opts$output)
message("Attribution chart written to ", opts$figure_dir)

