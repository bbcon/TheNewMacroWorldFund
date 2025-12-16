# CONTEXT — The New Macro World Fund

## Purpose
This repository is a structured macro-research and portfolio journal designed to:
1. Make discretionary macro calls fully transparent.
2. Build a credible and reviewable track record.
3. Serve as a learning tool to continuously refine a discretionary macro strategy over time.

The focus is on decision quality as much as performance: documenting assumptions, testing them through markets, and reviewing outcomes honestly.

---

## Core Principles
- Discretionary macro, supported by structure.
- Transparency over optimisation.
- Learning and refinement through systematic post-mortems.
- Cross-asset perspective (rates, equities, credit, FX, commodities).
- Use only easily accessible, reproducible data.

---

## Data Constraint
All analysis and models rely exclusively on:
- public or low-friction data sources,
- liquid market proxies,
- ETF prices where possible (e.g. via Yahoo Finance).

No proprietary or opaque datasets are assumed.

---

## Decision Layers

### Strategic Asset Allocation (SAA)
- Long-run structural themes and regime beliefs.
- Provides the macro context for tactical risk-taking.

### Tactical Asset Allocation (TAA)
- Discretionary macro trades (weeks to months).
- Each trade is logged with thesis, drivers, implementation, risks, and exit criteria.
- All trades are reviewed ex-post to refine the strategy.

---

## Role of Models
Models are decision-support and learning tools, not black-box alpha engines.

They are used to:
- summarise macro information consistently,
- classify regimes and risk environments,
- map macro states to cross-asset implications,
- discipline trade entry and review.

Models must be:
- transparent and interpretable,
- reproducible,
- stable across reasonable specifications.

---

## Core Model Families (MVP)
- Macro regime model (growth, inflation, policy, risk premia)
- Rates curve diagnostics (level / slope)
- Policy pricing vs market expectations
- Inflation expectations proxies
- Risk appetite / financial conditions indicators

---

## Repository Structure (simple, evolving)

- data/: raw and processed public data
- models/: reusable diagnostics and regime tools
- research/: SAA themes and TAA trade ideas
- logs/: trade log and research notes
- scripts/: data loading and analytics helpers

The structure is intentionally minimal and expands only when needed.

---

## Workflow
1. Update public market and macro data.
2. Run models and diagnostics.
3. Review SAA context and TAA opportunities.
4. Log decisions transparently.
5. Review closed trades and extract lessons.
6. Commit changes to preserve an auditable history.

---

## Non-Goals
- No high-frequency trading.
- No fully automated execution.
- No black-box machine learning.
- No reliance on proprietary datasets.

---

## Summary
This repository is a transparent, reproducible macro decision journal that links macro reasoning to portfolio actions and uses systematic review to improve discretionary macro investing over time.

# Codex specifics

## Constraints
- Work in R
- Reproducibility > speed
- Avoid repo-wide refactors
- Ask before touching config or renv.lock
- TAA weights sum up to zero because these are to be interpreted as deviations from the SAA weights
- SAA weights contain a cash allocation of 10% to allow directional calls against cash




## What NOT to do
- Don’t invent APIs or files
- Don’t scan the whole repo unless asked
