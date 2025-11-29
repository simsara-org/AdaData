#!/usr/bin/env bash
# mint_airgap.sh – sign (and optionally submit) mint transaction on air‑gapped machine

set -euo pipefail
cd "$(dirname "$0")" || exit 1

TX_DIR="./tx"
# Adjust the network flag as needed
# NETWORK="--mainnet"
NETWORK="--testnet-magic 1"

echo "✍️  Signing mint transaction ..."
cardano-cli transaction sign \
  --tx-body-file "${TX_DIR}/mint.raw" \
  --signing-key-file ./cardano_policy/keys/payment.skey \
  --signing-key-file ./cardano_policy/keys/policy.skey \
  ${NETWORK} \
  --out-file "${TX_DIR}/mint.signed"

echo "✅  Signed transaction ready: ${TX_DIR}/mint.signed"
echo "   Copy that file back to the online environment and run:"
echo "   cardano-cli transaction submit --tx-file ${TX_DIR}/mint.signed ${NETWORK}"

# If this air‑gapped machine actually has network access (rare), you could uncomment:
# cardano-cli transaction submit --tx-file "${TX_DIR}/mint.signed" ${NETWORK}