### Files and Their Purpose (Generated During Key/Policy/Metadata Creation)

| File / Folder | Purpose |
|----------------|----------|
| `keys/payment.*` | Your wallet’s payment keys and address (used to hold ADA and receive the minted tokens). |
| `keys/policy.*` | The minting policy keys and script that define who can mint/burn under this policy. |
| `keys/policy.id` | The policy ID (hash of the policy script). |
| `metadata.json`, `description.txt`, `display_name.txt`, `logo_base64.txt`, `url.txt` | Token metadata used when registering or displaying your asset. |
| `scripts/policy.script` | The actual minting policy script file. |
| `asset_name.txt`, `asset_name_hex.txt`, `asset_id.txt` | Convenience files showing the asset name, its hex encoding, and the full asset ID (`policyID.assetNameHex`). |
| `.json` files named like `62864ce17e9…53494d53.json` | Each of these is a draft or generated metadata file for a specific token under that policy. If you’ve run the generator multiple times, you’ll see one per attempt. |
| `keys/wallet.mnemonic`, `keys/root.prv` | Your seed phrase and root private key — **these must stay offline and backed up securely.** |