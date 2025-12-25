# The New Macro World Fund

## Philosophy

The New Macro World Fund is a personal macro-research and portfolio journal built for transparency, discipline, and continuous learning. It pairs structured quantitative tools with discretionary judgement across asset classes.

- **SAA (Strategic Asset Allocation):** expresses long-horizon themes (geopolitics, energy transition, fiscal sustainability, technological change) and aims to capture structural premia.
- **TAA (Tactical Asset Allocation):** expresses medium-term macro mispricings across assets; focused on timely entries/exits.

## Instruments & Benchmarks

- Multi-asset, liquid ETFs across equities, sovereigns, FX, and commodities; occasional use of short-term futures for curve expression.
- Sector themes via sector ETFs/commodities; macro regimes via relative weights in rates vs equities.

# Strategic Asset Allocation (SAA)

## I. Objective & Investment Philosophy

The Strategic Asset Allocation (SAA) defines the **long-term capital allocation** of the fund across asset classes, regions, and structural themes.  
It reflects **persistent macroeconomic forces** rather than cyclical or short-term tactical views.

The SAA is designed to capture **structural return drivers** in a world characterised by:
- Rising capital intensity (energy, infrastructure, defence)
- Geopolitical fragmentation
- The coming era of fiscal dominance
- Technology-driven productivity shifts, led by AI, climate change and the shift towards electrification

Tactical Asset Allocation (TAA) decisions are implemented **around** this strategic backbone.

---

## II. Strategic Macro Regime Assumptions

The SAA is anchored around the following long-run macro assumptions:

### 1. Electrification & Energy Security
Electricity demand is structurally rising, driven by AI, data centres, electrification of transport and heating, and energy security considerations. Grid infrastructure is the binding constraint of the transition.

### 2. Geopolitical Fragmentation
The global economy is moving toward strategic blocs, increasing defence spending, reshoring, and challenging business models.

### 3. Fiscal Dominance
High public debt levels constrain monetary policy independence, increasing inflation volatility and reducing the likelihood of a return to structurally low real rates.

### 4. China as an Engineering Superpower
China dominates large segments of the electric and industrial stack (solar, batteries, EVs, power equipment). Under-ownership and geopolitical discounting create asymmetric long-term opportunities.

### 5. US Innovation Exceptionalism (without Macro Exceptionalism)
The United States remains the global leader in frontier innovation, particularly in AI, software, and platform-based industries. Its ecosystem for creativity, capital formation, and scalable business models is unmatched. This justifies a **large strategic allocation to US equities**, even as macro, fiscal, and geopolitical headwinds warrant a relative rebalancing at the margin.

---

## III. Reference Benchmark (Neutral Allocation)

The benchmark represents a **neutral global macro portfolio**, absent thematic or geopolitical tilts.

### Asset Class Weights

- **Equities:** 55%
- **Sovereign Fixed Income:** 35%
- **Commodities:** 10%

### Equity Benchmark (55%)

**Regional Equities – 100%**
- United States: 50%
- Europe: 30%
  - Germany: 33%
  - France: 33%
  - Spain: 17%
  - Italy: 17%
- China: 20%

**Sectoral / Thematic Equities:** 0%

### Sovereign Bonds (35%)

- US Treasuries: 50%
- German Bunds: 25%
- UK Gilts: 25%

### Commodities (10%)

- Gold: 100%

---

## IV. Strategic Asset Allocation (SAA)

Relative to the benchmark, the SAA introduces **structural thematic overlays** and **regional reallocations**, while maintaining broad diversification.

### A. Equity Allocation – Structural Thematic Layer

- Reduce **regional equity exposure** from 100% to **80%**
- Introduce **20% thematic equity exposure**  
  → Equivalent to **11% of total portfolio** (20% × 55%)

#### Thematic Equity Allocation

| Theme | Weight | Rationale |
|------|--------|-----------|
| Electric Grid Infrastructure | 40% | Grid expansion is the key bottleneck for AI power demand, electrification, and energy security |
| Solar | 20% | Fastest scalable source of new electricity; critical for AI and geopolitical autonomy |
| Chile / Copper | 20% | Copper is the core metal of electrification |
| Defence | 20% | Persistent increase in defence spending in a fragmented geopolitical world |

---

### B. Regional Equity Rebalancing

#### United States: Relative Underweight, Strategic Core
- Reduce allocation from **50% → 45%**, while remaining the **largest regional exposure**

**Narrative:**  
The United States continues to dominate in frontier technologies, particularly AI, software, and platform-based industries. Its capacity to generate world-leading companies through innovation, creativity, and efficient capital allocation remains unparalleled. This structural strength justifies a **high absolute allocation** within the portfolio.

The underweight reflects not a loss of confidence in US innovation, but a **relative macro rebalancing** in response to rising fiscal imbalances, geopolitical friction, and trade policy uncertainty. Recent trade policies and overall approach to international policies are liquidating a lot of goodwill and reinforcing this trend.

---

#### China: Structural Overweight
- Increase allocation from **20% → 30%**

**Narrative:**  
China is a global engineering powerhouse and a leader across large segments of the electric stack. The combination of industrial scale, cost leadership, and under-ownership creates attractive long-term asymmetry. Concerns about balance sheet recessions are justified, but the innovation capacity of the country is underappreciated.

---

#### Europe: Neutral Allocation
- Reduce European allocation from **30% to 25%**

**Narrative:**  
While defence and infrastructure spending are rising, sustained conviction in a structural German fiscal regime shift remains limited at this stage. The ongoing geopolitical restructuring and the rise of protectionist policies is further straining the export-driven business models of many European countries.

---

### C. Fixed Income & Credit Strategy

#### Sovereign Bonds
Maintain core exposure to developed-market sovereign bonds as:
- Portfolio stabilisers
- Recession hedges
- Volatility dampeners

The traditional diversification role of fixed income will be regularly reviewed in light of accumulating evidence that supply-side shocks—driven by geopolitics, the energy transition, and climate change—may be more frequent and persistent than in the past, which could weaken the historical equity-bond relationship.

#### High Yield Credit (Macro Overlay)
- Introduce **High Yield credit CDS exposure**

**Narrative:**  
In a regime of fiscal dominance, deteriorating sovereign balance sheets have coincided with **compressed credit spreads**, ceteris paribus.

---

### D. Commodities & Real Assets

- Maintain **Gold** as a strategic hedge against:
  - Fiscal dominance
  - Geopolitical stress
  - Monetary regime uncertainty


---

## V. Summary of Structural Tilts

| Theme | Position |
|------|----------|
| US Innovation | Strategic Core |
| Electrification & Grid | Strong Overweight |
| Defence | Overweight |
| China | Overweight |
| Nominal Growth Assets | Overweight |
| Duration | Neutral / Tactical |
| Gold | Strategic Hedge |

---

## VI. Implementation & Governance

- Implementation via liquid ETFs and CDS
- SAA reviewed annually or upon major macro regime shifts
- TAA may temporarily deviate from SAA within defined risk limits

---



## Workflow (high level)

1. Ingest ETF data (currently Yahoo Finance) using `scripts/R/fetch_yahoo_data.R`; tickers defined in `config/instruments/etf_universe.yml`.
2. Build portfolios from SAA/TAA weight histories; enforce SAA=1.0, TAA=0.0 (self-funded) tilts.
3. Log trades in `data/reference/taa_weights_history.csv` and narratives in `logs/tactical_trades/*.md`; run `scripts/R/run_all_trade_perf.R` to generate per-trade analytics.
4. Aggregate and export: `scripts/R/aggregate_trades.R` → `scripts/R/export_site_data.R` to refresh the website data.
5. Review outcomes and update post-mortems to reinforce the learning loop.
