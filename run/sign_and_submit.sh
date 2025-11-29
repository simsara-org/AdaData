# --------------------------------------------------------------
# sign_and_submit_tx.sh
# --------------------------------------------------------------
sign_and_submit_tx() {
  local tx_draft="$1"
  local tx_signed="$2"
  local policy_skey="$3"
  local payment_skey="$4"

  # Determine network flag
  local NET_ARGS=()

  # Use environment variable if already set
  if [ -n "${NETWORK:-}" ]; then
    echo "🌐 Using network from \$NETWORK: $NETWORK"
    read -r -a NET_ARGS <<< "$NETWORK"
  else
    echo "🌐 Select network to use:"
    echo "  1) Testnet"
    echo "  2) Mainnet"
    read -r -p "Enter choice [1-2]: " net_choice
    case "$net_choice" in
      1)
        read -r -p "Enter Testnet magic number [default 1097911063]: " TESTNET_MAGIC
        TESTNET_MAGIC=${TESTNET_MAGIC:-1097911063}
        NET_ARGS=(--testnet-magic "$TESTNET_MAGIC")
        ;;
      2)
        NET_ARGS=(--mainnet)
        ;;
      *)
        echo "❌ Invalid selection."
        return 1
        ;;
    esac
  fi

  #
  # 3️⃣ Signing step (with safety prompt)
  #
  echo "⚠️  The next step will SIGN a transaction using your keys."
  read -r -p "Do you want to sign this transaction now? (y/N): " resp
  [[ ! "$resp" =~ ^[Yy]$ ]] && { echo "❌ Aborted before signing."; return 1; }

  cardano-cli transaction sign \
    --tx-body-file "$tx_draft" \
    --signing-key-file "$policy_skey" \
    --signing-key-file "$payment_skey" \
    "${NET_ARGS[@]}" \
    --out-file "$tx_signed"

  echo "✅ Transaction signed -> $tx_signed"

  #
  # 4️⃣ Final confirmation and submission
  #
  echo "⚠️  The next step will SUBMIT the signed transaction to the network."
  read -r -p "Do you want to submit now? (y/N): " resp
  [[ ! "$resp" =~ ^[Yy]$ ]] && { echo "❌ Aborted before submission."; return 1; }

  echo "⚠️  Once submitted, it cannot be undone."
  read -r -p "Type exactly 'sign and submit' to continue: " confirm
  [[ "$confirm" != "sign and submit" ]] && { echo "❌ Confirmation phrase did not match. Aborted."; return 1; }

  cardano-cli transaction submit \
    --tx-file "$tx_signed" \
    "${NET_ARGS[@]}"

  echo "✅ Transaction submitted to the network."
}