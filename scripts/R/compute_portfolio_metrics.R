#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(dplyr)
  library(lubridate)
  library(arrow)
  library(readr)
  library(ggplot2)
  library(scales)
})

rolling_apply <- function(x, window, fun) {
  n <- length(x)
  out <- rep(NA_real_, n)
  if (n < window) return(out)
  for (i in seq.int(window, n)) {
    out[i] <- fun(x[(i - window + 1):i])
  }
  out
}

compute_metrics <- function(df, period_label) {
  df <- dplyr::arrange(df, date)
  total_return <- prod(1 + df$portfolio_return, na.rm = TRUE) - 1
  days_held <- as.numeric(max(df$date) - min(df$date) + 1)
  cagr <- (1 + total_return)^(365.25 / days_held) - 1
  vol <- stats::sd(df$portfolio_return, na.rm = TRUE) * sqrt(252)
  sharpe <- ifelse(vol == 0, NA_real_, (mean(df$portfolio_return, na.rm = TRUE) * 252) / vol)
  nav <- cumprod(1 + tidyr::replace_na(df$portfolio_return, 0))
  peak <- cummax(nav)
  max_dd <- min(nav / peak - 1, na.rm = TRUE)
  tibble::tibble(
    strategy = unique(df$strategy),
    period = period_label,
    total_return = total_return,
    cagr = cagr,
    vol = vol,
    sharpe = sharpe,
    max_drawdown = max_dd,
    days = days_held
  )
}

option_list <- list(
  optparse::make_option(c("-i", "--input"), dest = "input",
                        default = "data/outputs/performance/taa_portfolio_returns.parquet",
                        help = "Parquet file with portfolio returns."),
  optparse::make_option(c("-o", "--output"), dest = "output",
                        default = "data/outputs/performance/portfolio_metrics.parquet",
                        help = "Parquet path for summary metrics."),
  optparse::make_option(c("--drawdowns-output"), dest = "dd_output",
                        default = "data/outputs/performance/drawdowns.parquet",
                        help = "Parquet path for drawdown series."),
  optparse::make_option(c("--rolling-output"), dest = "rolling_output",
                        default = "data/outputs/performance/rolling_metrics.parquet",
                        help = "Parquet path for rolling stats."),
  optparse::make_option(c("--figure-dir"), dest = "figure_dir",
                        default = "reports/figures",
                        help = "Directory where ggplot charts will be saved.")
)

opts <- optparse::parse_args(optparse::OptionParser(option_list = option_list))

if (!file.exists(opts$input)) stop("Input portfolio parquet not found: ", opts$input)
if (!dir.exists(dirname(opts$output))) dir.create(dirname(opts$output), recursive = TRUE)
if (!dir.exists(dirname(opts$dd_output))) dir.create(dirname(opts$dd_output), recursive = TRUE)
if (!dir.exists(dirname(opts$rolling_output))) dir.create(dirname(opts$rolling_output), recursive = TRUE)
if (!dir.exists(opts$figure_dir)) dir.create(opts$figure_dir, recursive = TRUE)

portfolio <- arrow::read_parquet(opts$input) %>%
  dplyr::mutate(date = lubridate::as_date(date)) %>%
  dplyr::arrange(strategy, date)

today_year <- lubridate::year(max(portfolio$date, na.rm = TRUE))

metrics_since <- portfolio %>%
  dplyr::group_by(strategy) %>%
  tidyr::nest() %>%
  dplyr::mutate(metrics = purrr::map(data, compute_metrics, period_label = "since_inception")) %>%
  dplyr::select(strategy, metrics) %>%
  tidyr::unnest(metrics)

metrics_ytd <- portfolio %>%
  dplyr::filter(lubridate::year(date) == today_year) %>%
  dplyr::group_by(strategy) %>%
  tidyr::nest() %>%
  dplyr::mutate(metrics = purrr::map(data, compute_metrics, period_label = paste0(today_year, "_ytd"))) %>%
  dplyr::select(strategy, metrics) %>%
  tidyr::unnest(metrics)

all_metrics <- dplyr::bind_rows(metrics_since, metrics_ytd) %>%
  dplyr::arrange(strategy, period)

arrow::write_parquet(all_metrics, opts$output)

drawdowns <- portfolio %>%
  dplyr::group_by(strategy) %>%
  dplyr::arrange(date, .by_group = TRUE) %>%
  dplyr::mutate(
    nav = cumprod(1 + tidyr::replace_na(portfolio_return, 0)),
    peak = cummax(nav),
    drawdown = nav / peak - 1
  ) %>%
  dplyr::ungroup()

arrow::write_parquet(drawdowns, opts$dd_output)

rolling_tbl <- portfolio %>%
  dplyr::group_by(strategy) %>%
  dplyr::arrange(date, .by_group = TRUE) %>%
  dplyr::mutate(
    roll_21_return = rolling_apply(portfolio_return, 21, function(x) prod(1 + x) - 1),
    roll_63_return = rolling_apply(portfolio_return, 63, function(x) prod(1 + x) - 1),
    roll_126_return = rolling_apply(portfolio_return, 126, function(x) prod(1 + x) - 1),
    roll_63_vol = rolling_apply(portfolio_return, 63, function(x) stats::sd(x, na.rm = TRUE) * sqrt(252)),
    roll_63_sharpe = ifelse(
      is.na(roll_63_vol) | roll_63_vol == 0, NA_real_,
      rolling_apply(portfolio_return, 63, function(x) mean(x, na.rm = TRUE) * 252) / roll_63_vol
    )
  ) %>%
  dplyr::ungroup()

arrow::write_parquet(rolling_tbl, opts$rolling_output)

equity_plot <- ggplot(portfolio, aes(x = date, y = nav, color = strategy)) +
  geom_line(size = 0.8) +
  scale_y_continuous(labels = scales::number_format(accuracy = 0.01)) +
  labs(title = "Portfolio NAV", x = NULL, y = "NAV", color = "Strategy") +
  theme_minimal(base_size = 12)

dd_plot <- ggplot(drawdowns, aes(x = date, y = drawdown, color = strategy)) +
  geom_line(size = 0.7) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(title = "Drawdowns", x = NULL, y = "Drawdown", color = "Strategy") +
  theme_minimal(base_size = 12)

ggsave(file.path(opts$figure_dir, "portfolio_nav.png"), equity_plot, width = 10, height = 6, dpi = 150)
ggsave(file.path(opts$figure_dir, "portfolio_drawdowns.png"), dd_plot, width = 10, height = 6, dpi = 150)

message("Metrics written to ", opts$output)
message("Drawdowns written to ", opts$dd_output)
message("Rolling stats written to ", opts$rolling_output)
message("Charts written to ", opts$figure_dir)
