# AdaData – Air‑Gapped Token Metadata Toolkit
A secure, offline‑ready toolkit for creating and managing Cardano token metadata.

AdaData is a self‑contained Docker environment for generating and signing Cardano token metadata, designed for fully offline or isolated workflows.

We recommend running Docker once to obtain dependencies, then transferring the resulting environment to an air‑gapped system for secure use.

The offline copy contains everything necessary to generate and sign metadata without internet access.
---

## Features
- Reproducible, air‑gapped generation of wallet and policy keys  
- Metadata and registry file creation  
- Optional base‑64 logo embedding  
- Deterministic Docker container for predictable outputs  

---

## Quick Start

(Requires Docker and Git installed locally.)

    git clone https://github.com/simsara-org/adadata.git
    cd adadata
    docker build -t adadata .
    docker run --rm -v "$(pwd)":/work adadata
   

Outputs are written to `cardano_policy/`.

Back up the keys/ folder securely before deletion or transfer to an offline medium.


### Alternative (no Docker)

You can run the scripts directly on a machine with the Cardano CLI installed.
Install `cardano-cli` and ensure it’s in your `$PATH`, then:
   
   ./scripts/generate-policy.sh
   # Creates ./policy/policy.script and key pair under ./keys/
   
---

## Directory Layout
| Path | Purpose |
|------|----------|
| `keys/` | Offline key pairs for policy and payment addresses (keep these secret) |
| `metadata.json` | Metadata definition for your native asset |
| `scripts/` | Helper scripts such as `generate-policy.sh`, `mint.sh`, `validate.sh` |
| `Dockerfile` | Defines the air‑gapped build environment |
| `cardano_policy/keys/`     | Offline key pairs (keep secret)                      |
| `cardano_policy/metadata.json` | Token metadata definition                         |



## Transparency and Provenance
AdaData executes only visible, auditable commands drawn from
official Cardano repositories and open‑source tooling.  
No proprietary or third‑party binaries are fetched, and the container
performs **no outbound network activity** during any stage of use.  

All scripts are included in this repository for review, ensuring
that every build step can be independently verified and reproduced.

---

## Security Notes
- Keep everything under `cardano_policy/keys/` offline and **never commit it** to a public repo.  
- The container itself makes **no outbound network calls**—all data remains locally generated.  


---

## Next Steps
- Implement `mint.sh` (token minting flow)  
- Implement `validate.sh` (metadata validator)  
- Expand examples to include minimal policy lifecycles based on the official Cardano “Minting Native Assets” documentation  

---

## Author / Maintainer
**Patrick Peluse** (@simsara‑official)  
**Simsara Org** – open‑source tools for secure Cardano workflows  
GitHub → [https://github.com/simsara-org](https://github.com/simsara-org)

_Not affiliated with Input Output Global (IOHK), Cardano Foundation, or Emurgo.  
Provided as open‑source educational tools._

---
## License
This project is licensed under the [Apache License 2.0](LICENSE).

The [NOTICE](NOTICE) file provides attribution and licensing information
for this project and any referenced Cardano open‑source components
included in the container build.

All code and container definitions are version‑pinned to enable deterministic rebuilds.


