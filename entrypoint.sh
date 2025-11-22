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
# entrypoint.sh
#
# Purpose : Docker entry file
# Security:
#   Keep all output files offline; never commit keys to a repository.
# ===========================================================================

set -e  # fail on first error

# Resolve the directory where this script itself lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET_SCRIPT="$SCRIPT_DIR/run/launch.sh"

echo "🚀  Running entrypoint: $TARGET_SCRIPT"

# Confirm that the target script exists and is executable
if [[ ! -x "$TARGET_SCRIPT" ]]; then
    echo "❌  Missing or non‑executable target: $TARGET_SCRIPT" >&2
    echo "Make sure run/generate.sh exists and has +x permission." >&2
    exit 1
fi

# Forward all arguments downstream
"$TARGET_SCRIPT" "$@"

echo "✅  Entrypoint complete."
