#!/usr/bin/env bash

set -euo pipefail

# ------------------------------------------------------------
# Controlled rsync deployment workflow
# ------------------------------------------------------------

SOURCE_DIR="/srv/apps/mcp-platform/source/"
DEST_DIR="/srv/apps/mcp-platform/production/"

DEPLOY_USER="deploysvc"

CONFIG_DIR="/opt/deployment/mcp-platform"
EXCLUDE_FILE="${CONFIG_DIR}/rsync-exclude.txt"

BACKUP_ROOT="/srv/apps/mcp-platform/backups"
LOG_DIR="/var/log/mcp-platform"

TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"
LOG_FILE="${LOG_DIR}/rsync-deploy.log"

mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_ROOT"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "Starting rsync deployment"

if [[ ! -d "$SOURCE_DIR" ]]; then
  log "ERROR: Source directory not found: $SOURCE_DIR"
  exit 1
fi

if [[ ! -d "$DEST_DIR" ]]; then
  log "ERROR: Destination directory not found: $DEST_DIR"
  exit 1
fi

if [[ ! -f "$EXCLUDE_FILE" ]]; then
  log "ERROR: Rsync exclude file not found: $EXCLUDE_FILE"
  exit 1
fi

CHANGED_FILES="$(mktemp)"

cleanup() {
  rm -f "$CHANGED_FILES"
}

trap cleanup EXIT

log "Detecting changed files before deployment"

sudo -H -u "$DEPLOY_USER" rsync \
  -a \
  --dry-run \
  --itemize-changes \
  --exclude-from="$EXCLUDE_FILE" \
  "$SOURCE_DIR" "$DEST_DIR" \
  | awk '
      $1 !~ /^\*deleting/ && NF >= 2 {
          $1="";
          sub(/^ /, "");
          print
      }
    ' > "$CHANGED_FILES"

if [[ -s "$CHANGED_FILES" ]]; then
  mkdir -p "$BACKUP_DIR"

  log "Backing up existing destination files"

  while IFS= read -r relative_path; do
    [[ -z "$relative_path" ]] && continue

    source_path="${DEST_DIR}${relative_path}"

    if [[ -f "$source_path" ]]; then
      backup_path="${BACKUP_DIR}/${relative_path}"

      mkdir -p "$(dirname "$backup_path")"
      cp -a "$source_path" "$backup_path"

      log "Backed up: $relative_path"
    fi
  done < "$CHANGED_FILES"

else
  log "No existing destination files require backup"
fi

log "Promoting source to production"

sudo -H -u "$DEPLOY_USER" rsync \
  -a \
  --itemize-changes \
  --exclude-from="$EXCLUDE_FILE" \
  "$SOURCE_DIR" "$DEST_DIR" \
  | tee -a "$LOG_FILE"

log "Rsync deployment completed successfully"

if [[ -d "$BACKUP_DIR" ]]; then
  log "Backup location: $BACKUP_DIR"
fi
