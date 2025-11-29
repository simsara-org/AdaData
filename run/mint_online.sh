#!/usr/bin/env bash
set -euo pipefail
source ./run/ada_env.sh
# Include signing/submission helper
source "$(dirname "$0")/sign_and_submit.sh"

SOCKET_PATH=${CARDANO_NODE_SOCKET_PATH:-$(find / -type s -name "node.socket" 2>/dev/null | head -1)}
[[ -S "$SOCKET_PATH" ]] || { echo "❌ node.socket not found"; exit 1; }
export CARDANO_NODE_SOCKET_PATH="$SOCKET_PATH"

NETWORK="--mainnet"   # or --testnet-magic 1097911063
TX_DIR="./tx"
mkdir -p "$TX_DIR"

PAYMENT_ADDR_FILE="cardano_policy/keys/payment.addr"

# --- Wallet check & funding loop (improved) ---
if [ ! -s "$PAYMENT_ADDR_FILE" ]; then
  echo "⚠️  No wallet found. Generate or load one first."
  read -p "Generate new wallet now? (Y/N): " yn
  if [[ "$yn" =~ ^[Yy]$ ]]; then
      ./generate_wallet.sh
  else
      echo "Aborting mint build."
      exit 1
  fi
fi

PAYMENT_ADDR=$(<"$PAYMENT_ADDR_FILE")
RETRY_INTERVAL=30   # seconds between balance rechecks

echo "🔎 Checking wallet balance for ${PAYMENT_ADDR}..."
echo

while true; do
    # Query current UTxO set
    UTXO_JSON=$(cardano-cli query utxo --address "${PAYMENT_ADDR}" ${NETWORK} 2>/dev/null || true)

    # Sum ADA balance (if lines beyond header exist)
    TOTAL_ADA=$(echo "$UTXO_JSON" | awk 'NR>2 && NF {sum+=$3} END {printf "%.6f", sum/1000000}')

    # Determine if any valid UTxO exists with non‑zero total
    if [[ -n "$TOTAL_ADA" && $(echo "$TOTAL_ADA > 0" | bc -l) -eq 1 ]]; then
        echo "💰 Detected funded wallet: ${TOTAL_ADA} ADA"
        echo "🔹 Continuing..."
        echo
        break
    fi

    # Otherwise, wait/retry
    echo "⏳ No spendable UTxOs yet for this address."
    echo "💡 Wallet address is valid, but no on‑chain funds detected."
    echo "Send ADA to:"
    echo "  ${PAYMENT_ADDR}"
    echo
    echo "Press [Enter] to check again, wait ${RETRY_INTERVAL}s for auto‑retry,"
    echo "or press Ctrl+C to abort."
    read -t "${RETRY_INTERVAL}" -r || true
done
# --- Token info setup ---
POLICY_ID=$(<cardano_policy/keys/policy.id)
ASSET_NAME_HEX=$(<cardano_policy/asset_name_hex.txt)
ASSET_NAME=$(<cardano_policy/asset_name.txt)
ASSET="${POLICY_ID}.${ASSET_NAME_HEX}"
AMOUNT=1


# --- TX input selection loop (improved) ---
TX_IN=""
while true; do
    echo "🔎 Attempting to auto‑select a UTxO..."

    # Query UTxOs as JSON and auto‑pick the first entry
    UTXO_JSON=$(cardano-cli query utxo --address "${PAYMENT_ADDR}" ${NETWORK} --out-file /dev/stdout)
    TX_IN=$(echo "$UTXO_JSON" | jq -r 'keys[0]')
    echo
    echo "🔎 Current UTxOs for ${PAYMENT_ADDR}:"
    cardano-cli query utxo --address "${PAYMENT_ADDR}" ${NETWORK}
    echo

    if [[ -n "${TX_IN}" ]]; then
        echo "✅ Auto‑selected TX input: ${TX_IN}"
        read -rp "Press Enter to accept this TX_IN or type one manually (tx_hash#ix): " manual_in
    else
        echo "⚠️  Auto‑selection failed — no spendable UTxO detected."
        read -rp "Paste a TX_IN manually (tx_hash#ix) or press Enter to retry: " manual_in
    fi

    if [[ -n "${manual_in}" ]]; then
        TX_IN="${manual_in}"
    fi

    # If still empty, loop back and refresh
    if [[ -z "${TX_IN}" ]]; then
        echo "⚠️  No valid TX input chosen. Press Enter to refresh UTxOs (Ctrl+C to abort)."
        read -r
        UTXO_JSON=$(cardano-cli query utxo --address "${PAYMENT_ADDR}" ${NETWORK} 2>/dev/null || true)
        continue
    fi

    echo "✅ Using TX input: ${TX_IN}"
    read -rp "Confirm this input? [Y/n/r (retry)]: " confirm
    case "${confirm}" in
        [rR])  # Retry selection
            echo "🔁 Retrying UTxO selection..."
            UTXO_JSON=$(cardano-cli query utxo --address "${PAYMENT_ADDR}" ${NETWORK} 2>/dev/null || true)
            TOTAL_ADA=$(echo "$UTXO_JSON" | awk 'NR>2 && NF {sum+=$3} END {printf "%.6f", sum/1000000}')
            echo "💰 Current wallet balance: ${TOTAL_ADA} ADA"
            continue
            ;;
        [nN])  # Abort
            echo "❌ Cancelled by user."
            exit 1
            ;;
        *) break ;;  # Default accept and exit loop
    esac
done

# Show final balance before building
TOTAL_ADA=$(cardano-cli query utxo --address "${PAYMENT_ADDR}" ${NETWORK} | \
    awk 'NR>2 && NF {sum+=$3} END {printf "%.6f", sum/1000000}')
echo "💰 Final wallet balance: ${TOTAL_ADA} ADA"


# --- Source mint templates
source "$(dirname "$0")/mint_meta_generator.sh"


# Example variables (adjust to your environment)
POLICY_ID=$(<cardano_policy/keys/policy.id)
POLICY_DIR="./cardano_policy"

choose_metadata_template "$POLICY_ID" "$ASSET_NAME" "${POLICY_DIR}/metadata.json"

# --- Build transaction ---
# --- Parse registry.json and extract simple values --------------------
registry_json="./cardano_policy/registry.json"

# Defensive: make sure file exists
if [[ ! -f "$registry_json" ]]; then
    echo "❌  registry.json not found at $registry_json"
    exit 1
fi

echo "🔎 Parsing registry metadata from $registry_json"

NAME=$(jq -r '.name.value'        "$registry_json")
TICKER=$(jq -r '.ticker.value'    "$registry_json")
DESCRIPTION=$(jq -r '.description.value' "$registry_json")
DECIMALS=$(jq -r '.decimals.value' "$registry_json")
URL=$(jq -r '.url.value'          "$registry_json")
LOGO=$(jq -r '.logo.value'        "$registry_json")

# Check for empties so we fail early
for var in NAME TICKER DESCRIPTION DECIMALS URL LOGO; do
    if [[ -z "${!var}" || "${!var}" == "null" ]]; then
        echo "⚠️  $var is empty or missing in registry.json"
    fi
done

echo "🔎 Parsed metadata variables:"
echo "  NAME:        ${NAME}"
echo "  TICKER:      ${TICKER}"
echo "  DESCRIPTION: ${DESCRIPTION}"
echo "  URL:         ${URL}"
echo "  DECIMALS:    ${DECIMALS}"
echo "  LOGO length: $(echo -n "${LOGO}" | wc -c)"


echo "NETWORK=${NETWORK}"
echo "TX_IN=${TX_IN}"
echo "PAYMENT_ADDR=${PAYMENT_ADDR}"
echo "AMOUNT=${AMOUNT}"
echo "ASSET=${ASSET}"
echo "POLICY_DIR=${POLICY_DIR}"
echo "TX_DIR=${TX_DIR}"

# --- Path to where final metadata.json will be written ----------------
metadata_json="./cardano_policy/metadata.json"

echo "🔎 Final metadata.json:"
cat "${POLICY_DIR}/metadata.json"

# Build the raw transaction
if ! cardano-cli conway transaction build \
  ${NETWORK} \
  --tx-in "${TX_IN}" \
  --tx-out "${PAYMENT_ADDR}+2000000+${AMOUNT} ${ASSET}" \
  --change-address "${PAYMENT_ADDR}" \
  --mint="${AMOUNT} ${ASSET}" \
  --minting-script-file "${POLICY_DIR}/scripts/policy.script" \
  --metadata-json-file "${metadata_json}" \
  --out-file "${TX_DIR}/mint.raw" 2> "${TX_DIR}/build.log"
then
  echo "❌ build failed – check ${TX_DIR}/build.log for details"
  exit 1
fi

echo "✅ Unsigned transaction written to ${TX_DIR}/mint.raw"
echo "Copy it to your air‑gapped machine for signing."

# (1) Ensure wallet exists / funded
# (2) Query + let user pick TX_IN
# (3) Define POLICY_ID, ASSET_NAME, etc.
# (4) Build mint.raw (just completed)
# (5) THEN save info for offline use:

echo "💾 Saving TX input info for offline signing..."
TX_INFO_FILE="${TX_DIR}/tx_input_info.txt"

{
  echo "TX_IN=${TX_IN}"
  echo "PAYMENT_ADDR=${PAYMENT_ADDR}"
  echo "POLICY_ID=${POLICY_ID}"
  echo "ASSET_NAME=${ASSET_NAME}"
  echo "ASSET=${ASSET}"
  echo "AMOUNT=${AMOUNT}"
  echo "DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
} > "${TX_INFO_FILE}"

echo "✅ Saved public TX info to ${TX_INFO_FILE}"
echo "   Copy this file, together with ${TX_DIR}/mint.raw, to your air‑gapped machine."

# (Optional) If you intend to sign and submit automatically (not air‑gapped)
# add the following only when applicable
sign_and_submit_tx \
  ./txs/mint.draft \
  ./txs/mint.signed \
  ./cardano_policy/policy.skey \
  ./wallet/payment.skey