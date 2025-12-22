# The New Macro World Fund

## Philosophy

**The New Macro World Fund** is a personal macro-research and portfolio journal designed to provide **full transparency on discretionary macro decisions**, build a **credible track record**, and support **continuous learning and strategy refinement** over time. It reflects a professional, investment-oriented approach to macro strategy across asset classes, combining structured quantitative tools with discretionary judgement.

The strategy is made of two blocks: 

**SAA:** the SAA aims to identify and profit from structural changes in the world economy, driven by the ongoing geopolitical restructuring and its implications for economic and trade policies, changes in energy systems driven by national security and climate considerations, and the profound technological changes that AI is creating. It also recognises the unsustainable fiscal trajectory of a number of developed economies.

**TAA:** the TAA aims to benefit from mispricing of macroeconomic fundamentals across asset classes. These are more short-term in nature. Please add a bit more here to make it look more professional.

## Instruments, asset classes, and benchmarks

The fund invests is multi-asset and invests in liquid ETFs of major asset classes. The core asset classes are: equities, sovereigns, FX, and commodities. It retains the flexibility to invest in short-term futures (to play the curve). Can you add some stuffs here to make it more professional? Strategic sectoral views are expressed through exposure to sector specific ETFs and (potentially) specific commodities that play a theme. Macro regime views are expressed through the relativel weights of fixed income versus equities. It invests in both developed and emerging markets.

The benchmark is a simple 60/40 portfolio with a similar regional distribution than the SAA portfolio.


---

# Workflow

## Data ingestion

The script 'scripts/R/fetch_yahoo_data.R' loads ETFs data from Yahoo Finance. The tickers and their description are defined in a config file located in 'config/instruments/etf_universe.yml'. The fact that ETFs are retrieved from Yahoo provides full transparency and reproducibility. However, this comes at two serious costs: i) data may not be reliable and may be retroactively adjusted, and ii) certain (a lot!) ETFs may not be available. The live portfolio will use data from Datastream (still to do).

The following CLI script can be run in the terminal:

Add rscript CLI command here.


## Portfolio construction and metrics

The script 'scripts/R/build_portfolio.R' (name needs to be adjusted) loads SAA and TAA weights from `data/weights/SAA_weights.csv' and 'data/weights/TAA_weights.csv', respectively. These two files contain the history of SAA and TAA weights. New trades, either changes in structural allocation or tactical trades are logged by adjusting these .csv files, making sure the date of the change is correctly set.

The script ensures that weights sum up to the required amount (1 for SAA, and 0 for TAA).

Portfolio returns are then constructed. Portfolio performance can truly be decomposed as the sum of SAA and TAA. The natural benchmark for the SAA is the benchmark portfolio, while the benchmark for TAA is absolute.

Finally, some summary statistics of the YTD and overall portfolio performance are displayed. 

Portfolio returns and portfolio metrics (both YTD and overall) are then output (as a list) in the folder 'outputs/portfolio/YYYYMMDD/portfolio_metrics.rds'. These portfolio metrics are run in a rmd (in 'reports/performance/portfolio_metrics.rmd0 which reads the latest available data) file that displays the latest results in a html format. These will then be displayed also in a tab of the fund website.





# OLD (KEEP FOR NOW)

---

## What This Repository Is

This repository documents:
- macro views and regime assessments,
- how those views are translated into investable trades,
- how risk is managed and expressed,
- and how outcomes are reviewed ex-post.

The objective is not only to measure performance, but to **evaluate decision quality**:  
*Was the macro view right? Was the trade expression appropriate? What should be done differently next time?*

---

## Investment Philosophy

- **Discretionary macro, disciplined by structure**  
  Final decisions are discretionary, but supported by systematic diagnostics and models.

- **Cross-asset by design**  
  Rates, equities, credit, FX, and commodities are analysed within a unified macro framework.

- **Transparency over optimisation**  
  Every trade is logged with its rationale, assumptions, risks, and exit criteria.

- **Learning-oriented**  
  Mistakes are documented and reviewed to refine the strategy over time.

---

## Strategic vs Tactical Layers

### Strategic Asset Allocation (SAA)
- Long-run structural themes (energy transition, geopolitics, demographics, climate risk, fiscal dominance, etc.).
- Provides the macro backdrop and regime beliefs that guide risk-taking.

### Tactical Asset Allocation (TAA)
- Medium-term discretionary macro trades (weeks to months).
- Each trade is documented from thesis to post-mortem.
- Focus on investable, liquid instruments.

---

## Models and Analytics

The repo includes a small set of **transparent, interpretable models** used as decision-support tools, not black-box alpha engines:

- Macro regime classification (growth, inflation, policy, risk premia)
- Rates curve diagnostics (level / slope via PCA-style approaches)
- Policy pricing vs market expectations
- Inflation expectations proxies
- Risk appetite and financial conditions indicators

All models rely **exclusively on easily accessible data**, with a strong preference for:
- public macro series,
- market data,
- and ETF prices (e.g. via Yahoo Finance).

This ensures full reproducibility and portability.

---

## What This Repository Is Not

- Not a fully systematic trading strategy
- Not high-frequency or execution-focused
- Not reliant on proprietary datasets
- Not performance-optimised at the expense of interpretability

---

## How to Read This Repo

- `config/` centralises the investable universe, strategic baselines, and data-source knobs.
- `data/` flows raw pulls → interim cleaning → reference histories → model/performance outputs.
- `models/` contains the diagnostics used to frame decisions.
- `scripts/` holds automation entry points (R, Python, and higher-level pipelines).
- `logs/` provides a transparent history of weekly macro notes, live trades, and post-mortems.
- `reports/` captures human-friendly outputs (weekly pack, performance, trade reviews).
- `docs/` stores playbooks, templates, and workflow guidance so the process is reproducible.
- `notebooks/` is reserved for exploratory analysis before code graduates into `models/` or `scripts/`.

Each trade idea can be traced from **macro thesis → implementation → outcome** using the combination of `logs/`, `data/reference`, and `reports/`.

## Weekly Operating Rhythm

1. **Macro & market summary** – draft via `docs/templates/weekly_summary.md`, publish to `logs/weekly_macro/`, and surface charts in `reports/weekly_pack/`.
2. **Run quant macro models** – execute scripts in `scripts/pipelines/` so outputs land in `data/outputs/models/` for dashboards.
3. **Log tactical trades** – capture lifecycle notes in `logs/tactical_trades/` (use `docs/templates/trade_log.md`) and append weight changes to `data/reference/taa_weights_history.csv`, then run `scripts/R/trade_performance.R` to back up the narrative with analytics in `data/outputs/performance/trades/`.
4. **Adjust SAA (when needed)** – edit `config/allocations/saa_current.yml` and document history in `data/reference/saa_weights_history.csv`.
5. **Display portfolio performance** – read the latest returns from `data/processed/taa_portfolio_returns.parquet` (and mirror into `data/outputs/performance/`) when building `reports/performance/`.
6. **Analyse previous trades** – use `logs/postmortems/` and promote insights into `reports/trade_reviews/` for easy recall.

---

**Bottom line:**  
This repository is a **transparent, professional macro decision journal** that demonstrates how macroeconomic thinking translates into portfolio decisions — and how those decisions improve through disciplined review.

## Getting Started with ETF Data + TAA

- Define ETFs once in `config/instruments/etf_universe.yml`; scripts treat this as the single source of truth.
- Maintain SAA baselines in `data/reference/saa_weights_history.csv` (weights sum to 1.0 and include the 10% cash sleeve that finances tactical tilts).
- Record TAA deviations in `data/reference/taa_weights_history.csv` (weights sum to 0.0 per rebalance so trades are self-funded vs cash/other sleeves).
- Pull Yahoo data with `Rscript scripts/R/fetch_yahoo_data.R` and build portfolio returns with `Rscript scripts/R/build_taa_portfolio.R`.
- See `docs/workflow/data_workflow.md` for the full workflow, directory layout, and logging conventions.
