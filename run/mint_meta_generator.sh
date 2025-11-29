# --------------------------------------------------------------
# mint_metadata_generator.sh
# --------------------------------------------------------------
create_mint_meta_from_registry() {
  local policy_id="$1"
  local asset_name="$2"
  local output_file="$3"

  mkdir -p "$(dirname "$output_file")"
  local registry_json="./cardano_policy/registry.json"

  if [[ -f "$registry_json" ]]; then
    local TOKEN_NAME TICKER DESCRIPTION LOGO_REF DECIMALS
    TOKEN_NAME=$(jq -r '.name.value // empty' "$registry_json")
    TICKER=$(jq -r '.ticker.value // empty' "$registry_json")
    DESCRIPTION=$(jq -r '.description.value // empty' "$registry_json")
    LOGO_REF=$(jq -r '.logoSrc.value // empty' "$registry_json")
    DECIMALS=$(jq -r '.decimals.value // 0' "$registry_json")

    echo "✅ Found registry.json – pre‑filling mint metadata:"
    echo "   Name:        $TOKEN_NAME"
    echo "   Ticker:      $TICKER"
    echo "   Description: $DESCRIPTION"
    echo "   Decimals:    $DECIMALS"
    echo "   LogoRef:     $LOGO_REF"
  else
    echo "⚠️  registry.json not found – falling back to manual entry."
    read -rp "Enter asset name: " TOKEN_NAME
    read -rp "Enter ticker: " TICKER
    read -rp "Enter description: " DESCRIPTION
    read -rp "Enter decimals (default 0): " DECIMALS
    read -rp "Enter logo IPFS/URL (optional): " LOGO_REF
  fi

  # ---------------- Logo source selector ----------------

  echo
  echo "Select logo source:"
  echo "  1) Use existing encoded PNG (./cardano_policy/logo.base64)"
  echo "  2) Enter a remote Logo URL (e.g., https://simsara.com/logo.png)"
  read -r -p "Enter choice [1‑2]: " logo_choice

  case "$logo_choice" in
    1)
      if [[ -f ./cardano_policy/logo.base64 ]]; then
        LOGO_REF=$(<./cardano_policy/logo.base64)
        echo "✅ Using embedded base64 logo."
      else
        echo "⚠️  logo.base64 not found; keeping previous logo ref."
      fi
      ;;
    2)
      read -rp "Enter remote logo URL: " user_logo
      LOGO_REF="$user_logo"
      echo "✅ Using remote logo URL: $LOGO_REF"
      ;;
    *)
      echo "⚠️  Invalid selection – leaving logo as: $LOGO_REF"
      ;;
  esac

  # -------------------------------------------------------

  # Produce lightweight, CLI‑ready metadata
  jq -n \
    --arg pid "$policy_id" \
    --arg aname "$asset_name" \
    --arg name "$TOKEN_NAME" \
    --arg ticker "$TICKER" \
    --arg desc "$DESCRIPTION" \
    --argjson dec "${DECIMALS:-0}" \
    --arg logo "$LOGO_REF" \
    '{
      "20": {
        ($pid): {
          ($aname): {
            name: $name,
            ticker: $ticker,
            description: $desc,
            decimals: $dec,
            logo: $logo
          }
        }
      }
    }' > "$output_file"

  echo "✅ Mint metadata generated at $output_file"

}

# --------------------------------------------------------------
# NFT metadata (unchanged)
# --------------------------------------------------------------
create_nft_metadata() {
  local policy_id="$1"
  local asset_name="$2"
  local output_file="$3"
  mkdir -p "$(dirname "$output_file")"

  read -rp "Enter display name for NFT: " TOKEN_NAME
  read -rp "Enter description: " DESCRIPTION
  read -rp "Enter image URL (ipfs://... or https://...): " IMAGE
  read -rp "Enter media type (e.g. image/png): " MEDIA_TYPE

  jq -n \
    --arg policy "$policy_id" \
    --arg asset "$asset_name" \
    --arg name  "$TOKEN_NAME" \
    --arg desc  "$DESCRIPTION" \
    --arg image "$IMAGE" \
    --arg mediaType "$MEDIA_TYPE" \
    '{
      "721": {
        ($policy): {
          ($asset): {
            name: $name,
            description: $desc,
            image: $image,
            mediaType: $mediaType
          }
        },
        version: "1.0"
      }
    }' > "$output_file"

  echo "✅ NFT metadata JSON saved to $output_file"
}

choose_metadata_template() {
  echo "Select metadata template:"
  select opt in "Fungible (auto from registry)" "NFT (manual CIP‑25)"; do
    case $REPLY in
      1) create_mint_meta_from_registry "$@"; break ;;
      2) create_nft_metadata "$@"; break ;;
      *) echo "Invalid option."; continue ;;
    esac
  done
}