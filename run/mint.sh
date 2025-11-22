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

# Continue with transaction build steps here
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

# Sign it
cardano-cli transaction sign \
  --tx-body-file "${TX_DIR}/mint.raw" \
  --signing-key-file "${KEYS_DIR}/payment.skey" \
  --signing-key-file "${KEYS_DIR}/policy.skey" \
  ${NETWORK} \
  --out-file "${TX_DIR}/mint.signed"

TXID=$(cardano-cli transaction txid --tx-file "${TX_DIR}/mint.signed")

echo
echo "✅ Transaction built & signed!"
echo "TXID: ${TXID}"
echo
echo "To submit the transaction, run:"
echo "  cardano-cli transaction submit --tx-file ${TX_DIR}/mint.signed ${NETWORK}"
echo

exit 0
