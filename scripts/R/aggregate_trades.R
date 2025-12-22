#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(dplyr)
  library(readr)
  library(lubridate)
  library(purrr)
  library(tidyr)
  library(arrow)
  library(ggplot2)
  library(scales)
})

option_list <- list(
  optparse::make_option(c("-t", "--trades-dir"), dest = "trades_dir",
                        default = "data/outputs/performance/trades",
                        help = "Directory containing *_daily.csv and *_summary.csv trade files."),
  optparse::make_option(c("-o", "--summary-output"), dest = "summary_output",
                        default = "data/outputs/performance/trades_summary.parquet",
                        help = "Parquet path for aggregated trade summaries."),
  optparse::make_option(c("--equity-output"), dest = "equity_output",
                        default = "data/outputs/performance/trades_equity_curve.parquet",
                        help = "Parquet path for aggregated trade equity curve."),
  optparse::make_option(c("--figure-dir"), dest = "figure_dir",
                        default = "reports/figures",
                        help = "Directory where ggplot charts will be saved.")
)

opts <- optparse::parse_args(optparse::OptionParser(option_list = option_list))

if (!dir.exists(opts$trades_dir)) stop("Trades directory not found: ", opts$trades_dir)
if (!dir.exists(dirname(opts$summary_output))) dir.create(dirname(opts$summary_output), recursive = TRUE)
if (!dir.exists(dirname(opts$equity_output))) dir.create(dirname(opts$equity_output), recursive = TRUE)
if (!dir.exists(opts$figure_dir)) dir.create(opts$figure_dir, recursive = TRUE)

summary_files <- list.files(opts$trades_dir, pattern = "_summary\\.csv$", full.names = TRUE)
if (length(summary_files) == 0) stop("No trade summary files found in ", opts$trades_dir)

summaries <- purrr::map_dfr(summary_files, readr::read_csv, show_col_types = FALSE) %>%
  dplyr::mutate(entry_date = lubridate::as_date(entry_date),
                exit_date = lubridate::as_date(exit_date))

daily_files <- list.files(opts$trades_dir, pattern = "_daily\\.csv$", full.names = TRUE)
daily <- purrr::map_dfr(daily_files, function(path) {
  df <- readr::read_csv(path, show_col_types = FALSE)
  trade_id <- gsub("_daily\\.csv$", "", basename(path))
  df$trade_id <- trade_id
  df
}) %>%
  dplyr::mutate(date = lubridate::as_date(date)) %>%
  dplyr::arrange(trade_id, date)

if (nrow(daily) == 0) stop("No daily trade files found in ", opts$trades_dir)

metrics <- daily %>%
  dplyr::group_by(trade_id) %>%
  dplyr::summarise(
    vol = stats::sd(spread_return, na.rm = TRUE) * sqrt(252),
    sharpe = ifelse(vol == 0, NA_real_, (mean(spread_return, na.rm = TRUE) * 252) / vol),
    max_drawdown_recomputed = min(drawdown, na.rm = TRUE),
    days_held = dplyr::n(),
    total_return = prod(1 + spread_return, na.rm = TRUE) - 1,
    .groups = "drop"
  )

summaries <- summaries %>%
  dplyr::left_join(metrics, by = "trade_id") %>%
  dplyr::mutate(
    max_drawdown = dplyr::coalesce(max_drawdown_recomputed, max_drawdown),
    spread_total_return = dplyr::coalesce(total_return, spread_total_return)
  ) %>%
  dplyr::select(-max_drawdown_recomputed, -total_return) %>%
  dplyr::relocate(vol, sharpe, max_drawdown, days_held, .after = spread_total_return)

arrow::write_parquet(summaries, opts$summary_output)

equity_curve <- daily %>%
  dplyr::group_by(date) %>%
  dplyr::summarise(portfolio_spread_return = sum(spread_return, na.rm = TRUE), .groups = "drop") %>%
  dplyr::arrange(date) %>%
  dplyr::mutate(
    nav = cumprod(1 + tidyr::replace_na(portfolio_spread_return, 0)),
    peak = cummax(nav),
    drawdown = nav / peak - 1
  )

arrow::write_parquet(equity_curve, opts$equity_output)

equity_plot <- ggplot(equity_curve, aes(x = date, y = nav)) +
  geom_line(color = "#2b8cbe", size = 0.8) +
  labs(title = "Aggregated Trade Equity Curve", x = NULL, y = "NAV") +
  theme_minimal(base_size = 12)

dd_plot <- ggplot(equity_curve, aes(x = date, y = drawdown)) +
  geom_line(color = "#cb181d", size = 0.7) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(title = "Aggregated Trade Drawdowns", x = NULL, y = "Drawdown") +
  theme_minimal(base_size = 12)

ggsave(file.path(opts$figure_dir, "trades_equity.png"), equity_plot, width = 10, height = 6, dpi = 150)
ggsave(file.path(opts$figure_dir, "trades_drawdown.png"), dd_plot, width = 10, height = 6, dpi = 150)

message("Trade summaries written to ", opts$summary_output)
message("Trade equity curve written to ", opts$equity_output)
message("Charts written to ", opts$figure_dir)
