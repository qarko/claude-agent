FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Seoul
ENV LANG=ko_KR.UTF-8
ENV LANGUAGE=ko_KR:ko
ENV LC_ALL=ko_KR.UTF-8

# ── 1. 시스템 패키지 (이 이미지가 아니면 깔 수 없는 것들만) ──────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl wget gnupg lsb-release \
        openssh-server tmux \
        git jq ripgrep vim sudo \
        build-essential locales \
        python3 python3-pip python3-venv \
    && locale-gen ko_KR.UTF-8 \
    && update-locale LANG=ko_KR.UTF-8 \
    && mkdir -p /var/run/sshd \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── 2. Node.js 20.x ───────────────────────────────────────────────────────
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSL https://deb.nodesource.com/setup_20.x -o /tmp/nodesetup.sh \
    && bash /tmp/nodesetup.sh \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -f /tmp/nodesetup.sh \
    && rm -rf /var/lib/apt/lists/*

# ── 3. GitHub CLI ─────────────────────────────────────────────────────────
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# ── 4. Railway CLI ────────────────────────────────────────────────────────
RUN curl -fsSL https://railway.com/install.sh -o /tmp/railway-install.sh \
    && sh /tmp/railway-install.sh \
    && rm -f /tmp/railway-install.sh

# ── 5. Python 공통 패키지 ─────────────────────────────────────────────────
RUN pip3 install --no-cache-dir \
        pexpect requests python-dotenv pyyaml anthropic openai rich click

# ── 6. claude 유저 (sudoer, NOPASSWD) ─────────────────────────────────────
RUN useradd -m -s /bin/bash claude \
    && echo 'claude ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# ── 7. 공통 환경 (non-interactive shell에도 적용되도록 /etc/profile.d/) ──
RUN printf '%s\n' \
        'export TZ=Asia/Seoul' \
        'export LANG=ko_KR.UTF-8' \
        'export PATH="$HOME/.bun/bin:$HOME/.local/bin:/usr/local/bin:$PATH"' \
        > /etc/profile.d/qarko.sh \
    && chmod 644 /etc/profile.d/qarko.sh

# ── 8. SSH 기본 설정 (비밀번호는 런타임에 env로 주입) ────────────────────
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# ── 9. qarko-init + entrypoint 설치 ──────────────────────────────────────
COPY qarko-init /usr/local/bin/qarko-init
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /usr/local/bin/qarko-init /entrypoint.sh

EXPOSE 22
CMD ["/entrypoint.sh"]
