# Allocation Configs

- `saa_current.yml` holds the live strategic mix (weights sum to 1.0 incl. cash).
- `taa_rules.yml` documents any tactical guardrails or buckets used for trade sizing.

Whenever you change these, append the historical record in `data/reference/*_weights_history.csv` so the reconstruction stays in sync.
