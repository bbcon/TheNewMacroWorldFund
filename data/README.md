# Data Layers

- `raw/` – direct downloads (e.g., Yahoo CSVs). Never edit manually.
- `interim/` – cleaned intermediate tables ready for modeling.
- `reference/` – curated inputs such as SAA/TAA history.
- `processed/` – legacy location for derived series (kept for backward compatibility).
- `outputs/` – finalized model signals and portfolio performance used by reports.

Pipelines should write from raw → interim → outputs so provenance stays clear.
