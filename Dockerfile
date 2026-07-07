FROM node:20-bookworm-slim

# Install system tooling (git, curl, build essentials, python with venv support, gosu for user switching).
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    git \
    nano \
    curl \
    jq \
    python3 \
    python3-venv \
    python3-pip \
    build-essential \
    ca-certificates \
    gosu \
    gnupg \
    lsb-release \
    sqlite3 \
    lsof \
    pkg-config \
    default-libmysqlclient-dev \
  && rm -rf /var/lib/apt/lists/*

# Install Docker CLI (for Docker-in-Docker if needed)
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
  && apt-get update \
  && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
  && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI (gh)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && apt-get update \
  && apt-get install -y --no-install-recommends gh \
  && rm -rf /var/lib/apt/lists/*

# Install cloudflared (quick-tunnel for ./scripts/dev-up.sh prodCom — exposes the
# local backend on a https://*.trycloudflare.com URL so external services (e.g. an
# SMS provider) can reach inbound webhooks). Key ships already in binary GPG format.
RUN curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg -o /usr/share/keyrings/cloudflare-main.gpg \
  && echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared bookworm main" | tee /etc/apt/sources.list.d/cloudflared.list > /dev/null \
  && apt-get update \
  && apt-get install -y --no-install-recommends cloudflared \
  && rm -rf /var/lib/apt/lists/*

# Create an isolated Python environment for any pip-installed tooling.
RUN python3 -m venv /opt/venv \
  && /opt/venv/bin/pip install --upgrade pip \
  && ln -s /opt/venv/bin/python /usr/local/bin/python \
  && ln -s /opt/venv/bin/pip /usr/local/bin/pip

# Add venv and npm global bin to PATH (npm bin path finalized after global installs).
ENV NPM_CONFIG_PREFIX=/home/app/.npm-global
ENV DISABLE_AUTOUPDATER=1
# Default editor for git (merge/commit messages) and other CLI tools, so
# interactive git operations don't fail in this otherwise editor-less image.
ENV EDITOR=nano
# Effort applies container-wide (orchestrator + subagents + interactive `claude`/`cdv`) and OVERRIDES
# any per-launch --effort flag. xhigh is Opus 4.7's recommended default; `max` lifts the token-spend
# cap and tends to overthink — too costly for an autonomous loop. Changing this needs an image
# rebuild (`./run-claude.sh --build`); ENV is baked at build time.
ENV CLAUDE_CODE_EFFORT_LEVEL=xhigh
# No-op on the Opus 4.7 orchestrator (it's always adaptive); only forces a fixed thinking budget on
# the Sonnet 4.6 subagents.
ENV CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1
ENV PATH="/home/app/.npm-global/bin:/opt/venv/bin:${PATH}"

# Non-root user and workspace setup.
RUN useradd -m app \
  && groupadd -f docker \
  && usermod -aG docker app \
  && mkdir -p /workspace /home/app/.npm-global \
  && chown -R app:app /workspace /home/app/.npm-global

# Install Claude Code globally (npm-based install, auto-updater disabled).
USER app
RUN npm install -g @anthropic-ai/claude-code

# Install audio player for peon-ping + Playwright Chromium runtime libs
# (Playwright itself stays a project devDependency; only the OS libs Chromium
# needs to launch are baked here.)
USER root
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    alsa-utils \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
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
    libxshmfence1 \
    fonts-noto-color-emoji \
  && rm -rf /var/lib/apt/lists/*

# Install peon-ping for terminal notifications (relay mode)
USER app
RUN mkdir -p /home/app/.claude \
  && curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash -s -- --packs=peon \
  || true
# Backup peon-ping installation (volume mount will overwrite ~/.claude at runtime)
USER root
RUN cp -a /home/app/.claude /opt/peon-ping-backup 2>/dev/null || true

# Copy modular setup scripts into the image
COPY docker_setup/ /usr/local/bin/docker_setup/
RUN chmod +x /usr/local/bin/docker_setup/*.sh

# Copy entrypoint script (runs as root, sources docker_setup modules, then drops to app user)
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/bin/bash"]
