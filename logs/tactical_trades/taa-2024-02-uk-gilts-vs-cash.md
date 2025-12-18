# Trade Log: 10Y Gilts OW vs USD Cash

- **Trade ID:** TAA-2024-02
- **Status:** Open
- **Strategy Sleeve:** core_taa
- **Entry Date:** 2024-05-15
- **Exit Date:** Open
- **Expression:** +35 bps IGLT (10Y gilts) / -35 bps CASH
- **Sizing Rationale:** Larger starter size given the structural nature of the trade but still well within gross limits; GBP exposure hedged via cash leg.

## Thesis
- Setup: UK policy rates are pinned near restrictive levels that the real economy cannot tolerate indefinitely; long Gilts embed fat risk premia.
- Macro triggers: expectation of slowing UK data and a turn in BoE rhetoric as inflation normalizes, compressing term premium on the 10Y point.
- Risks / invalidation: sticky services inflation, GBP devaluation that forces higher term premia, or fiscal slippage that re-prices Gilts wider.

## Implementation & Risk
- Instruments used: +35 bps IGLT funded via -35 bps USD cash sleeve (FX hedged separately within the sleeve).
- Data/model references: rates curve diagnostics in `models/rates_curve` plus policy tracker outputs to monitor BoE expectations.
- Risk budget: 35 bps of gross tilts keep exposure plus carry manageable for a long-duration position.

## Outcome & Review
- Exit rationale: Pending; trade is intended as a slower-burn macro mean reversion.
- Monitoring plan: reassess after each BoE meeting and when monthly CPI/utilities policy data are released.
- Analytics: run `Rscript scripts/R/trade_performance.R --trade-id TAA-2024-02 --long IGLT --short CASH --entry 2024-05-15` after each data refresh to keep rolling performance under `data/outputs/performance/trades/TAA-2024-02_{daily,summary}.csv`.
