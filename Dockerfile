FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Seoul
ENV LANG=ko_KR.UTF-8
ENV LANGUAGE=ko_KR:ko
ENV LC_ALL=ko_KR.UTF-8
ENV CLAUDE_HOME=/home/claude

# ── 1. 시스템 패키지 ──────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget gnupg lsb-release \
    openssh-server tmux screen expect sshpass \
    vim nano jq git rsync inotify-tools \
    ripgrep fd-find \
    htop tree net-tools \
    build-essential \
    locales \
    python3 python3-pip python3-venv \
    && locale-gen ko_KR.UTF-8 \
    && update-locale LANG=ko_KR.UTF-8 \
    && mkdir -p /var/run/sshd \
    && rm -rf /var/lib/apt/lists/*

# ── 2. Node.js 20.x ───────────────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# ── 3. GitHub CLI ─────────────────────────────────────────────────────────
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# ── 4. Railway CLI ────────────────────────────────────────────────────────
RUN curl -fsSL https://railway.com/install.sh | sh

# ── 5. Python 패키지 ──────────────────────────────────────────────────────
RUN pip3 install --no-cache-dir \
    pexpect requests python-dotenv \
    pyyaml anthropic openai \
    rich click

# ── 6. 유저 설정 ──────────────────────────────────────────────────────────
RUN useradd -m -s /bin/bash claude \
    && echo 'claude:claude123' | chpasswd \
    && echo 'claude ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && echo 'root:railway' | chpasswd

# ── 7. SSH 설정 ───────────────────────────────────────────────────────────
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# ── 8. Claude Code CLI + Bun (claude 유저 홈에 설치) ─────────────────────
RUN su - claude -c " \
    npm install -g @anthropic-ai/claude-code \
    && curl -fsSL https://bun.sh/install | bash \
"

# ── 9. PATH 설정 ──────────────────────────────────────────────────────────
RUN echo 'export PATH="$HOME/.bun/bin:$HOME/.local/bin:/usr/local/bin:$PATH"' >> /home/claude/.bashrc \
    && echo 'export TZ=Asia/Seoul' >> /home/claude/.bashrc \
    && echo 'export LANG=ko_KR.UTF-8' >> /home/claude/.bashrc

# ── 10. qarko-init + entrypoint 설치 ──────────────────────────────────────
COPY qarko-init /usr/local/bin/qarko-init
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /usr/local/bin/qarko-init /entrypoint.sh

EXPOSE 22
CMD ["/entrypoint.sh"]
