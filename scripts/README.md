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
- `R/run_all_trade_perf.R` – read `data/reference/taa_weights_history.csv` (rows with `trade_id`), infer long/short legs, and call `trade_performance.R` for each trade.
- `run_all_trade_perf.sh` – parse TAA trade logs (`logs/tactical_trades/taa-*.md`) and run `trade_performance.R` for each.
