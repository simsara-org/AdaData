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
        bc \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# --------------------------
# Install Cardano Wallet tools
# --------------------------
ENV CARDANO_WALLET_VERSION=v2025-03-31
RUN curl -L https://github.com/cardano-foundation/cardano-wallet/releases/download/${CARDANO_WALLET_VERSION}/cardano-wallet-${CARDANO_WALLET_VERSION}-linux64.tar.gz \
    | tar -xz && \
    mv cardano-wallet-${CARDANO_WALLET_VERSION}-linux64/* /usr/local/bin/ && \
    rm -rf cardano-wallet-${CARDANO_WALLET_VERSION}-linux64

# --------------------------
# Overwrite with latest official Node / CLI
# --------------------------
# ARG CARDANO_NODE_VERSION=10.6.1
#
# RUN mkdir -p /tmp/cnode && cd /tmp/cnode && \
#     curl -L \
#       "https://github.com/IntersectMBO/cardano-node/releases/download/${CARDANO_NODE_VERSION}/cardano-node-${CARDANO_NODE_VERSION}-linux.tar.gz" \
#       -o node.tar.gz && \
#     tar -xzf node.tar.gz && \
#     find . -type f -name 'cardano-cli' -exec mv {} /usr/local/bin/ \; && \
#     find . -type f -name 'cardano-node' -exec mv {} /usr/local/bin/ \; && \
#     chmod +x /usr/local/bin/cardano-cli /usr/local/bin/cardano-node && \
#     cd / && rm -rf /tmp/cnode

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
# Copy project files and set permissions
# --------------------------
COPY . .

# *** critical line: ensure /app/db is a directory ***
RUN rm -f /app/db && mkdir -p /app/db /app/tx /app/cardano_policy/keys

# docker run --rm -it \
#   --user "$(id -u):$(id -g)" \
#   -v "$PWD":/app \
#   -v /media/pp/Elements/pp/db/node.socket:/tmp/node.socket \
#   -e NETWORK="--mainnet" \
#   -e KEYS_DIR=/app/cardano_policy/keys \
#   -e TX_DIR=/app/tx \
#   -e PAYMENT_ADDR="$(cat cardano_policy/keys/payment.addr)" \
#   -e CARDANO_NODE_SOCKET_PATH=/tmp/node.socket \
#   adadata

#Testnet
# docker run --rm -it \
#   --user $(id -u):$(id -g) \
#   -v "$PWD":/app \
#   -v /media/pp/22f153d3-1f53-4f5a-8f01-b03ab3e179f4/pp/db/node.socket:/app/db/node.socket \
#   -e KEYS_DIR=/app/cardano_policy/keys \
#   -e TX_DIR=/app/tx \
#   -e PAYMENT_ADDR="$(cat cardano_policy/keys/payment.addr)" \
#   -e CARDANO_NODE_SOCKET_PATH=/app/db/node.socket \
#   adadata

RUN chmod +x entrypoint.sh && \
    if [ -d run ]; then chmod +x run/*.sh || true; fi && \
    chmod a+x /app/run/generate.sh

# --------------------------
# Sanity checks (optional)
# --------------------------
RUN cardano-wallet version && \
    cardano-cli version && \
    bech32 --help >/dev/null && \
    echo "Cardano tools installed successfully."

ENTRYPOINT ["bash", "entrypoint.sh"]