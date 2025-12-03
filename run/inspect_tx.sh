#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <tx-json-file>"
  exit 1
fi

TX_JSON_FILE="$1"

if [[ ! -f "$TX_JSON_FILE" ]]; then
  echo "❌ File not found: $TX_JSON_FILE"
  exit 1
fi

echo "🔎 Inspecting $TX_JSON_FILE"
echo

# Basic metadata from the JSON envelope
TYPE=$(jq -r '.type // "Unknown"' "$TX_JSON_FILE")
DESC=$(jq -r '.description // "No description"' "$TX_JSON_FILE")
CBOR_HEX=$(jq -r '.cborHex // ""' "$TX_JSON_FILE")
CBOR_LEN=${#CBOR_HEX}

echo "Type:        $TYPE"
echo "Description: $DESC"
echo "CBOR length: $CBOR_LEN characters"
echo

# Very basic classification
case "$TYPE" in
  "Unwitnessed Tx ConwayEra")
    echo "📌 This looks like an UNSIGNED (raw) Conway-era transaction."
    ;;
  "Witnessed Tx ConwayEra")
    echo "📌 This looks like a SIGNED (witnessed) Conway-era transaction."
    ;;
  *)
    echo "📌 Unknown or unsupported type for simple inspection."
    ;;
esac