# Data + TAA Workflow

The repo now separates configuration, raw data, processed artefacts, and logs so ETF updates and TAA reviews are reproducible.

## Key directories
- `config/etf_universe.yml` — canonical list of ETFs with metadata (asset class, role, start date). Scripts use this as the only source of truth for market tickers.
- `data/raw/yahoo/` — one parquet file per ETF straight from Yahoo Finance. Never edit manually.
- `data/reference/saa_weights_history.csv` — dated SAA allocations that must sum to **1.0** (includes the 10% cash sleeve that finances tactical tilts).
- `data/reference/taa_weights_history.csv` — dated TAA deviations that must sum to **0.0** (positive tilts must be funded via cash or other sleeves).
- `data/processed/` — derived panels (e.g. merged time series, portfolio returns) produced by scripts.
- `logs/taa/` — human-readable exports such as the latest weights snapshot or allocation commentary.

## R scripts
1. `scripts/R/fetch_yahoo_data.R`
   - Reads `config/etf_universe.yml`.
   - Pulls daily prices from Yahoo via `quantmod`.
   - Writes each ETF to `data/raw/yahoo/<ticker>.parquet` so future work reuses cached files.

2. `scripts/R/build_taa_portfolio.R`
   - Reads both the SAA baseline and the zero-sum TAA deviations.
   - Expands each across the trading calendar, sums them to net weights (enforcing 1.0 total exposure) and injects a synthetic `CASH` series if no data is provided.
   - Joins ETF returns, computes strategy level returns/NAV, and drops parquet output in `data/processed/taa_portfolio_returns.parquet`.
   - Exports the latest SAA, TAA, and net weights snapshot to `logs/taa/latest_weights.csv` so discretionary notes can reference exactly what is in the book.

## Allocation policy
- **SAA weights** live in `data/reference/saa_weights_history.csv` and *must* sum to 1.0 for each effective date (including the 10% cash sleeve).
- **TAA deviations** live in `data/reference/taa_weights_history.csv` and *must* sum to 0.0 so every tilt is self-funded (e.g. +5% TLT, -5% CASH).
- Use the same `strategy` label in both files so the scripts can marry the baselines and deviations.
- Never rely on Git history alone—append rows for every rebalance to both files as needed, then check them into version control.
- Optional: keep a short Markdown note in `logs/taa/` per rebalance that links thesis ↔ the weights inserted on that date.

## Typical workflow
```
# 1. Update raw data (override start/end dates if needed)
Rscript scripts/R/fetch_yahoo_data.R --start 2015-01-01

# 2. Append/adjust SAA + TAA rows in data/reference/saa_weights_history.csv and data/reference/taa_weights_history.csv

# 3. Rebuild the portfolio view
Rscript scripts/R/build_taa_portfolio.R
```
