#!/usr/bin/env bash
# pre_int.sh – gather inputs for minting

source ./ada_env.sh

NETWORK=$(choose_network)

require_file "${KEYS_DIR}/policy.skey"
require_file "${KEYS_DIR}/policy.vkey"
require_file "${SCRIPTS_DIR}/policy.script"

read -rp "Enter asset name (default from file if blank): " ASSET_NAME
[[ -z "$ASSET_NAME" && -f "${POLICY_DIR}/asset_name.txt" ]] && ASSET_NAME=$(<"${POLICY_DIR}/asset_name.txt")

read -rp "Enter token amount (default 1): " AMOUNT
AMOUNT=${AMOUNT:-1}

ASSET_NAME_HEX=$(<"${POLICY_DIR}/asset_name_hex.txt")
POLICY_ID=$(<"${KEYS_DIR}/policy.id")
PAYMENT_ADDR=$(<"${KEYS_DIR}/payment.addr")
ASSET="${POLICY_ID}.${ASSET_NAME_HEX}"

echo "Minting ${AMOUNT} of ${ASSET} on ${NETWORK}"
confirm "Proceed?" || exit 0

echo "$NETWORK" > "${TX_DIR}/network.txt"
echo "$ASSET" > "${TX_DIR}/asset.txt"
echo "$AMOUNT" > "${TX_DIR}/amount.txt"