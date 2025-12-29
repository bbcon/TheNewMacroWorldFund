#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(arrow)
  library(dplyr)
  library(lubridate)
  library(jsonlite)
  library(readr)
  library(fs)
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
  optparse::make_option(c("--trades-summary"), dest = "trades_summary",
                        default = "data/outputs/performance/trades_summary.parquet",
                        help = "Parquet with per-trade performance summary."),
  optparse::make_option(c("--trades-equity"), dest = "trades_equity",
                        default = "data/outputs/performance/trades_equity_curve.parquet",
                        help = "Parquet with aggregate trade equity curve."),
  optparse::make_option(c("--narratives"), dest = "narratives",
                        default = "docs/data/trades_narratives.json",
                        help = "Trade narratives JSON (copied through if present)."),
  optparse::make_option(c("-o", "--output-dir"), dest = "output_dir",
                        default = "docs/data",
                        help = "Directory where JSON payloads will be written.")
)

opts <- optparse::parse_args(optparse::OptionParser(option_list = option_list))

if (!dir.exists(opts$output_dir)) dir.create(opts$output_dir, recursive = TRUE)

write_parquet_json <- function(input_path, output_name) {
  if (!file.exists(input_path)) {
    message("Skip missing file: ", input_path)
    return(invisible(NULL))
  }
  df <- arrow::read_parquet(input_path) %>%
    dplyr::mutate(dplyr::across(dplyr::matches("^date$"), as.character))
  out_path <- file.path(opts$output_dir, output_name)
  jsonlite::write_json(df, out_path, auto_unbox = TRUE)
  message("Wrote ", out_path)
}

write_parquet_json(opts$portfolio, "portfolio.json")
write_parquet_json(opts$metrics, "metrics.json")
write_parquet_json(opts$drawdowns, "drawdowns.json")
write_parquet_json(opts$rolling, "rolling.json")
write_parquet_json(opts$trades_summary, "trades_summary.json")
write_parquet_json(opts$trades_equity, "trades_equity.json")

if (file.exists(opts$narratives)) {
  dest_path <- file.path(opts$output_dir, "trades_narratives.json")
  if (fs::path_real(opts$narratives) != fs::path_real(dest_path)) {
    file.copy(opts$narratives, dest_path, overwrite = TRUE)
    message("Copied narratives to ", dest_path)
  } else {
    message("Narratives already located at ", dest_path, "; no copy needed.")
  }
} else {
  message("Trade narratives JSON not found: ", opts$narratives)
}

message("Site data exported to ", opts$output_dir)
