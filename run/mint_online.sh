#!/usr/bin/env bash
set -euo pipefail
source ./run/ada_env.sh

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
ASSET="${POLICY_ID}.${ASSET_NAME_HEX}"
AMOUNT=1

# --- TX input selection loop (improved) ---
TX_IN=""
while true; do
    echo "🔎 Attempting to auto‑select a UTxO..."
    TX_IN=$(echo "$UTXO_JSON" | awk '/TxHash/ {getline; if ($1 != "") {print $1"#"$2; exit}}')

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


# --- Build transaction ---
cardano-cli transaction build \
  --babbage-era \
  ${NETWORK} \
  --tx-in "${TX_IN}" \
  --tx-out "${PAYMENT_ADDR}+2000000+${AMOUNT} ${ASSET}" \
  --change-address "${PAYMENT_ADDR}" \
  --mint="${AMOUNT} ${ASSET}" \
  --minting-script-file cardano_policy/scripts/policy.script \
  --metadata-json-file cardano_policy/metadata.json \
  --out-file "${TX_DIR}/mint.raw"

echo "✅ Unsigned transaction written to ${TX_DIR}/mint.raw"
echo "Copy it to your air‑gapped machine for signing."