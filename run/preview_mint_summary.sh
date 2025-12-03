#!/usr/bin/env bash
set -euo pipefail

TX_INFO_FILE="./tx/tx_input_info.txt"
METADATA_FILE="./cardano_policy/metadata.json"

if [[ ! -f "$TX_INFO_FILE" ]]; then
  echo "❌ TX info file not found: $TX_INFO_FILE"
  exit 1
fi

if [[ ! -f "$METADATA_FILE" ]]; then
  echo "❌ Metadata file not found: $METADATA_FILE"
  exit 1
fi

# Load values from tx_input_info.txt
# (this file is in KEY=VALUE format, so we can source it safely)
# It only contains public info, no keys.
source "$TX_INFO_FILE"

echo "================ Mint Preview ================"
echo "Policy ID:       $POLICY_ID"
echo "Asset Name:      $ASSET_NAME"
echo "Full Asset ID:   $ASSET"
echo "Amount to mint:  $AMOUNT"
echo "Payment address: $PAYMENT_ADDR"
echo "TX input:        $TX_IN"
echo "Timestamp:       $DATE"
echo

# Now parse metadata.json for human fields
# Your current structure (from earlier) is:
# {
#   "20": {
#     "<policy_id>": {
#       "<asset_name>": {
#         "name": "...",
#         "ticker": "...",
#         "description": "...",
#         "decimals": 4,
#         "logo": "https://..."
#       }
#     }
#   }
# }

POLICY_JSON_KEY="$POLICY_ID"
ASSET_JSON_KEY="$ASSET_NAME"

NAME=$(jq -r --arg pid "$POLICY_JSON_KEY" --arg an "$ASSET_JSON_KEY" '.["20"][$pid][$an].name // "N/A"' "$METADATA_FILE")
TICKER=$(jq -r --arg pid "$POLICY_JSON_KEY" --arg an "$ASSET_JSON_KEY" '.["20"][$pid][$an].ticker // "N/A"' "$METADATA_FILE")
DESCRIPTION=$(jq -r --arg pid "$POLICY_JSON_KEY" --arg an "$ASSET_JSON_KEY" '.["20"][$pid][$an].description // "N/A"' "$METADATA_FILE")
DECIMALS=$(jq -r --arg pid "$POLICY_JSON_KEY" --arg an "$ASSET_JSON_KEY" '.["20"][$pid][$an].decimals // "N/A"' "$METADATA_FILE")
LOGO=$(jq -r --arg pid "$POLICY_JSON_KEY" --arg an "$ASSET_JSON_KEY" '.["20"][$pid][$an].logo // "N/A"' "$METADATA_FILE")

echo "Token name:      $NAME"
echo "Ticker:          $TICKER"
echo "Description:     $DESCRIPTION"
echo "Decimals:        $DECIMALS"
echo "Logo URL:        $LOGO"
echo "=============================================="