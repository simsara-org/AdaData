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
# generate.sh
#
# Purpose : Generate a new minting policy and key pair for Cardano token minting
#
# Inputs  :
#   --name <string>       Optional descriptive policy name
#   --key-dir <path>      Output directory for key files (default: ./keys)
#   --policy-dir <path>   Output directory for policy files (default: ./policy)
#   --expires <slot>      Optional expiry slot for time-locked policies
#   --force               Overwrite existing files if present
#
# Outputs :
#   <key-dir>/<policy_name>.skey
#   <key-dir>/<policy_name>.vkey
#   <policy-dir>/<policy_name>.script
# Security:
#   Keep all output files offline; never commit keys to a repository.
#
# ===========================================================================


set -e  # Exit on error


# CONFIGURATION
NETWORK_DEFAULT="--testnet-magic 1097911063"  # Preview by default
NETWORK="$NETWORK_DEFAULT"


choose_network() {
    echo "Select network environment:"
    echo "1) Mainnet"
    echo "2) Preview Testnet"
    echo "3) Preprod Testnet"
    read -p "Enter choice [1-3]: " NET_OPTION

    case "$NET_OPTION" in
        1)
            NETWORK="--mainnet"
            ;;
        2)
            NETWORK="--testnet-magic 1097911063"  # Preview network
            ;;
        3)
            NETWORK="--testnet-magic 1"           # Preprod network
            ;;
        *)
            echo "Invalid choice; defaulting to Preview Testnet."
            NETWORK="--testnet-magic 1097911063"
            ;;
    esac

    export NETWORK
    echo "Using network: $NETWORK"
}

# DIRECTORY SETUP
mkdir -p cardano_policy/{keys,scripts}
cd cardano_policy

# Always overwrite (with an optional safety check)
echo "⚠️  This will overwrite any existing policy keys or scripts in $(pwd)"
sleep 1  # short pause so users can Ctrl+C if needed
rm -f keys/policy.vkey keys/policy.skey scripts/policy.script keys/policy.id

# Optionally remove any leftovers from previous runs
# rm -f keys/* scripts/*

# GENERATE POLICY KEYS
generate_policy_keys() {
    echo "Generating Policy Keys..."
    cardano-cli address key-gen \
        --verification-key-file keys/policy.vkey \
        --signing-key-file keys/policy.skey
}

# CREATE POLICY SCRIPT
create_policy_script() {
    echo "Creating Policy Script..."
    KEY_HASH=$(cardano-cli address key-hash --payment-verification-key-file keys/policy.vkey)

    cat > scripts/policy.script << EOF
{
    "type": "sig",
    "keyHash": "$KEY_HASH"
}
EOF

    echo "Policy script created at scripts/policy.script"
}

# GENERATE POLICY ID: from policy script, not just key hash
generate_policy_id() {
    echo "Generating Policy ID (from script, best practice)..."

    # Try new/standard way first
    if cardano-cli transaction policyid --script-file scripts/policy.script > keys/policy.id 2>/dev/null; then
        :
    elif cardano-cli conway transaction policyid --script-file scripts/policy.script > keys/policy.id 2>/dev/null; then
        :
    elif cardano-cli shelley transaction policyid --script-file scripts/policy.script > keys/policy.id 2>/dev/null; then
        :
    else
        echo "ERROR: Could not derive policy id using any known cardano-cli command!"
        exit 1
    fi

    # ✅ Remove any trailing newline so file is exactly 56 chars
    printf %s "$(tr -d '\n' < keys/policy.id)" > keys/policy.id

    echo "Policy ID: $(cat keys/policy.id)"
}

# Prompt for asset name & compute hex and full asset id
prompt_asset_name() {
    echo -n "Enter your asset name (ASCII, e.g., SSARA): "
    read ASSET_NAME
    ASSET_NAME=$(echo "$ASSET_NAME" | tr -d '[:space:]')
    ASSET_NAME_HEX=$(echo -n "$ASSET_NAME" | xxd -p | tr -d '\n')
    POLICY_ID=$(cat keys/policy.id)
    ASSET_ID="${POLICY_ID}${ASSET_NAME_HEX}"   # <-- no dot

    # write without trailing newline
    echo -n "$ASSET_NAME"     > asset_name.txt
    echo -n "$ASSET_NAME_HEX" > asset_name_hex.txt
    echo -n "$ASSET_ID"       > asset_id.txt
}

# Prompt for metadata (display name, description, url, logo)
prompt_metadata() {
    # Display Name
    echo -n "Enter display name (human readable, e.g., CardanoToken): "
    read -r DISPLAY_NAME
    echo "$DISPLAY_NAME" > display_name.txt

    # Description
    echo -n "Enter description (short summary about this token/asset): "
    read -r DESCRIPTION
    echo "$DESCRIPTION" > description.txt

    # URL
    echo -n "Enter URL (must start with https://, e.g., https://simsara.com): "
    read -r URL
    echo "$URL" > url.txt

    DEFAULT_LOGO="$(dirname "$0")/../default_logo.png"  # bundle a small placeholder image
    LOGO_BASE64_OUT="logo_base64.txt"

    # helper: encode to base64 without line wraps
    encode_base64_nowrap() {
        # detect GNU (supports -w flag) or BSD base64
        if base64 --help 2>&1 | grep -q -- '-w'; then
            base64 -w 0 "$1" > "$LOGO_BASE64_OUT"
        else
            base64 < "$1" | tr -d '\n' > "$LOGO_BASE64_OUT"
        fi
    }

    # Small note for clarity
    if [ -f "$DEFAULT_LOGO" ]; then
        echo ""
        echo "A default placeholder logo is bundled at: $DEFAULT_LOGO"
        echo "Replace it with your own .png inside the container or set LOGO_PATH to use a custom one."
        echo ""
    fi

    while true; do
        echo -n "Would you like to add a logo? (Y/N, Enter = use default): "
        read -r LOGO_CHOICE
        case "$(echo "${LOGO_CHOICE:-Y}" | tr '[:lower:]' '[:upper:]')" in
            Y)
                # Prefer environment variable if provided
                if [ -n "$LOGO_PATH" ] && [ -f "$LOGO_PATH" ]; then
                    echo "Using logo from LOGO_PATH: $LOGO_PATH"
                    encode_base64_nowrap "$LOGO_PATH"
                    echo "Logo base64 saved to $LOGO_BASE64_OUT"
                    break
                fi

                # Ask user manually
                echo -n "Paste path to PNG logo file (Enter = use default): "
                read -r USER_LOGO
                USER_LOGO="${USER_LOGO/#\~/$HOME}"  # expand ~ if used

                if [ -z "$USER_LOGO" ]; then
                    if [ -f "$DEFAULT_LOGO" ]; then
                        echo "Using built‑in default logo."
                        encode_base64_nowrap "$DEFAULT_LOGO"
                        echo "$DEFAULT_LOGO" > logo_path.txt
                        echo "Logo path recorded to logo_path.txt"
                    else
                        echo "No default logo available; skipping."
                    fi
                    break
                elif [ -f "$USER_LOGO" ]; then
                    encode_base64_nowrap "$USER_LOGO"
                    echo "$USER_LOGO" > logo_path.txt
                    echo "Logo path recorded to logo_path.txt"
                    echo "Logo base64 saved to $LOGO_BASE64_OUT"
                    break
                else
                    echo "⚠️  File not found: $USER_LOGO"
                    continue
                fi
                ;;
            N)
                echo "Skipping logo."
                break
                ;;
            *)
                echo "Please enter Y or N."
                ;;
        esac
    done
}

# DISPLAY SUMMARY
display_summary() {
    echo -e "\n🔐 Policy Generation Complete 🔐"
    echo "Verification Key: keys/policy.vkey"
    echo "Signing Key:      keys/policy.skey"
    echo "Policy Script:    scripts/policy.script"
    echo "Policy ID:        $(cat keys/policy.id)"

    echo -e "\n📋 File Contents:"

    for file in keys/policy.vkey keys/policy.skey scripts/policy.script keys/policy.id asset_name.txt asset_name_hex.txt asset_id.txt display_name.txt description.txt url.txt; do
        if [ -f "$file" ]; then
            echo -e "\n==== $file ===="
            cat "$file"
        fi
    done

    if [ -f logo_base64.txt ]; then
        echo -e "\n==== logo_base64.txt (first 100 chars) ===="
        head -c 100 logo_base64.txt && echo "... [truncated]"
    fi
}

generate_metadata_json() {
    POLICY_ID=$(cat keys/policy.id)
    ASSET_NAME_HEX=$(cat asset_name_hex.txt)
    DISPLAY_NAME=$(cat display_name.txt)
    DESCRIPTION=$(cat description.txt)
    URL=$(cat url.txt)

    # optional logo
    LOGO_FIELD=""
    if [ -f logo_base64.txt ]; then
        LOGO=$(cat logo_base64.txt)
        LOGO_FIELD=",        \"logo\": \"$LOGO\""
    fi

    if [ "$ASSET_TYPE" = "fungible" ]; then
        cat > metadata.json <<EOF
{
  "name": "$DISPLAY_NAME",
  "description": "$DESCRIPTION",
  "ticker": "$DISPLAY_NAME",
  "policy": "$POLICY_ID",
  "url": "$URL"${LOGO_FIELD}
}
EOF
    else
        cat > metadata.json <<EOF
{
  "721": {
    "$POLICY_ID": {
      "$ASSET_NAME_HEX": {
        "name": "$DISPLAY_NAME",
        "description": "$DESCRIPTION",
        "url": "$URL"${LOGO_FIELD}
      }
    }
  }
}
EOF
    fi

    echo -e "\nmetadata.json created for minting!"
}

generate_payment_keys_and_address() {
    echo
    echo "Choose payment key type:"
    echo "1) Standard CLI key pair (no mnemonic)"
    echo "2) Mnemonic-derived 24-word wallet key"
    read -p "Enter choice [1-2]: " KEY_OPTION
    echo

    mkdir -p keys

    if [[ "$KEY_OPTION" == "2" ]]; then
        echo "🔑 Generating keys from a new 24-word mnemonic..."
        # Requirements: 'cardano-address' must be installed.
        # This will create wallet.mnemonic and derive keys
        MNEMONIC_FILE="keys/wallet.mnemonic"
        ROOT_KEY="keys/root.prv"
        PAYMENT_PRV="keys/payment.prv"
        PAYMENT_PUB="keys/payment.pub"
        if ! command -v cardano-address >/dev/null; then
            echo "Error: cardano-address not found; please install it first."
            return 1
        fi

        cardano-address recovery-phrase generate --size 24 > "$MNEMONIC_FILE"
        echo "Mnemonic saved to $MNEMONIC_FILE — store it safely (offline backup recommended). “We hide the generated mnemonic from terminal output for security reasons — anything printed to the console can end up in shell scrollback or command history, which isn’t considered safe storage for private keys.”"
        chmod 600 "$MNEMONIC_FILE"


        # Derive root and payment keys
        cardano-address key from-recovery-phrase Shelley < "$MNEMONIC_FILE" > "$ROOT_KEY"
        cardano-address key child 1852H/1815H/0H/0/0 < "$ROOT_KEY" > "$PAYMENT_PRV"


                # 🔧 FIX: add the required flag so the command succeeds
        cardano-address key public --with-chain-code < "$PAYMENT_PRV" > "$PAYMENT_PUB"

        # Convert to CLI-compatible key files
        # Convert to CLI-compatible payment keys
        cardano-cli key convert-cardano-address-key \
            --shelley-payment-key \
            --signing-key-file "$PAYMENT_PRV" \
            --out-file keys/payment.skey

        # Now derive the verification key from the converted signing key
        cardano-cli key verification-key \
            --signing-key-file keys/payment.skey \
            --verification-key-file keys/payment.vkey
    else
        echo "🔐 Generating standard CLI-based payment key pair..."
        cardano-cli address key-gen \
            --verification-key-file keys/payment.vkey \
            --signing-key-file keys/payment.skey
    fi

    # Build payment address
    # Build payment address
    cardano-cli address build \
        --payment-verification-key-file keys/payment.vkey \
        "$NETWORK" \
        --out-file keys/payment.addr

    if [[ $? -ne 0 ]]; then
        echo "❌ Failed to build payment address. Please check the previous logs for details."
        return 1
    fi

    echo
    echo "✅ Payment address built and saved to keys/payment.addr"
    echo "Address: $(cat keys/payment.addr)"
    echo
    echo "All key materials (and any mnemonic) are in ./keys/"
    echo "⚠️  Do NOT share or commit your mnemonic or signing keys!"

    return 0
}

check_dependencies() {
    for cmd in cardano-cli cardano-address jq; do
        command -v "$cmd" >/dev/null || { echo "Error: $cmd not found."; exit 1; }
    done
}

sign_token_metadata_json() {
    POLICY_ID=$(cat keys/policy.id)
    ASSET_NAME_HEX=$(cat asset_name_hex.txt)
    ASSET_NAME=$(cat asset_name.txt)
    POLICY_SCRIPT="scripts/policy.script"
    POLICY_SKEY="keys/policy.skey"
    SUBJECT="${POLICY_ID}${ASSET_NAME_HEX}"
    DISPLAY_NAME=$(cat display_name.txt)
    DESCRIPTION=$(cat description.txt)
    URL=$(cat url.txt)

    echo "Creating metadata for subject: $SUBJECT"
    echo "Using policy script: $POLICY_SCRIPT"

    # sanity check for required files
    for f in "$POLICY_SCRIPT" "$POLICY_SKEY" keys/policy.id asset_name_hex.txt asset_name.txt display_name.txt description.txt url.txt; do
        if [ ! -f "$f" ]; then
            echo "Error: Missing required file: $f"
            exit 1
        fi
    done
    # Prompt for registry metadata creation
    echo
    read -p "Do you want to create and SIGN a Cardano Token Registry metadata JSON (for submission to the Cardano Registry)? (Y/N): " create_signed

    case "${create_signed^^}" in
        Y)
            # Steps 1–6 (same as your code)
            token-metadata-creator entry --init "$SUBJECT"
            token-metadata-creator entry "$SUBJECT" \
                --name "$DISPLAY_NAME" \
                --description "$DESCRIPTION" \
                --policy "$POLICY_SCRIPT" \
                --url "$URL"

            if [ -f logo_base64.txt ]; then
                   DEFAULT_LOGO_PATH=$(cat logo_base64.txt)
               elif [ -f logo_path.txt ]; then
                   DEFAULT_LOGO_PATH=$(cat logo_path.txt)
               elif [ -n "$LOGO_PATH" ]; then
                   DEFAULT_LOGO_PATH="$LOGO_PATH"
               else
                   DEFAULT_LOGO_PATH=""
               fi


            echo "🖼  Logo detected."
            [ -n "$DEFAULT_LOGO_PATH" ] && echo "Found recorded logo path: $DEFAULT_LOGO_PATH"

            while true; do
                read -p "Please provide path to your logo PNG file for registry [Press Enter = use default]: " LOGO_PNG
                LOGO_PNG="${LOGO_PNG:-$DEFAULT_LOGO_PATH}"

                if [ -z "$LOGO_PNG" ]; then
                    echo "No default logo path recorded; need a valid file path."
                    continue
                fi

                if [ -f "$LOGO_PNG" ]; then
                    echo "Using logo: $LOGO_PNG"
                    token-metadata-creator entry "$SUBJECT" --logo "$LOGO_PNG"
                    break
                else
                    echo "File not found: $LOGO_PNG"
                    echo "Please try again."
                fi
            done

            read -p "Enter ticker (short symbol, or leave blank): " TICKER
            if [ -n "$TICKER" ]; then
                token-metadata-creator entry "$SUBJECT" --ticker "$TICKER"
            fi

            read -p "Enter decimals (number of decimal places, or leave blank for 0): " DECIMALS
            if [[ "$DECIMALS" =~ ^[0-9]+$ ]]; then
                token-metadata-creator entry "$SUBJECT" --decimals "$DECIMALS"
            fi

            token-metadata-creator entry "$SUBJECT" -a "$POLICY_SKEY"
            token-metadata-creator entry "$SUBJECT" --finalize

            OUT_JSON="${SUBJECT}.json"
            cp "$OUT_JSON" "signed_registry_metadata.json"

            echo
            echo "🎉 Signed registry metadata created as: signed_registry_metadata.json"
            echo "Short preview:"
            jq . signed_registry_metadata.json | head -40
            ;;
        N)
            echo "Skipping registry metadata/JSON signing."
            ;;
        *)
            echo "Please answer Y or N."
            ;;
    esac
}   # <-- this closing brace was missing!

# MAIN
main() {
    check_dependencies

    echo "==== Policy Creation ===="
    generate_policy_keys
    create_policy_script
    generate_policy_id

    echo "==== Asset Type Selection ===="
    echo "1) Fungible token"
    echo "2) NFT (non‑fungible token)"
    read -p "Choose asset type [1/2]: " asset_type
    echo

    case "$asset_type" in
        1)
            export ASSET_TYPE="fungible"
            echo "==== Fungible Token Metadata Preparation ===="
            ;;
        2|*)
            export ASSET_TYPE="nft"
            echo "==== NFT Metadata Preparation ===="
            ;;
    esac

    prompt_asset_name
    prompt_metadata
    display_summary
    generate_metadata_json "$ASSET_TYPE"
    sign_token_metadata_json

    echo
    read -p "Do you want to generate a payment key/address now? (Y/N): " make_payment_key
    case "${make_payment_key^^}" in
        Y)
            choose_network
            generate_payment_keys_and_address
            ;;
        *)
            echo "Skipping payment key/address generation."
            ;;
    esac

    echo
    echo "✅ All operations completed successfully."
}

main "$@"