#!/bin/bash
# Railway 컨테이너 진입점
# 순서: sshd 시작 → 환경 복원 체크 → tmux main 세션 생성 → 대기

set -e

log() { echo "[entrypoint] $*"; }

# ── 1. sshd 시작 ─────────────────────────────────────────────────────────
log "Starting sshd..."
/usr/sbin/sshd
log "sshd started."

# ── 2. /home/claude 복원 체크 ─────────────────────────────────────────────
# volume mount 시 .claude 디렉토리가 없으면 자동 복원 시도
if [ ! -d "/home/claude/.claude" ]; then
    log "No .claude directory found — attempting auto-restore..."

    BACKUP_CLONE_DIR="/home/claude/dev-env-backup"

    if [ -n "${GITHUB_TOKEN}" ]; then
        CLONE_URL="https://${GITHUB_TOKEN}@github.com/qarko/dev-env-backup.git"
    else
        CLONE_URL="https://github.com/qarko/dev-env-backup.git"
    fi

    if git clone --depth=1 "$CLONE_URL" "$BACKUP_CLONE_DIR" 2>&1; then
        log "dev-env-backup cloned. Running restore.sh..."
        cd "$BACKUP_CLONE_DIR"
        bash restore.sh
        log "Restore complete."
    else
        log "WARNING: Could not clone dev-env-backup. Run 'qarko-init' manually after SSH login."
    fi
else
    log ".claude directory exists — skipping auto-restore (volume data intact)."
fi

# ── 3. tmux main 세션 생성 (claude 유저로) ───────────────────────────────
log "Creating tmux main session..."
su - claude -c "tmux new-session -d -s main -c /home/claude 2>/dev/null && echo 'tmux main session created.' || echo 'tmux main session already exists.'"

# ── 4. 컨테이너 유지 ─────────────────────────────────────────────────────
log "Container ready. SSH into port 22."
tail -f /dev/null
