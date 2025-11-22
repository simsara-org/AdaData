#!/usr/bin/env bash
# AdaData – Air‑Gapped Cardano Token Metadata Toolkit
# ---------------------------------------------------
# validate_keys.sh
# Local sanity checks for policy keys and registry metadata
# ===========================================================================

#!/usr/bin/env bash
set -euo pipefail

POLICY_DIR="${1:-./cardano_policy}"

echo "🔍 Validating asset package in: $POLICY_DIR"
echo

err=0

check_hex() {
  [[ "$1" =~ ^[0-9a-fA-F]+$ ]]
}
# --- policy.id ---
PID=$(tr -d '\n\r' < "$POLICY_DIR/keys/policy.id")

if [[ ${#PID} -eq 56 ]] && check_hex "$PID"; then
  echo "✔ policy.id looks correct ($PID)"
else
  echo "❌ policy.id invalid or wrong length"; err=1
fi

# --- asset name / hex ---
NAME=$(<"$POLICY_DIR/asset_name.txt")
NAME_HEX=$(<"$POLICY_DIR/asset_name_hex.txt")
# shellcheck disable=SC2059
if [[ -z "$NAME" ]]; then
  echo "❌ asset_name.txt is empty"; err=1
elif [[ ${#NAME_HEX} -ne $(( ${#NAME} * 2 )) ]]; then
  echo "❌ asset_name_hex.txt length mismatch"; err=1
elif ! check_hex "$NAME_HEX"; then
  echo "❌ asset_name_hex.txt contains non‑hex characters"; err=1
else
  echo "✔ Asset name '$NAME' / hex ok"
fi

# --- asset_id.txt ---
ASSET_ID=$(<"$POLICY_DIR/asset_id.txt")
if [[ "$ASSET_ID" == "$PID$NAME_HEX" ]]; then
  echo "✔ asset_id.txt matches policy + name_hex"
else
  echo "❌ asset_id.txt mismatch"; err=1
fi

# --- metadata.json ---
if command -v jq >/dev/null 2>&1; then
  jq empty "$POLICY_DIR/metadata.json" && echo "✔ metadata.json syntax ok"
else
  echo "⚠ jq not found; skipping metadata.json check"
fi

# --- policy.script ---
if command -v jq >/dev/null 2>&1; then
  jq empty "$POLICY_DIR/scripts/policy.script" && echo "✔ policy.script syntax ok"
fi

# --- signed registry metadata ---
if [[ -f "$POLICY_DIR/signed_registry_metadata.json" ]]; then
  jq empty "$POLICY_DIR/signed_registry_metadata.json" && echo "✔ signed_registry_metadata.json syntax ok"
fi

# --- logo base64 ---
if base64 --decode "$POLICY_DIR/logo_base64.txt" >/dev/null 2>&1; then
  echo "✔ logo_base64.txt decodes successfully"
else
  echo "⚠ logo_base64.txt may not be valid base64"
fi

[[ $err -eq 0 ]] && echo "✅ Asset package verification complete!" || echo "❌ One or more checks failed."

exit $err
