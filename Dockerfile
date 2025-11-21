FROM ubuntu:22.04

# Combine installs to keep layers small
RUN apt-get update && \
    apt-get install -y \
        bash \
        curl \
        jq \
        tar \
        ca-certificates \
        vim-common \
    && rm -rf /var/lib/apt/lists/*

# --------------------------
# Install Cardano Wallet package (wallet, node, cli, bech32, address)
# --------------------------
ENV CARDANO_WALLET_VERSION=v2025-03-31

RUN curl -L https://github.com/cardano-foundation/cardano-wallet/releases/download/${CARDANO_WALLET_VERSION}/cardano-wallet-${CARDANO_WALLET_VERSION}-linux64.tar.gz \
    | tar -xz && \
    mv cardano-wallet-${CARDANO_WALLET_VERSION}-linux64/* /usr/local/bin/ && \
    rm -rf cardano-wallet-${CARDANO_WALLET_VERSION}-linux64

# Optional sanity checks (won’t make the build fail if missing)
RUN cardano-wallet version && cardano-cli --version && bech32 --help || true

# --------------------------
# Install Token Metadata Creator
# --------------------------
ENV TOKEN_METADATA_VERSION=v0.4.0.0
RUN curl -L https://github.com/input-output-hk/offchain-metadata-tools/releases/download/${TOKEN_METADATA_VERSION}/token-metadata-creator.tar.gz -o token-metadata-creator.tar.gz && \
    tar -xvzf token-metadata-creator.tar.gz && \
    mv token-metadata-creator /usr/local/bin/ && \
    chmod +x /usr/local/bin/token-metadata-creator && \
    rm token-metadata-creator.tar.gz

# --------------------------
# Install Metadata Validator
# --------------------------
RUN curl -L https://github.com/input-output-hk/offchain-metadata-tools/releases/download/${TOKEN_METADATA_VERSION}/metadata-validator-github.tar.gz -o metadata-validator-github.tar.gz && \
    tar -xvzf metadata-validator-github.tar.gz && \
    mv metadata-validator-github /usr/local/bin/ && \
    chmod +x /usr/local/bin/metadata-validator-github && \
    rm metadata-validator-github.tar.gz

# --------------------------
# Copy scripts
# --------------------------
WORKDIR /app
COPY generate.sh /usr/local/bin/generate.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /usr/local/bin/generate.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
