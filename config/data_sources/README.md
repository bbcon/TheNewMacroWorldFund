# Data Sources

Describe how each dataset is fetched and refreshed. Example layout:

- `yahoo.yml` – ticker list, fields, and frequency for the ETF price pulls.
- Additional files for macro series (FRED, IMF, etc.) as they come online.

Keep secrets out of version control; use environment variables or `.Renviron` for credentials.
