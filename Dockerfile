FROM ubuntu:22.04

# --------------------------
# Base image setup
# --------------------------
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
# Install Cardano Wallet tools
# --------------------------
ENV CARDANO_WALLET_VERSION=v2025-03-31

RUN curl -L https://github.com/cardano-foundation/cardano-wallet/releases/download/${CARDANO_WALLET_VERSION}/cardano-wallet-${CARDANO_WALLET_VERSION}-linux64.tar.gz \
    | tar -xz && \
    mv cardano-wallet-${CARDANO_WALLET_VERSION}-linux64/* /usr/local/bin/ && \
    rm -rf cardano-wallet-${CARDANO_WALLET_VERSION}-linux64

# Optional sanity checks
RUN cardano-wallet version && cardano-cli --version && bech32 --help || true

# --------------------------
# Install Token Metadata Creator and Validator
# --------------------------
ENV TOKEN_METADATA_VERSION=v0.4.0.0

RUN curl -L https://github.com/input-output-hk/offchain-metadata-tools/releases/download/${TOKEN_METADATA_VERSION}/token-metadata-creator.tar.gz \
        | tar -xvzf - && \
    mv token-metadata-creator /usr/local/bin/ && \
    chmod +x /usr/local/bin/token-metadata-creator && \
    rm -f token-metadata-creator.tar.gz

RUN curl -L https://github.com/input-output-hk/offchain-metadata-tools/releases/download/${TOKEN_METADATA_VERSION}/metadata-validator-github.tar.gz \
        | tar -xvzf - && \
    mv metadata-validator-github /usr/local/bin/ && \
    chmod +x /usr/local/bin/metadata-validator-github && \
    rm -f metadata-validator-github.tar.gz

# --------------------------
# Copy project files
# --------------------------
WORKDIR /app
COPY . .

# Make sure entrypoint and helper scripts are executable
RUN chmod +x entrypoint.sh && \
    if [ -d run ]; then chmod +x run/*.sh || true; fi

ENTRYPOINT ["bash", "entrypoint.sh"]
