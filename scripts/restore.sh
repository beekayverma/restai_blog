#!/usr/bin/env bash
# Restore a backup produced by scripts/backup.sh.
#
#   ./scripts/restore.sh backups/restai-backup-20260902-120000.tar.gz
#
# This REPLACES the current subscriber database. The dump is taken with
# --clean --if-exists, so it drops and recreates objects as it replays.

set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

ARCHIVE="${1:-}"
[ -n "$ARCHIVE" ] || { echo "restore: usage: $0 <archive.tar.gz>" >&2; exit 1; }
[ -f "$ARCHIVE" ] || { echo "restore: no such archive: $ARCHIVE" >&2; exit 1; }
[ -f .env ] || { echo "restore: no .env found" >&2; exit 1; }
set -a; . ./.env; set +a

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
tar -xzf "$ARCHIVE" -C "$WORK"

[ -f "$WORK/database.sql" ] || { echo "restore: archive has no database.sql" >&2; exit 1; }
[ -f "$WORK/manifest.txt" ] && sed 's/^/restore: /' "$WORK/manifest.txt" >&2

dc() { docker compose -f compose/docker-compose.yml --env-file .env "$@"; }

# Listmonk holds open connections that would block object drops.
dc stop listmonk >/dev/null 2>&1 || true

dc exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=0 \
  < "$WORK/database.sql" >/dev/null 2>&1

if [ -f "$WORK/uploads.tar" ]; then
  dc start listmonk >/dev/null 2>&1
  sleep 3
  dc exec -T listmonk tar -xf - -C /listmonk < "$WORK/uploads.tar" 2>/dev/null || true
else
  dc start listmonk >/dev/null 2>&1
fi

count=$(dc exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA \
        -c 'SELECT count(*) FROM subscribers' 2>/dev/null | tr -d '[:space:]')
echo "restore: complete, $count subscribers" >&2
