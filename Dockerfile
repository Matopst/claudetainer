FROM debian:bookworm-slim

# Avoid interactive prompts during install
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    jq \
    less \
    vim-tiny \
    dnsutils \
    net-tools \
    iputils-ping \
    git \
    openssl \
    netcat-openbsd \
    traceroute \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22 LTS
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg \
    && echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' > /etc/apt/sources.list.d/kubernetes.list \
    && apt-get update && apt-get install -y --no-install-recommends kubectl \
    && rm -rf /var/lib/apt/lists/*

# Cluster viewing tools: stern (multi-pod logs), k9s (TUI), helm (release inspection)
ARG K9S_VERSION=v0.51.0
ARG STERN_VERSION=1.35.0
RUN curl -fsSL https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz | tar -xz -C /usr/local/bin k9s \
    && curl -fsSL https://github.com/stern/stern/releases/download/v${STERN_VERSION}/stern_${STERN_VERSION}_linux_amd64.tar.gz | tar -xz -C /usr/local/bin stern \
    && curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# GitHub CLI + just (used to set up the developer-platform-agent repo)
ARG JUST_VERSION=1.59.0
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo 'deb [signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://just.systems/install.sh | bash -s -- --tag ${JUST_VERSION} --to /usr/local/bin

# Install Claude CLI globally
RUN npm install -g @anthropic-ai/claude-code

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

# Create non-root user
RUN useradd -m -s /bin/bash claude

# Switch to non-root user
USER claude
WORKDIR /home/claude

# Sets up the agent repo, then keeps the container alive
CMD ["/usr/local/bin/entrypoint.sh"]
