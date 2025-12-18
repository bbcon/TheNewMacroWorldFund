# Trade Log: US Equities OW vs USD Cash

- **Trade ID:** TAA-2024-01
- **Status:** Closed
- **Strategy Sleeve:** core_taa
- **Entry Date:** 2024-04-25
- **Exit Date:** 2024-11-15
- **Expression:** +25 bps SPY / -25 bps CASH
- **Sizing Rationale:** Small starter size sized to test the Liberation Day tariff fallout narrative without breaching the 30% gross cap.

## Thesis
- Setup: markets appeared to overreact to the short-term economic fallout risk from the Liberation Day tariffs; US equity beta looked oversold relative to medium-term earnings support.
- Macro triggers: expectation that any tariff-related demand hit would take time to appear in data, while positioning was light after the shock.
- Risks / invalidation: genuine demand shock showing up earlier than expected, or a policy response that tightened financial conditions faster than priced.

## Implementation & Risk
- Instruments used: +25 bps SPY funded via -25 bps USD cash sleeve.
- Data/model references: equity breadth diagnostics plus policy tracker in `models/macro_regime` (to be refreshed before sizing up).
- Risk budget: fits inside the 150 bp trade risk allowance and keeps gross leverage inside guardrails.

## Outcome & Review
- Exit rationale: chose to head to the sidelines ahead of NVDA earnings (binary outcome with meaningful downside if AI sentiment rolled over) and to lock the tariff-driven rebound.
- Key takeaways: narrative trades tied to single catalysts should have explicit event exits; monitor AI leadership concentration when running equity beta risk.
- Analytics: run `Rscript scripts/R/trade_performance.R --trade-id TAA-2024-01 --long SPY --short CASH --entry 2024-04-25 --exit 2024-11-15` after refreshing prices; outputs land under `data/outputs/performance/trades/TAA-2024-01_{daily,summary}.csv`.
