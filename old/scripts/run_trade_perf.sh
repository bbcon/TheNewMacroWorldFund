#!/usr/bin/env bash
set -euo pipefail

# Simple wrapper to run the trade performance script with configurable inputs.
# Override defaults via env vars when calling, e.g.:
#   LONG=TLT SHORT=CASH ENTRY=2024-03-01 scripts/run_trade_perf.sh

TRADE_ID="${TRADE_ID:-TAA-2024-01}"
LONG="${LONG:-SPY}"
SHORT="${SHORT:-CASH}"
ENTRY="${ENTRY:-2024-04-25}"
EXIT="${EXIT:-}"                     # leave empty for open trades
PRICE_DIR="${PRICE_DIR:-data/raw/yahoo}"
OUTPUT_DIR="${OUTPUT_DIR:-data/outputs/performance/trades}"
CASH_TICKER="${CASH_TICKER:-CASH}"

cmd=(
  Rscript scripts/R/trade_performance.R
  --trade-id "$TRADE_ID"
  --long "$LONG"
  --short "$SHORT"
  --entry "$ENTRY"
)

if [[ -n "$EXIT" ]]; then
  cmd+=(--exit "$EXIT")
fi

cmd+=(
  -p "$PRICE_DIR"
  -o "$OUTPUT_DIR"
  --cash-ticker "$CASH_TICKER"
)

echo "Running: ${cmd[*]}"
"${cmd[@]}"
