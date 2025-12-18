# Config Directory

Centralizes knobs that define the investable universe, strategic baselines, and data plumbing. Sub-folders:

- `allocations/` – current SAA, guardrails, and any TAA policy inputs.
- `instruments/` – canonical tickers, ETF lists, contract metadata.
- `data_sources/` – credentials and pull parameters for APIs or public feeds.

Update these files before running portfolio or model pipelines so downstream scripts pick up the latest assumptions.
