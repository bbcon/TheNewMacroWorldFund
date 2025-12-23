# Trade Log: OW US vs UW China Equity

- **Trade ID:** TAA-LONGUSvsCN
- **Status:** Open
- **Strategy Sleeve:** macro_core
- **Entry Date:** 2024-02-01
- **Exit Date:** 2025-11-15
- **Expression:** +5 bps US EQ Momentum / -5 bps China EQ Momentum
- **Sizing Rationale:** Small relative-value tilt to express US earnings momentum and cleaner policy path, fully self-funded with CN underweight.

## Thesis
- Setup: US large-cap earnings revisions and liquidity backdrop outpace China, while CN still faces policy/FX overhangs; relative trend favors US.
- Macro triggers: sustained US EPS upgrades and stable USD liquidity vs. fading CN credit impulse.
- Risks / invalidation: CN policy surprise that restores growth, USD spike that crimps US risk appetite, or US tech leadership unwind.

## Implementation & Risk
- Instruments used: +5 bps USEQMA vs -5 bps CNEQMA.
- Data/model references: revisions tracker and liquidity dashboards; CN credit pulse monitors.
- Risk budget: small starter tilt; can be sized up if breadth improves and CN macro stabilizes without outperforming.

## Outcome & Review
- Exit rationale: Planned 2025-11-15 or earlier if US/CN relative trend breaks 200d or CN stimulus forces relative rerate.
- Monitoring plan: watch US EPS revisions, CN TSF, and US/CN index relative strength weekly.
- Analytics: run `Rscript scripts/R/trade_performance.R --trade-id TAA-LONGUSvsCN --long USEQMA --short CNEQMA --entry 2024-02-01 --exit 2025-11-15` after price refreshes to update `data/outputs/performance/trades/TAA-LONGUSvsCN_{daily,summary}.csv`.
