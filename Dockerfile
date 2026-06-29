# ---- Stage 1: Builder — install all plugins with real API tokens ----
FROM node:26-bookworm-slim AS builder

# Use Aliyun mirror for apt
RUN sed -i 's|deb.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list.d/debian.sources 2>/dev/null; \
    sed -i 's|deb.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list 2>/dev/null; \
    true

# System deps (rarely changes → good cache layer)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    openssh-client \
    ca-certificates \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Use Taobao mirror for npm
RUN npm config set registry https://registry.npmmirror.com

# Install claude-code (changes only on version bump → good cache layer)
RUN npm install -g @anthropic-ai/claude-code

# Git config
RUN git config --global --add safe.directory '*' \
    && git config --global init.defaultBranch main

# Inject real token via BuildKit secret (not stored in image layers)
COPY builder-settings.json /root/.claude/settings.json
RUN --mount=type=secret,id=anthropic_token \
    if [ -s /run/secrets/anthropic_token ]; then \
      TOKEN=$(cat /run/secrets/anthropic_token); \
      jq --arg token "$TOKEN" \
         '.env.ANTHROPIC_AUTH_TOKEN = $token' \
         /root/.claude/settings.json > /tmp/s.json \
      && mv /tmp/s.json /root/.claude/settings.json; \
    fi

# Trigger plugin installation (most volatile layer → last)
RUN mkdir -p /tmp/workspace && cd /tmp/workspace && git init \
    && claude -p "hello" || true

# ---- Stage 2: Final — clean image with pre-installed plugins ----
FROM node:26-bookworm-slim

# Use Aliyun mirror for apt
RUN sed -i 's|deb.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list.d/debian.sources 2>/dev/null; \
    sed -i 's|deb.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list 2>/dev/null; \
    true

# System dependencies (full toolset, rarely changes → good cache layer)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    openssh-client \
    ca-certificates \
    curl \
    wget \
    jq \
    less \
    vim-tiny \
    ripgrep \
    fd-find \
    python3 \
    python3-pip \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Use Taobao mirror for npm
RUN npm config set registry https://registry.npmmirror.com

# Install claude-code
RUN npm install -g @anthropic-ai/claude-code

# Git config
RUN git config --global --add safe.directory '*' \
    && git config --global init.defaultBranch main

# Copy pre-installed plugins from builder (volatile → after stable layers)
COPY --from=builder /root/.claude/plugins /root/.claude/plugins

# Runtime config (most volatile → last)
COPY settings.json /root/.claude/settings.json
COPY claude.json /root/.claude.json
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

WORKDIR /workspace

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["--help"]
