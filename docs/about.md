# The New Macro World Fund

## Philosophy

The New Macro World Fund is a personal macro-research and portfolio journal built for transparency, discipline, and continuous learning. It pairs structured quantitative tools with discretionary judgement across asset classes.

- **SAA (Strategic Asset Allocation):** expresses long-horizon themes (geopolitics, energy transition, fiscal sustainability, AI-driven change) and aims to capture structural premia.
- **TAA (Tactical Asset Allocation):** expresses medium-term macro mispricings across assets; focused on timely entries/exits and self-funded tilts.

## Instruments & Benchmarks

- Multi-asset, liquid ETFs across equities, sovereigns, FX, and commodities; occasional use of short-term futures for curve expression.
- Sector themes via sector ETFs/commodities; macro regimes via relative weights in rates vs equities.
- Benchmark: a 60/40 portfolio aligned with the SAA regional mix.

## Workflow (high level)

1. Ingest ETF data (currently Yahoo Finance) using `scripts/R/fetch_yahoo_data.R`; tickers defined in `config/instruments/etf_universe.yml`.
2. Build portfolios from SAA/TAA weight histories; enforce SAA=1.0, TAA=0.0 (self-funded) tilts.
3. Log trades in `data/reference/taa_weights_history.csv` and narratives in `logs/tactical_trades/*.md`; run `scripts/R/run_all_trade_perf.R` to generate per-trade analytics.
4. Aggregate and export: `scripts/R/aggregate_trades.R` → `scripts/R/export_site_data.R` to refresh the website data.
5. Review outcomes and update post-mortems to reinforce the learning loop.
