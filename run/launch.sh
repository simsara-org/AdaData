#!/usr/bin/env bash
#
# AdaData – Air‑Gapped Cardano Token Metadata Toolkit
# ---------------------------------------------------
# Author : Patrick Peluse / Simsara
# Website: https://simsara.com
#
# If this tool saves you time or earns you money, consider supporting:
# ADA: addr1q9v8ymz760w2a8ja9g0znchgxf42uj27p8cvx6p2jq9dgt672djtjn96uawdpaq2xn54vr6rkd24ej7rcxz29cly55mqm0vjlp
#
# launch.sh
#
# Purpose : Launcher to generate, mint, burn, or validate token data.
# ===============================================================

set -euo pipefail
trap 'echo; echo "👋  Exiting gracefully."; exit 0' INT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="1.0.0"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Usage: $(basename "$0")"
  echo "Interactive launcher for the AdaData air‑gapped Cardano toolkit."
  exit 0
fi

if [ "$EUID" -eq 0 ]; then
  echo "⚠️  Running as root."
  echo "It's safer to use a regular user. Press Enter to continue or Ctrl+C to cancel."
  read -r
fi

run_script() {
  local script_name="$1"
  if [[ -f "$SCRIPT_DIR/$script_name" ]]; then
    chmod +x "$SCRIPT_DIR/$script_name"
    "${SCRIPT_DIR}/${script_name}" || {
      echo "❌  ${script_name} failed; returning to menu."
      return 1
    }
  else
    echo "⚠️  Script not found: $script_name"
    echo "    Skipping because it appears you don’t have this component."
  fi
}

while true; do
  clear
  echo "=========================="
  echo "🚀 Adadata Token Utility  v${VERSION}"
  echo "=========================="
  echo
  echo "Choose an action:"
  echo "  1) Generate keys/policy/metadata"
  echo "  2) Mint existing token"
  echo "  3) Burn token"
  echo "  4) Validate keys/policy"
  echo "  5) Validate mint data/metadata"
  echo "  6) Setup node connection (for mint/burn/wallet)"
  echo "  7) Quit"
  echo

  read -rp "Enter choice [1‑7]: " choice
  echo

  case "$choice" in
    1) echo "⚙️  Generating keys/policy/metadata..."; run_script "generate.sh" ;;
    2)
      echo "💫  Minting token..."
      echo
      echo "Select minting mode:"
      echo "  1) Full mint workflow (mint.sh)"
      echo "  2) Online build only (mint_online.sh)"
      echo "  3) Air‑gapped sign only (mint_airgap.sh)"
      echo "  4) Back to main menu"
      echo
      read -rp "Enter choice [1‑4]: " mint_mode
      echo

      case "$mint_mode" in
        1) run_script "mint.sh" ;;
        2) run_script "mint_online.sh" ;;
        3) run_script "mint_airgap.sh" ;;
        4) echo "Returning to main menu..." ;;
        *) echo "❌  Invalid choice." ;;
      esac
      ;;
    3) echo "🔥  Burning token...";                  run_script "burn.sh" ;;
    4) echo "🔍  Validating keys/policy...";          run_script "validate_keys.sh" ;;
    5) echo "🧪  Validating mint data/metadata...";   run_script "validate_mint.sh" ;;
    6) echo "🔗  Setting up node connection...";      run_script "setup_node.sh" ;;
    7)
      read -rp "Are you sure you want to quit? [y/N] " ans
      [[ "${ans,,}" == "y" ]] && { echo "👋  Exiting. Goodbye!"; exit 0; }
      ;;
    *) echo "❌  Invalid choice." ;;
  esac

  echo
  echo "✅ Done."
  echo
  read -rp "Press Enter to return to menu or Ctrl+C to quit..."
done