# Running the TAA/SAA Model

End-to-end steps to refresh data, build portfolio returns, and review outputs.

## 1) Prereqs and environment
- R with packages: `optparse`, `yaml`, `quantmod`, `dplyr`, `tidyr`, `purrr`, `lubridate`, `arrow`, `zoo`, `readr`. In the devcontainer, install via `.devcontainer/install-packages.r` if needed.
- Ensure the ETF universe tickers match your allocation tickers (see mapping notes below).
- Network access to Yahoo Finance for price pulls.

## 2) Define the investable universe
- Edit `config/instruments/etf_universe.yml`.
  - `ticker` is the filename used in `data/raw/yahoo/<ticker>.parquet`.
  - `yahoo_symbol` is what `quantmod` requests (use suffixes like `.L`, `.SW`, or FX pairs like `JPY=X`).
- Keep `ticker` values consistent with `data/reference/saa_weights_history.csv` and `data/reference/taa_weights_history.csv`; there is no automatic mapping.

## 3) Maintain allocations
- Baseline SAA: append dated rows to `data/reference/saa_weights_history.csv` (weights sum to 1.0 including `CASH`).
- TAA deviations: append dated rows to `data/reference/taa_weights_history.csv` (weights sum to 0.0 each effective date).
- Optional human snapshot: update `config/allocations/saa_current.yml` for quick reference; it is not read by scripts.

## 4) Fetch prices from Yahoo
```
Rscript scripts/R/fetch_yahoo_data.R \
  --config config/instruments/etf_universe.yml \
  --start 2010-01-01 \
  --output-dir data/raw/yahoo
```
- Output: one parquet per ticker in `data/raw/yahoo/`.
- Verify a file exists for every ticker in your SAA/TAA files.

## 5) Build portfolio returns (SAA + TAA)
```
Rscript scripts/R/build_taa_portfolio.R \
  --saa-weights data/reference/saa_weights_history.csv \
  --weights data/reference/taa_weights_history.csv \
  --price-dir data/raw/yahoo \
  --output data/outputs/performance/taa_portfolio_returns.parquet \
  --weights-log logs/tactical_trades/latest_weights.csv
```
- Validations: SAA rows must sum to 1.0; TAA rows must sum to 0.0; tickers must match price files. A synthetic `CASH` series (0 return) is injected if not present in prices.
- Outputs:
  - `data/outputs/performance/taa_portfolio_returns.parquet` with `date`, `strategy`, `portfolio_return`, `nav`, `rebal_flag`.
  - `logs/tactical_trades/latest_weights.csv` snapshot of the latest SAA/TAA/net weights.

## 6) Inspect results in R
```r
library(arrow); library(dplyr)
pf <- read_parquet("data/outputs/performance/taa_portfolio_returns.parquet")
dplyr::glimpse(pf)
pf %>% group_by(strategy) %>% summarise(
  start = min(date), end = max(date),
  total_return = prod(1 + portfolio_return, na.rm = TRUE) - 1
)
```

## 7) Trade-level analytics (optional)
```
Rscript scripts/R/trade_performance.R \
  --trade-id TAA-2024-01 \
  --long SPY --short CASH \
  --entry 2024-04-25 --exit 2024-11-15 \
  --price-dir data/raw/yahoo \
  --output-dir data/outputs/performance/trades
```
- Outputs: `<trade_id>_daily.csv` and `<trade_id>_summary.csv` in `data/outputs/performance/trades/`.

## 8) Common pitfalls
- Ticker mismatches: `saa_weights_history.csv`/`taa_weights_history.csv` tickers must match parquet filenames from the universe; otherwise `build_taa_portfolio.R` will fail with “Missing price data”.
- Weight sums: SAA must sum to 1.0 per date; TAA must sum to 0.0 per date.
- Cash handling: If no `CASH` price series is provided, the scripts assume 0 return.
