#!/usr/bin/env bash
# mint_airgap.sh – sign and (optionally) submit mint transaction

set -euo pipefail
source ./run/ada_env.sh

TX_DIR="./tx"
#NETWORK="--mainnet"
NETWORK="--testnet-magic 1"
echo "✍️  Signing transaction..."
cardano-cli transaction sign \
  --tx-body-file "${TX_DIR}/mint.raw" \
  --signing-key-file cardano_policy/keys/payment.skey \
  --signing-key-file cardano_policy/keys/policy.skey \
  ${NETWORK} \
  --out-file "${TX_DIR}/mint.signed"

echo "✅ Signed transaction ready: ${TX_DIR}/mint.signed"
echo "Copy it back to the online machine to submit (if you prefer)."

# Optional: if you trust this machine to broadcast
# cardano-cli transaction submit --tx-file "${TX_DIR}/mint.signed" ${NETWORK}