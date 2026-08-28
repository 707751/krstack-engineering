#!/usr/bin/env bash

set -euo pipefail

# ------------------------------------------------------------
# Production-safe Git update workflow
# ------------------------------------------------------------

REPO_PATH="/srv/apps/mcp-platform/source"
BRANCH="main"
DEPLOY_USER="deploysvc"

BACKUP_DIR="/tmp/mcp-platform-runtime-backup"
LOG_DIR="/var/log/mcp-platform"
LOG_FILE="${LOG_DIR}/git-update.log"

PROTECTED_FILES=(
  ".env"
  "instance"
  "data"
)

mkdir -p "$LOG_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "Starting Git update"

if [[ ! -d "$REPO_PATH/.git" ]]; then
  log "ERROR: Git repository not found at $REPO_PATH"
  exit 1
fi

cd "$REPO_PATH"

rm -rf "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

log "Backing up protected runtime files"

for item in "${PROTECTED_FILES[@]}"; do
  if [[ -e "$item" ]]; then
    cp -a "$item" "$BACKUP_DIR/"
    log "Backed up: $item"
  fi
done

log "Saving local Git changes"

sudo -H -u "$DEPLOY_USER" git stash push --all \
  -m "automatic-pre-deployment-stash" || true

log "Switching to branch: $BRANCH"

sudo -H -u "$DEPLOY_USER" git checkout "$BRANCH"

log "Pulling latest source"

sudo -H -u "$DEPLOY_USER" git pull --ff-only origin "$BRANCH"

log "Restoring protected runtime files"

for item in "${PROTECTED_FILES[@]}"; do
  if [[ -e "$BACKUP_DIR/$item" ]]; then
    rm -rf "$REPO_PATH/$item"
    cp -a "$BACKUP_DIR/$item" "$REPO_PATH/"
    log "Restored: $item"
  fi
done

chown -R "$DEPLOY_USER":"$DEPLOY_USER" "$REPO_PATH"

COMMIT_ID=$(sudo -H -u "$DEPLOY_USER" git rev-parse --short HEAD)
COMMIT_MSG=$(sudo -H -u "$DEPLOY_USER" git log -1 --pretty=%s)

log "Deployment source updated successfully"
log "Commit: $COMMIT_ID"
log "Message: $COMMIT_MSG"

rm -rf "$BACKUP_DIR"

log "Temporary backup removed"
log "Git update completed"
