#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(arrow)
  library(dplyr)
  library(lubridate)
  library(jsonlite)
  library(readr)
})

option_list <- list(
  optparse::make_option(c("--portfolio"), dest = "portfolio",
                        default = "data/outputs/performance/taa_portfolio_returns.parquet",
                        help = "Parquet with portfolio returns."),
  optparse::make_option(c("--metrics"), dest = "metrics",
                        default = "data/outputs/performance/portfolio_metrics.parquet",
                        help = "Parquet with summary metrics."),
  optparse::make_option(c("--drawdowns"), dest = "drawdowns",
                        default = "data/outputs/performance/drawdowns.parquet",
                        help = "Parquet with drawdown series."),
  optparse::make_option(c("--rolling"), dest = "rolling",
                        default = "data/outputs/performance/rolling_metrics.parquet",
                        help = "Parquet with rolling stats."),
  optparse::make_option(c("--attribution"), dest = "attribution",
                        default = "data/outputs/performance/attribution.parquet",
                        help = "Parquet with SAA/TAA attribution."),
  optparse::make_option(c("--trades-summary"), dest = "trades_summary",
                        default = "data/outputs/performance/trades_summary.parquet",
                        help = "Parquet with aggregated trade summaries."),
  optparse::make_option(c("--trades-equity"), dest = "trades_equity",
                        default = "data/outputs/performance/trades_equity_curve.parquet",
                        help = "Parquet with aggregated trade equity curve."),
  optparse::make_option(c("-o", "--output-dir"), dest = "output_dir",
                        default = "docs/data",
                        help = "Directory where JSON payloads will be written.")
)

opts <- optparse::parse_args(optparse::OptionParser(option_list = option_list))

paths <- c(opts$portfolio, opts$metrics, opts$drawdowns, opts$rolling, opts$attribution, opts$trades_summary, opts$trades_equity)
missing <- paths[!file.exists(paths)]
if (length(missing) > 0) {
  stop("Missing required input files: ", paste(missing, collapse = ", "))
}

if (!dir.exists(opts$output_dir)) dir.create(opts$output_dir, recursive = TRUE)

portfolio <- arrow::read_parquet(opts$portfolio) %>% dplyr::mutate(date = as.character(lubridate::as_date(date)))
metrics <- arrow::read_parquet(opts$metrics)
drawdowns <- arrow::read_parquet(opts$drawdowns) %>% dplyr::mutate(date = as.character(lubridate::as_date(date)))
rolling <- arrow::read_parquet(opts$rolling) %>% dplyr::mutate(date = as.character(lubridate::as_date(date)))
attrib <- arrow::read_parquet(opts$attribution) %>% dplyr::mutate(date = as.character(lubridate::as_date(date)))
trade_summary <- arrow::read_parquet(opts$trades_summary)
trade_equity <- arrow::read_parquet(opts$trades_equity) %>% dplyr::mutate(date = as.character(lubridate::as_date(date)))

jsonlite::write_json(portfolio, file.path(opts$output_dir, "portfolio.json"), auto_unbox = TRUE)
jsonlite::write_json(metrics, file.path(opts$output_dir, "metrics.json"), auto_unbox = TRUE)
jsonlite::write_json(drawdowns, file.path(opts$output_dir, "drawdowns.json"), auto_unbox = TRUE)
jsonlite::write_json(rolling, file.path(opts$output_dir, "rolling.json"), auto_unbox = TRUE)
jsonlite::write_json(attrib, file.path(opts$output_dir, "attribution.json"), auto_unbox = TRUE)
jsonlite::write_json(trade_summary, file.path(opts$output_dir, "trades_summary.json"), auto_unbox = TRUE)
jsonlite::write_json(trade_equity, file.path(opts$output_dir, "trades_equity.json"), auto_unbox = TRUE)

message("Site data exported to ", opts$output_dir)
