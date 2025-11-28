#!/usr/bin/env bash
#
# AdaData – Air‑Gapped Cardano Token Metadata Toolkit
# ---------------------------------------------------
# A helper script for creating and managing Cardano native assets and metadata.
#
# Author : Patrick Peluse / Simsara
# Website: https://simsara.com
# Repo   : https://github.com/youruser/yourrepo
#
# If this tool saves you time or earns you money, consider supporting:
# ADA: addr1q9v8ymz760w2a8ja9g0znchgxf42uj27p8cvx6p2jq9dgt672djtjn96uawdpaq2xn54vr6rkd24ej7rcxz29cly55mqm0vjlp
#
# Disclaimer: This is unofficial community software. Use at your own risk.
# ===========================================================================
# mint.sh
#
# Purpose :
#   Mint new Cardano native tokens (or burn existing ones) using an existing
#   minting policy and associated metadata.
#
# Inputs  :
#   --name <string>         Optional descriptive policy name (default: policy)
#   --policy-dir <path>     Directory containing policy and key files (default: ./policy)
#   --key-dir <path>        Directory containing payment keys and address (default: ./keys)
#   --metadata <path>       Path to metadata JSON file (required)
#   --asset-name <string>   Asset name to mint (required)
#   --amount <integer>      Quantity of tokens to mint (required, can be negative for burn)
#   --tx-in <hash#ix>       Transaction input covering mint fee and collateral (required)
#   --tx-out <address+amount>
#                           Output address and amount, including minted asset (required)
#   --network <type>        "mainnet" or "testnet-magic <num>" (required)
#   --out-dir <path>        Directory for transaction files (default: ./tx)
#   --force                 Overwrite existing unsigned/signed transaction files if present
#
# Outputs :
#   <out-dir>/mint.raw      Unsigned mint transaction body
#   <out-dir>/mint.signed   Fully signed transaction ready for submission
#   TXID                    Transaction ID printed to stdout (for tracking/submission)
#
# Security:
#   Run this script offline where possible.
#   Keep all key, policy, and metadata files private.
#   Never publish or commit signing keys, policy scripts, or raw transactions.
#
# ===========================================================================

set -euo pipefail

NODE_ENV_FILE="cardano_policy/node_env.sh"
[ -f "$NODE_ENV_FILE" ] && source "$NODE_ENV_FILE"

# Initialize
SOCKET_PATH=""

# Parse --socket-path (CLI override) -- modify for your argument parsing logic!
while [[ $# -gt 0 ]]; do
  case "$1" in
    --socket-path|--connect)
      SOCKET_PATH="$2"
      shift 2
      ;;
    *)
      break
      ;;
  esac
done


echo "Using configuration:"
echo "  Network: ${NETWORK}"
echo "  Output directory: ${TX_DIR}"
[[ -n "$SOCKET_PATH" ]] && echo "  Socket path: ${SOCKET_PATH}"
echo

# Fallback to env var
if [[ -z "$SOCKET_PATH" && -n "${CARDANO_NODE_SOCKET_PATH:-}" ]]; then
  SOCKET_PATH="$CARDANO_NODE_SOCKET_PATH"
fi

# Fallback to defaults
DEFAULT_PATHS=(
  "./db/node.socket"
  "$HOME/.cardano-node/db/node.socket"
)
if [[ -z "$SOCKET_PATH" ]]; then
  for p in "${DEFAULT_PATHS[@]}"; do
    if [[ -S "$p" ]]; then
      SOCKET_PATH="$p"
      break
    fi
  done
fi

# Final check and export
if [[ -z "$SOCKET_PATH" || ! -S "$SOCKET_PATH" ]]; then
  echo "❌ Could not locate a node socket."
  echo "   Tried: ${DEFAULT_PATHS[*]}"
  echo "   You can specify one with --socket-path <path> or set CARDANO_NODE_SOCKET_PATH."
  exit 1
fi

# Export for cardano-cli
export CARDANO_NODE_SOCKET_PATH="$SOCKET_PATH"
echo "✅ Using node socket: $SOCKET_PATH"
echo


# ---------------------------------------------------------------------------

set -euo pipefail

echo "===================================="
echo "🚀 Cardano Token Minting Script"
echo "===================================="
echo

# Ask for network
echo "Select network:"
echo "1) mainnet"
echo "2) testnet"
read -rp "Enter choice [1-2]: " net_choice

case $net_choice in
  1)
    NETWORK="--mainnet"
    ;;
  2)
    read -rp "Enter testnet magic (default 2): " magic
    magic=${magic:-2}
    NETWORK="--testnet-magic ${magic}"
    ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac

# Check if keys exist
POLICY_DIR="./cardano_policy"
KEYS_DIR="${POLICY_DIR}/keys"
SCRIPTS_DIR="${POLICY_DIR}/scripts"
TX_DIR="./tx"

if [[ ! -d "$KEYS_DIR" ]]; then
  echo "❌ Keys directory not found at ${KEYS_DIR}"
  echo "Please run ./generate.sh to create the policy before minting."
  exit 1
fi

if [[ ! -f "${KEYS_DIR}/policy.skey" || ! -f "${KEYS_DIR}/policy.vkey" ]]; then
  echo "❌ Missing policy keys. Please run generate.sh first."
  exit 1
fi

if [[ ! -f "${SCRIPTS_DIR}/policy.script" ]]; then
  echo "❌ Missing policy.script in ${SCRIPTS_DIR}"
  exit 1
fi

: "${TX_DIR:="./tx"}"
mkdir -p "$TX_DIR"

# Ask how many tokens and what name
read -rp "Enter asset name (default from file if blank): " ASSET_NAME
if [[ -z "$ASSET_NAME" && -f "${POLICY_DIR}/asset_name.txt" ]]; then
  ASSET_NAME=$(cat "${POLICY_DIR}/asset_name.txt")
fi

read -rp "Enter token amount (default 1): " AMOUNT
AMOUNT=${AMOUNT:-1}

ASSET_NAME_HEX=$(cat "${POLICY_DIR}/asset_name_hex.txt")
POLICY_ID=$(cat "${KEYS_DIR}/policy.id")
PAYMENT_ADDR=$(cat "${KEYS_DIR}/payment.addr")
ASSET="${POLICY_ID}.${ASSET_NAME_HEX}"

echo
echo "Minting information:"
echo "  Network:    ${NETWORK}"
echo "  Policy ID:  ${POLICY_ID}"
echo "  Asset:      ${ASSET}"
echo "  Amount:     ${AMOUNT}"
echo "  Address:    ${PAYMENT_ADDR}"
echo


# --------------------------------------------------------------------------
# Determine what stage we are in
RAW_FILE="${TX_DIR}/mint.raw"
SIGNED_FILE="${TX_DIR}/mint.signed"

if [[ -f "$SIGNED_FILE" ]]; then
  echo "✅ Found existing signed transaction: $SIGNED_FILE"
  echo "Submitting to network..."
  cardano-cli transaction submit --tx-file "$SIGNED_FILE" ${NETWORK}
  echo "✅ Submitted successfully."
  exit 0
elif [[ -f "$RAW_FILE" ]]; then
  echo "✅ Found existing unsigned transaction: $RAW_FILE"
  echo "Signing..."
  cardano-cli transaction sign \
    --tx-body-file "$RAW_FILE" \
    --signing-key-file "${KEYS_DIR}/payment.skey" \
    --signing-key-file "${KEYS_DIR}/policy.skey" \
    ${NETWORK} \
    --out-file "$SIGNED_FILE"
  echo "✅ Signed. You can now submit this file online."
  exit 0
fi


# --- soft pre‑mint checks --------------------------------------------------

# 1. Verify that the payment address file exists
if [ ! -f "${KEYS_DIR}/payment.addr" ]; then
  echo ""
  echo "⚠️  No wallet address file found at: ${KEYS_DIR}/payment.addr"
  echo "   Please generate keys/policy first (menu option 1)."
  echo ""
  exit 1
fi

# 2. Check that the wallet has some ADA
TMP_UTXO=/tmp/utxo.json

check_balance() {
  cardano-cli query utxo \
    --address "${PAYMENT_ADDR}" \
    ${NETWORK} \
    --out-file "$TMP_UTXO" 2>/dev/null

  if [ ! -s "$TMP_UTXO" ] || [ "$(jq length "$TMP_UTXO")" -eq 0 ]; then
    return 1
  fi

  TOTAL_LOVELACE=$(jq '[.[].value.lovelace] | add' "$TMP_UTXO")
  if [ -z "$TOTAL_LOVELACE" ] || [ "$TOTAL_LOVELACE" -lt 2000000 ]; then
    return 1
  fi
  return 0
}

echo ""
echo "🔍 Checking wallet balance..."
if ! check_balance; then
  echo ""
  echo "⚠️  This wallet (${PAYMENT_ADDR}) currently has no ADA or less than 2 ADA."
  echo "   Please send at least 2 ADA from your signing wallet"
  echo "   to cover fees and minimum UTxO requirements."
  echo ""
  echo "   Send funds to this address:"
  echo "     ${PAYMENT_ADDR}"
  echo ""
  echo "   Keep this window open. Once the transaction confirms, press ENTER."
  echo ""

  while true; do
    read -rp "Press ENTER to recheck balance, or type 'exit' to cancel: " ans
    [[ "${ans,,}" == "exit" ]] && echo "Exiting to main menu." && exit 0

    echo "🔄 Rechecking balance..."
    if check_balance; then
      echo "✅ Wallet funded with sufficient ADA!"
      break
    else
      echo "❌ Still no funds detected. Wait a bit longer and try again."
    fi
  done
else
  echo "✅ Wallet already funded."
fi

# --------------------------------------------------------------------------

# Confirm with user before continuing
read -rp "Proceed with minting? (y/N): " confirm
if [[ "${confirm,,}" != "y" ]]; then
  echo "Aborted."
  exit 0
fi

echo
echo "🔎 Checking available UTxOs..."
UTXO_JSON=$(cardano-cli query utxo --address "${PAYMENT_ADDR}" ${NETWORK})

# If the result is empty '{}', bail out nicely
if [[ "${UTXO_JSON}" == "{}" || -z "${UTXO_JSON// }" ]]; then
  echo
  echo "⚠️  No UTxOs found for address:"
  echo "    ${PAYMENT_ADDR}"
  echo
  echo "This usually means the wallet has not been funded yet."
  echo "➡️  Please send some ADA to this address, wait for confirmation,"
  echo "    then rerun the script. The address will receive a TxHash once funded."
  echo
  exit 1
fi

# Otherwise, show the UTxOs so the user can pick one
echo
echo "Available UTxOs:"
echo "${UTXO_JSON}"
echo
read -rp "Enter TX input in form <tx_hash#ix>: " TX_IN


if [[ -f "$RAW_FILE" ]]; then
  if [[ "${FORCE:-false}" == "true" ]]; then
    echo "⚠️  Overwriting existing unsigned transaction (forced)."
  else
    echo "⚠️  Unsigned transaction already exists. Use --force to overwrite."
    exit 1
  fi
fi

# Build the transaction
cardano-cli transaction build \
  --babbage-era \
  ${NETWORK} \
  --tx-in "${TX_IN}" \
  --tx-out "${PAYMENT_ADDR}+2000000+${AMOUNT} ${ASSET}" \
  --change-address "${PAYMENT_ADDR}" \
  --mint="${AMOUNT} ${ASSET}" \
  --minting-script-file "${SCRIPTS_DIR}/policy.script" \
  --metadata-json-file "${POLICY_DIR}/metadata.json" \
  --out-file "${TX_DIR}/mint.raw"

# Prevent accidental overwrite of a signed file
if [[ -f "$SIGNED_FILE" && "${FORCE:-false}" != "true" ]]; then
  echo "⚠️  Signed transaction already exists. Use --force to overwrite."
  exit 1
fi


# Sign it
cardano-cli transaction sign \
  --tx-body-file "${TX_DIR}/mint.raw" \
  --signing-key-file "${KEYS_DIR}/payment.skey" \
  --signing-key-file "${KEYS_DIR}/policy.skey" \
  ${NETWORK} \
  --out-file "${TX_DIR}/mint.signed"

TXID=$(cardano-cli transaction txid --tx-file "${TX_DIR}/mint.signed")

echo "Mint transaction prepared successfully!"
echo "  File: ${TX_DIR}/mint.signed"
echo "  TXID: ${TXID}"
echo
echo "Submit it online with:"
echo "  cardano-cli transaction submit --tx-file ${TX_DIR}/mint.signed ${NETWORK}"


exit 0
