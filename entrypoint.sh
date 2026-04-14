#!/bin/bash
# Railway 컨테이너 진입점 (claude-code 서버)
# 설계: 시스템 서비스(sshd, tmux)만 준비하고 대기. 유저 환경 복원은
#       사람이 SSH 들어와서 `qarko-init` 실행 시 이뤄진다.

log() { echo "[entrypoint] $*"; }

# ── 1. SSH host key 생성 (없으면) ────────────────────────────────────────
# 이미지에 키를 박으면 모든 배포가 같은 호스트 키를 공유해 MITM 위험 → 런타임 생성.
if ! ls /etc/ssh/ssh_host_*_key >/dev/null 2>&1; then
    ssh-keygen -A >/dev/null 2>&1 && log "SSH host keys generated."
fi

# ── 2. SSH 비밀번호 주입 (환경변수 기반) ─────────────────────────────────
if [ -n "${SSH_ROOT_PASSWORD}" ]; then
    echo "root:${SSH_ROOT_PASSWORD}" | chpasswd
    log "root SSH password set from SSH_ROOT_PASSWORD."
elif passwd -l root >/dev/null 2>&1; then
    log "SSH_ROOT_PASSWORD not set — root account locked."
else
    log "FATAL: failed to lock root account; aborting to avoid unauthenticated SSH."
    exit 1
fi

if [ -n "${SSH_CLAUDE_PASSWORD}" ]; then
    echo "claude:${SSH_CLAUDE_PASSWORD}" | chpasswd
    log "claude SSH password set from SSH_CLAUDE_PASSWORD."
elif passwd -l claude >/dev/null 2>&1; then
    log "SSH_CLAUDE_PASSWORD not set — claude account locked."
else
    log "FATAL: failed to lock claude account; aborting."
    exit 1
fi

# ── 3. sshd 시작 (데몬) ──────────────────────────────────────────────────
# SSH는 이 컨테이너의 존재 이유이므로 실패 시 fail-fast (Railway 재시작 유도).
if /usr/sbin/sshd; then
    log "sshd started on :22."
else
    log "FATAL: sshd failed to start — exiting so Railway reboots."
    exit 1
fi

# ── 4. /home/claude 소유권 보정 (필요할 때만) ────────────────────────────
# 볼륨이 root:root로 마운트되는 첫 부팅에만 chown. 재부팅마다 -R 돌리면 느림.
if [ "$(stat -c %U /home/claude 2>/dev/null)" != "claude" ]; then
    chown -R claude:claude /home/claude 2>/dev/null \
        && log "Fixed /home/claude ownership to claude." \
        || log "WARN: chown /home/claude failed."
fi

# (tmux 세션 생성은 qarko-init이 담당 — entrypoint는 시스템 서비스만)

# ── 5. 첫 부팅 안내 ──────────────────────────────────────────────────────
if [ ! -d /home/claude/.claude ]; then
    log ""
    log "================================================================"
    log " First boot detected. No /home/claude/.claude found."
    log " SSH in and run:  qarko-init"
    log " (This restores memories, projects, Claude CLI, and Bun.)"
    log "================================================================"
fi

# ── 6. 컨테이너 유지 ─────────────────────────────────────────────────────
log "Container ready. SSH into :22."
exec tail -f /dev/null
