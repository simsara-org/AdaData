#!/usr/bin/env bash
#
# AdaData – Air‑Gapped Cardano Token Metadata Toolkit
# ---------------------------------------------------
# validate_mint.sh
# Validate mint metadata JSON before submission to the registry.
# Inputs  : [--help] [metadata.json]
# Output  : Exit code 0 on success, non‑zero on failure.
#===========================================================================

set -euo pipefail

# --- Option parsing --------------------------------------------------------
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<EOF

Usage:
  $(basename "$0") [metadata.json]

Description:
  Validates a Cardano mint metadata file using the
  metadata-validator-github CLI tool.

Arguments:
  metadata.json   Optional path to the mint metadata JSON file.
                  Default: ./cardano_policy/metadata.json

Examples:
  $(basename "$0")
  $(basename "$0") ./path/to/your-metadata.json

EOF
    exit 0
fi

# --- Main ------------------------------------------------------------------
MINT_FILE=${1:-"./cardano_policy/metadata.json"}

echo
echo "🔍 Validating mint metadata: $MINT_FILE"
metadata-validator-github mint validate "$MINT_FILE" || {
  echo "❌ Mint metadata failed validation" >&2
  exit 1
}

echo
# Print deterministic fingerprint of exactly what was checked
if command -v sha256sum >/dev/null 2>&1; then
    HASH=$(sha256sum "$MINT_FILE" | cut -d' ' -f1)
    echo "✅ Mint metadata passed validation!"
    echo "   SHA‑256: $HASH"
elif command -v shasum >/dev/null 2>&1; then
    HASH=$(shasum -a 256 "$MINT_FILE" | cut -d' ' -f1)
    echo "✅ Mint metadata passed validation!"
    echo "   SHA‑256: $HASH"
else
    echo "✅ Mint metadata passed validation (hash utility not found)"
fi
