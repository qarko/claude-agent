FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Seoul
ENV LANG=ko_KR.UTF-8
ENV LANGUAGE=ko_KR:ko
ENV LC_ALL=ko_KR.UTF-8

# Bun & Claude CLI 경로 (이미지 고정 — 볼륨과 독립)
ENV BUN_INSTALL=/opt/bun
ENV NPM_CONFIG_PREFIX=/usr/local
ENV PATH=/opt/bun/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ── 1. 시스템 패키지 ──────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl wget gnupg lsb-release \
        openssh-server tmux tini \
        git jq ripgrep vim sudo \
        build-essential locales \
        python3 python3-pip python3-venv \
        gettext-base rsync unzip patch procps \
    && locale-gen ko_KR.UTF-8 \
    && update-locale LANG=ko_KR.UTF-8 \
    && mkdir -p /var/run/sshd \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── 2. Node.js 20.x ───────────────────────────────────────────────────────
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

# ── 5. Bun (이미지 고정 경로 + /usr/local/bin symlink) ───────────────────
# Bun 설치 스크립트가 적절한 권한 설정. 추가 chmod 불필요.
# sudo secure_path 는 /opt/bun/bin 을 무시하므로 /usr/local/bin 에 symlink 추가.
RUN curl -fsSL https://bun.sh/install | bash \
    && ln -sf /opt/bun/bin/bun /usr/local/bin/bun \
    && ln -sf /opt/bun/bin/bunx /usr/local/bin/bunx

# ── 6. Claude CLI 전역 설치 (NPM_CONFIG_PREFIX=/usr/local) ───────────────
RUN npm install -g @anthropic-ai/claude-code

# ── 7. Python 공통 패키지 ─────────────────────────────────────────────────
RUN pip3 install --no-cache-dir \
        pexpect requests python-dotenv pyyaml anthropic openai rich click

# ── 8. yq (mikefarah/yq GitHub release) ──────────────────────────────────
RUN curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" \
        -o /usr/local/bin/yq \
    && chmod 755 /usr/local/bin/yq

# ── 9. claude 유저 (sudo whitelist는 보안 단계에서 축소 예정) ────────────
RUN useradd -m -s /bin/bash claude \
    && echo 'claude ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# ── 10. 공통 환경 (SSH 세션 포함) ────────────────────────────────────────
RUN printf '%s\n' \
        'export TZ=Asia/Seoul' \
        'export LANG=ko_KR.UTF-8' \
        'export BUN_INSTALL=/opt/bun' \
        'export NPM_CONFIG_PREFIX=/usr/local' \
        'export PATH="$HOME/.local/bin:/opt/bun/bin:/usr/local/bin:$PATH"' \
        > /etc/profile.d/qarko.sh \
    && chmod 644 /etc/profile.d/qarko.sh

# ── 11. SSH 설정 (보안 단계에서 key-only로 전환 예정) ───────────────────
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# ── 12. 이미지 식별자 (qarko-init 재실행 트리거) ────────────────────────
# 빌드 시점 snapshot. 이미지 업데이트 후 첫 부팅 시 qarko-init 재실행 결정에 사용.
ARG IMAGE_BUILD_ID
RUN IMAGE_ID="${IMAGE_BUILD_ID:-$(date -u +%Y%m%dT%H%M%SZ)}" \
    && echo "$IMAGE_ID" > /etc/qarko-image-id \
    && chmod 644 /etc/qarko-image-id

# ── 13. qarko-init + entrypoint 설치 ─────────────────────────────────────
COPY qarko-init /usr/local/bin/qarko-init
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /usr/local/bin/qarko-init /entrypoint.sh

EXPOSE 22

# ── 14. Healthcheck: sshd 프로세스 생존 확인 ─────────────────────────────
# start-period=90s — 첫 부팅 시 chown -R /home/claude (대용량 볼륨) 여유 확보.
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
    CMD pgrep -x sshd >/dev/null || exit 1

# tini를 PID 1로 두어 좀비 수확 보장
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/entrypoint.sh"]
