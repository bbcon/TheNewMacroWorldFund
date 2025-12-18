# Scripts

Automation entry points live here:

- `R/` – existing R scripts for data pulls and portfolio construction.
- `python/` – space for analytics/helpers not tied to R.
- `pipelines/` – orchestration scripts (e.g., `run_weekly_models.sh`).

Keep scripts idempotent and rely on configs under `config/` rather than hard-coded values.

### Key entry points
- `R/fetch_yahoo_data.R` – refresh ETF prices in `data/raw/yahoo/`.
- `R/build_taa_portfolio.R` – merge SAA + TAA weights into portfolio returns and weight snapshots.
- `R/trade_performance.R` – generate per-trade analytics (spread returns, drawdowns) and write them to `data/outputs/performance/trades/`.
