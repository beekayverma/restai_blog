#!/usr/bin/env bash
# Back up the only state that matters: the subscriber database and any files
# uploaded through Listmonk.
#
# Posts are markdown in git, so they are already backed up by definition. The
# subscriber list is the one thing that cannot be reconstructed.
#
# Prints the archive path as its LAST line, so it can be captured:
#   archive=$(./scripts/backup.sh | tail -1)

set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

[ -f .env ] || { echo "backup: no .env found" >&2; exit 1; }
set -a; . ./.env; set +a

KEEP="${BACKUP_KEEP:-14}"
DEST="${BACKUP_DIR:-backups}"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

dc() { docker compose -f compose/docker-compose.yml --env-file .env "$@"; }

mkdir -p "$DEST"

# --clean --if-exists makes the dump safe to replay over an existing database.
dc exec -T postgres pg_dump \
  -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  --clean --if-exists --no-owner --no-privileges \
  > "$WORK/database.sql" 2>/dev/null

if [ ! -s "$WORK/database.sql" ]; then
  echo "backup: pg_dump produced nothing, is the stack running?" >&2
  exit 1
fi

# Uploads are optional: the volume may legitimately be empty.
if dc exec -T listmonk sh -c 'ls /listmonk/uploads' >/dev/null 2>&1; then
  dc exec -T listmonk tar -cf - -C /listmonk uploads > "$WORK/uploads.tar" 2>/dev/null || true
fi

{
  echo "created_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "subscribers=$(dc exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA \
        -c 'SELECT count(*) FROM subscribers' 2>/dev/null | tr -d '[:space:]')"
  echo "listmonk_image=$(grep -oE 'listmonk/listmonk:[^ ]+' compose/docker-compose.yml | head -1)"
} > "$WORK/manifest.txt"

ARCHIVE="$DEST/restai-backup-$STAMP.tar.gz"
tar -czf "$ARCHIVE" -C "$WORK" .

# Rotate, keeping the newest $KEEP.
ls -1t "$DEST"/restai-backup-*.tar.gz 2>/dev/null | tail -n "+$((KEEP + 1))" | while read -r old; do
  rm -f "$old"
done

echo "backup: $(grep '^subscribers=' "$WORK/manifest.txt" | cut -d= -f2) subscribers, $(du -h "$ARCHIVE" | cut -f1)" >&2
echo "$ARCHIVE"
