# Build Clawdbot from source 
FROM node:22-bookworm AS clawdbot-build

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    curl \
    python3 \
    make \
    g++ \
  && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /clawdbot

ARG CLAWDBOT_GIT_REF=main
RUN git clone --depth 1 --branch "${CLAWDBOT_GIT_REF}" https://github.com/clawdbot/clawdbot.git .

RUN pnpm install --frozen-lockfile || pnpm install --no-frozen-lockfile
RUN pnpm build
RUN pnpm ui:install && pnpm ui:build

# ---------------------------------------------------------------------------
# Runtime: code-server + tools + Clawdbot
# ---------------------------------------------------------------------------
FROM codercom/code-server:latest

USER root

# Base tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    gnupg \
    jq \
    postgresql-client \
    ripgrep \
    htop \
    vim \
    procps \
    sudo \
    wget \
    # Chrome dependencies
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libdbus-1-3 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libpango-1.0-0 \
    libcairo2 \
    libasound2 \
    libatspi2.0-0 \
    libxss1 \
    libxtst6 \
    fonts-liberation \
    fonts-noto-color-emoji \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI
RUN curl -sSfL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh && rm -rf /var/lib/apt/lists/*

# Node 22 + corepack (for pnpm)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs && rm -rf /var/lib/apt/lists/*

RUN corepack enable

# Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

# Google Chrome for browser automation
RUN wget -q -O /tmp/google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get update && apt-get install -y /tmp/google-chrome-stable_current_amd64.deb \
    && rm /tmp/google-chrome-stable_current_amd64.deb \
    && rm -rf /var/lib/apt/lists/*

# Chrome paths
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome-stable
ENV CHROME_BIN=/usr/bin/google-chrome-stable
ENV CHROME_PATH=/usr/bin/google-chrome-stable

# Copy Clawdbot build
COPY --from=clawdbot-build /clawdbot /clawdbot

# Global clawdbot command
RUN printf '%s\n' '#!/usr/bin/env bash' 'exec node /clawdbot/dist/index.js "$@"' > /usr/local/bin/clawdbot \
    && chmod +x /usr/local/bin/clawdbot

# Install additional apt packages if specified at build time
ARG CLAWDBOT_DOCKER_APT_PACKAGES=""
RUN if [ -n "$CLAWDBOT_DOCKER_APT_PACKAGES" ]; then \
    apt-get update && \
    apt-get install -y $CLAWDBOT_DOCKER_APT_PACKAGES && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*; \
    fi

# Clawdbot state directories
ENV CLAWDBOT_STATE_DIR=/home/coder/.clawdbot
ENV CLAWDBOT_WORKSPACE=/home/coder/clawd
RUN mkdir -p "${CLAWDBOT_STATE_DIR}" "${CLAWDBOT_WORKSPACE}" \
    && chown -R coder:coder "${CLAWDBOT_STATE_DIR}" "${CLAWDBOT_WORKSPACE}"

# VS Code extensions
RUN code-server --install-extension ms-python.python || true \
    && code-server --install-extension dbaeumer.vscode-eslint || true \
    && code-server --install-extension esbenp.prettier-vscode || true \
    && code-server --install-extension eamodio.gitlens || true

# Entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Verify installations
RUN gh --version && node -v && npm -v && clawdbot --help && google-chrome-stable --version

# Ports
# 18789 - Clawdbot Dashboard
# 18790 - WebChat
# 8443  - code-server
EXPOSE 18789 18790 8443

# Environment
ENV NODE_ENV=production
ENV CODE_SERVER_ENABLED=true
ENV GATEWAY_PORT=18789
ENV WAKE_DELAY=5
ENV WAKE_TEXT="Gateway started, checking in."

USER coder

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD clawdbot health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
