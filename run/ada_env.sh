#!/usr/bin/env bash
# ada_env.sh – common environment for AdaData scripts

set -euo pipefail

# Default directories
POLICY_DIR="./cardano_policy"
KEYS_DIR="${POLICY_DIR}/keys"
SCRIPTS_DIR="${POLICY_DIR}/scripts"
TX_DIR="./tx"

mkdir -p "$TX_DIR"

# Helper: prompt yes/no
confirm() {
  read -rp "$1 (y/N): " ans
  [[ "${ans,,}" == "y" ]]
}

# Helper: ensure required files exist
require_file() {
  local f="$1"
  [[ -f "$f" ]] || { echo "❌ Missing file: $f"; exit 1; }
}

# Helper: choose network interactively
choose_network() {
  echo "Select network:"
  echo "1) mainnet"
  echo "2) testnet"
  read -rp "Enter choice [1-2]: " net_choice
  case $net_choice in
    1) echo "--mainnet" ;;
    2)
      read -rp "Enter testnet magic (default 2): " magic
      echo "--testnet-magic ${magic:-2}"
      ;;
    *) echo "Invalid choice" >&2; exit 1 ;;
  esac
}