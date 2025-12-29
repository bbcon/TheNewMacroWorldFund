#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(arrow)
  library(ggplot2)
  library(purrr)
  library(tidyr)
})

price_dir <- "data/raw/datastream"
output_csv <- "data/outputs/checks/datastream_2025_returns.csv"
output_plot <- "data/outputs/checks/datastream_2025_ytd.png"
start_2025 <- as.Date("2025-01-01")
end_2025 <- as.Date("2025-12-31")

if (!dir.exists(price_dir)) {
  stop("Price directory not found: ", price_dir)
}

price_files <- list.files(price_dir, pattern = "\\.parquet$", full.names = TRUE)
if (length(price_files) == 0) {
  stop("No parquet files found in ", price_dir)
}

dir.create(dirname(output_csv), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(output_plot), recursive = TRUE, showWarnings = FALSE)

read_returns <- function(path) {
  df <- arrow::read_parquet(path)
  has_return <- "return_usd" %in% names(df)
  has_price <- "price_usd" %in% names(df)
  if (!has_return && !has_price) {
    stop("File missing return_usd and price_usd: ", path)
  }

  df <- dplyr::mutate(df, date = as.Date(date))
  if (has_return) {
    df <- dplyr::rename(df, return = return_usd)
  } else {
    df <- dplyr::arrange(df, date)
    df <- dplyr::mutate(df, return = price_usd / dplyr::lag(price_usd) - 1)
  }

  dplyr::select(df, date, return)
}

returns_2025 <- purrr::map_dfr(price_files, function(path) {
  ticker <- tools::file_path_sans_ext(basename(path))
  df <- read_returns(path) %>%
    dplyr::filter(date >= start_2025, date <= end_2025)
  if (nrow(df) == 0) return(NULL)
  dplyr::mutate(df, ticker = ticker)
})

if (nrow(returns_2025) == 0) {
  stop("No 2025 returns found in ", price_dir)
}

summary_2025 <- returns_2025 %>%
  dplyr::group_by(ticker) %>%
  dplyr::arrange(date, .by_group = TRUE) %>%
  dplyr::summarise(
    trading_days_2025 = sum(!is.na(return)),
    avg_daily_return_2025 = mean(return, na.rm = TRUE),
    annual_return_2025 = prod(1 + tidyr::replace_na(return, 0)) - 1,
    first_date_2025 = min(date),
    last_date_2025 = max(date),
    .groups = "drop"
  ) %>%
  dplyr::arrange(desc(annual_return_2025))

readr::write_csv(summary_2025, output_csv)

ytd_series <- returns_2025 %>%
  dplyr::arrange(date) %>%
  dplyr::group_by(ticker) %>%
  dplyr::mutate(
    ytd_cum_return = cumprod(1 + tidyr::replace_na(return, 0)) - 1
  ) %>%
  dplyr::ungroup()

p <- ggplot2::ggplot(ytd_series, ggplot2::aes(x = date, y = ytd_cum_return * 100, color = ticker)) +
  ggplot2::geom_line(linewidth = 0.6) +
  ggplot2::labs(
    title = "2025 YTD cumulative returns (USD)",
    x = "Date",
    y = "YTD return (%)",
    color = "Ticker"
  ) +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(legend.position = "right")
p
ggplot2::ggsave(output_plot, p, width = 10, height = 6, dpi = 320)

message("2025 return table written to ", output_csv)
message("2025 YTD plot written to ", output_plot)

