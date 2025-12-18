# Session Summaries

## 2025-12-18
- Finalized the repo layout to support weekly macro work, adding config/data/log/report docs plus templates for summaries and trades.
- Logged two historical tactical trades (SPY vs CASH, IGLT vs CASH) with full thesis, implementation notes, and clear analytics instructions.
- Added `scripts/R/trade_performance.R` and expanded documentation so every trade log can point to reproducible performance outputs in `data/outputs/performance/trades/`.
- Updated README/workflow guidance to map the new tooling into the weekly operating rhythm.

## 2024-?? (legacy summary)
# Last Session Summary

- Added repo scaffolding for ETF data ingestion: `config/instruments/etf_universe.yml`, raw/processed data dirs, and R scripts to fetch Yahoo prices and build TAA portfolio returns.
- Introduced explicit SAA vs TAA history files so baseline allocations sum to 1.0 (with 10% cash) and tactical tilts sum to 0.0, enabling accurate historical reconstruction.
- Updated `docs/workflow/data_workflow.md` and `ReadMe.md` to document the workflow, allocation policy, and the R command flow; sample weights now live under `data/reference/` for immediate testing.
