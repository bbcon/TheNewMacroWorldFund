# Data + TAA Workflow

The repo now separates configuration, raw data, processed artefacts, and logs so ETF updates and TAA reviews are reproducible.

## Key directories
- `config/instruments/etf_universe.yml` — single source of truth for ETFs (tickers, roles, regions). Extend this folder with other assets as the universe grows.
- `config/allocations/saa_current.yml` — live SAA mix; mirrors the latest row appended to the SAA history CSV.
- `config/allocations/taa_rules.yml` — guardrails for tactical tilts (risk budget, horizon, etc.).
- `config/data_sources/yahoo.yml` — parameters used by the Yahoo pull script.
- `data/raw/yahoo/` — one parquet file per ETF straight from Yahoo Finance. Never edit manually.
- `data/interim/` — cleaned/merged tables used as model inputs.
- `data/reference/saa_weights_history.csv` — dated SAA allocations that must sum to **1.0** (includes the 10% cash sleeve that finances tactical tilts).
- `data/reference/taa_weights_history.csv` — dated TAA deviations that must sum to **0.0** (positive tilts must be funded via cash or other sleeves).
- `data/processed/` — legacy location for derived series; kept for backward compatibility with existing scripts.
- `data/outputs/models/` — final model signals or diagnostics exported for reports.
- `data/outputs/performance/` — aggregated portfolio returns/equity curves consumed by reporting scripts.
- `logs/weekly_macro/` — Markdown summaries of the weekly macro & market view (use the template in `docs/templates/`).
- `logs/tactical_trades/` — trade-by-trade notes plus the latest weights snapshot exported by the TAA builder.
- `logs/postmortems/` — lessons learned after closing trades; reference them when adding new risk.
- `logs/sessions/` — rolling work session notes (e.g., `last_session.md`).

## R scripts
1. `scripts/R/fetch_yahoo_data.R`
   - Reads `config/instruments/etf_universe.yml` (and the Yahoo settings file as it evolves).
   - Pulls daily prices from Yahoo via `quantmod`.
   - Writes each ETF to `data/raw/yahoo/<ticker>.parquet` so future work reuses cached files.

2. `scripts/R/build_portfolio.R`
   - Reads both the SAA baseline and the zero-sum TAA deviations.
   - Expands each across the trading calendar, sums them to net weights (enforcing 1.0 total exposure) and injects a synthetic `CASH` series if no data is provided.
   - Joins ETF returns, computes strategy level returns/NAV, and drops parquet output in `data/outputs/performance/taa_portfolio_returns.parquet` for downstream reporting.
   - Exports the latest SAA, TAA, and net weights snapshot to `logs/tactical_trades/latest_weights.csv` so discretionary notes can reference exactly what is in the book.

3. `scripts/R/trade_performance.R`
   - Consumes price data from `data/raw/yahoo/` (plus synthetic cash returns) and calculates long/short leg returns between entry/exit dates.
   - Writes daily spread returns and summary statistics to `data/outputs/performance/trades/<trade_id>_{daily,summary}.csv`.
   - Use this after logging a trade to back up the narrative with objective performance diagnostics.

4. `scripts/R/aggregate_trades.R`
   - Sweeps `_daily` and `_summary` files in `data/outputs/performance/trades/` to build a portfolio-level trade equity curve, drawdown, and refreshed trade metrics.
   - Saves parquet outputs and ggplot charts under `reports/figures/`.

5. `scripts/R/compute_portfolio_metrics.R`
   - Reads `taa_portfolio_returns.parquet` and computes since-inception/YTD stats, rolling returns/vol/Sharpe, and drawdowns.
   - Writes parquet tables plus ggplot charts (`portfolio_nav.png`, `portfolio_drawdowns.png`) to `reports/figures/`.

6. `scripts/R/attribution.R`
   - Decomposes daily return into SAA vs TAA contribution using historical weights and price data.
   - Writes `data/outputs/performance/attribution.parquet` and a stacked bar ggplot chart in `reports/figures/`.

7. `scripts/R/export_site_data.R`
   - Converts parquet outputs into compact JSON files under `docs/data/` for the static site.

## Allocation policy
- **SAA weights** live in `data/reference/saa_weights_history.csv` and *must* sum to 1.0 for each effective date (including the 10% cash sleeve).
- **TAA deviations** live in `data/reference/taa_weights_history.csv` and *must* sum to 0.0 so every tilt is self-funded (e.g. +5% TLT, -5% CASH).
- Use the same `strategy` label in both files so the scripts can marry the baselines and deviations.
- Never rely on Git history alone—append rows for every rebalance to both files as needed, then check them into version control.
- Optional: keep a short Markdown note in `logs/tactical_trades/` per rebalance that links thesis ↔ the weights inserted on that date.

## Typical workflow
```
# 1. Update raw data (override start/end dates if needed)
Rscript scripts/R/fetch_yahoo_data.R --start 2015-01-01

# 2. Append/adjust SAA + TAA rows in data/reference/saa_weights_history.csv and data/reference/taa_weights_history.csv

# 3. Rebuild the portfolio view
Rscript scripts/R/build_portfolio.R

# 4. Refresh trade-level analytics (example for trade TAA-2024-01)
Rscript scripts/R/trade_performance.R --trade-id TAA-2024-01 --long SPY --short CASH --entry 2024-04-25 --exit 2024-11-15

# 5. Aggregate trades into a portfolio-level view
Rscript scripts/R/aggregate_trades.R

# 6. Compute portfolio metrics + charts (NAV, drawdown, rolling stats)
Rscript scripts/R/compute_portfolio_metrics.R

# 7. Run attribution (SAA vs TAA contribution)
Rscript scripts/R/attribution.R

# 8. Export JSON for the static site
Rscript scripts/R/export_site_data.R

# 9. (Optional) Knit an RMarkdown report and open docs/index.html for the latest visuals
```
