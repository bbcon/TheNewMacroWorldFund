# Weekly Process Playbook

1. **Refresh data** using `scripts/R/fetch_yahoo_data.R` (and any other source scripts).
2. **Run models** via `scripts/pipelines/run_weekly_models.sh` (to be implemented) so diagnostics land in `data/outputs/models/`.
3. **Update allocations** if needed (`config/allocations/*` + `data/reference/*_weights_history.csv`).
4. **Record trades** in `logs/tactical_trades/` and update `data/reference/taa_weights_history.csv`.
5. **Publish summary** using `docs/templates/weekly_summary.md` → `logs/weekly_macro/` and export charts to `reports/weekly_pack/` and `reports/performance/`.
6. **Review prior trades** pulling source notes from `logs/postmortems/` and, if relevant, add curated insights to `reports/trade_reviews/`.
