# Scripts

Current workflow is intentionally linear and lives under `scripts/R` with numbered entry points:

1. `1fetch_raw_data.R` – pull Datastream series defined in `config/instruments/etf_universe_datastream.yml` into `data/raw/datastream/`.
2. `2raw_data_to_returns.R` – convert raw series to daily local + USD returns (cash/rates hedging logic included) and write summaries.
3. `3build_portfolios.R` – derive SAA and benchmark weights from the config, overlay TAA trades from `data/reference/taa_weights_history.csv`, and write portfolio returns + latest weights.
4. `4portfolio_metrics.R` – compute NAV, drawdowns, rolling stats, and summary metrics for SAA, TAA, fund, and benchmark.
5. `5load_trade_narratives.R` – filter trade narratives in `logs/tactical_trades/` to active TAA trade_ids and output JSON for the site.
6. `6export_site_data.R` – convert parquet outputs to JSON in `docs/data/` for site consumption.
7. `7render_site.R` – render `docs/index.Rmd` to `docs/index.html`.

Previous scripts and helper folders are parked under `old/` for reference; only the numbered scripts above are meant to be used on this branch.
