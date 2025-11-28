#!/usr/bin/env bash
set -euo pipefail

echo
echo "🔗 Node connection setup"

NODE_ENV_FILE="cardano_policy/node_env.sh"

if [[ -f "$NODE_ENV_FILE" ]]; then
  source "$NODE_ENV_FILE"
  echo "✅ Loaded existing node socket path: $CARDANO_NODE_SOCKET_PATH"
else
  for guess in \
    "$HOME/cardano-node/db/node.socket" \
    "/media/${USER:-unknown}"/*/db/node.socket \
    "/var/lib/cardano-node/db/node.socket"
  do
    if [[ -S "$guess" ]]; then
      CARDANO_NODE_SOCKET_PATH="$guess"
      echo "✅ Found node socket automatically at: $CARDANO_NODE_SOCKET_PATH"
      break
    fi
  done

  if [[ -z "${CARDANO_NODE_SOCKET_PATH:-}" ]]; then
    echo "💡 Example full path: /media/user/cardano/db/node.socket"
    read -rp "⚙️  Enter the full path to your node.socket file: " NODE_SOCKET_INPUT
    CARDANO_NODE_SOCKET_PATH="${NODE_SOCKET_INPUT/#\~/$HOME}"

    if [[ ! -S "$CARDANO_NODE_SOCKET_PATH" ]]; then
      echo "❌ No node.socket found at: $CARDANO_NODE_SOCKET_PATH"
      echo "Please check the path and try again."
      exit 1
    fi
  fi

  mkdir -p "$(dirname "$NODE_ENV_FILE")"
  echo "export CARDANO_NODE_SOCKET_PATH=\"$CARDANO_NODE_SOCKET_PATH\"" > "$NODE_ENV_FILE"
  echo "✅ Node socket path saved to $NODE_ENV_FILE"
  echo "To use it later, run:  source $NODE_ENV_FILE"
fi

echo
echo "✅ Node setup complete."
echo
echo "✅ Done."
read -rp $'\nPress Enter to return to menu or Ctrl+C to quit...'