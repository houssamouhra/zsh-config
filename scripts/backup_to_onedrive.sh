#!/usr/bin/env bash
set -euo pipefail
HOME_DIR="/Users/jesse"
SRC_DIR="$HOME_DIR/git-jesse/zsh-config"
DEST_DIR="$HOME_DIR/Library/CloudStorage/OneDrive-IBM/backups/zsh-config-backups"
LOG_FILE="$HOME_DIR/Library/Logs/zsh-config-backup.log"
KEEP=30

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >>"$LOG_FILE"
}

mkdir -p "$DEST_DIR"

timestamp="$(date +%Y-%m-%d_%H%M%S)"
archive="$DEST_DIR/zsh-config-backup_${timestamp}.tgz"

if tar --exclude=".venv" --exclude=".git" --exclude="target" -czf "$archive" -C "$(dirname "$SRC_DIR")" "$(basename "$SRC_DIR")"; then
    size="$(du -h "$archive" | cut -f1)"
    log "created $archive ($size)"
else
    log "FAILED to create $archive"
    rm -f "$archive"
    exit 1
fi

# Retention: keep the most recent $KEEP archives, delete the rest.
mapfile -t archives < <(ls -1t "$DEST_DIR"/zsh-config-backup_*.tgz 2>/dev/null)
if [ "${#archives[@]}" -gt "$KEEP" ]; then
    for old in "${archives[@]:$KEEP}"; do
        rm -f "$old"
        log "removed old backup $old"
    done
fi
