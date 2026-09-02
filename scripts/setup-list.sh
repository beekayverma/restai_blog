#!/usr/bin/env bash
# Create the public subscriber list in Listmonk and wire its UUID into the site.
#
# Single opt-in on purpose: it needs no SMTP relay, so the subscribe form works
# from day one. Switch to double opt-in in the Listmonk admin before you send a
# first campaign, which is the point at which unverified addresses start to
# matter.
#
# Credentials are read from .env and never printed.

set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

[ -f .env ] || { echo "setup-list: no .env, run ./scripts/init-env.sh first" >&2; exit 1; }
set -a; . ./.env; set +a

LISTMONK="${LISTMONK:-http://localhost:9000}"
LIST_NAME="${LIST_NAME:-REST AI Blog}"

# Listmonk v6 gates its REST API behind a separate API user token, which cannot
# be created without either the admin UI or a database write. Since we need a
# database write either way, create the list directly in Postgres. The schema is
# stable and list creation carries no application side logic.
dc() { docker compose -f compose/docker-compose.yml --env-file .env "$@"; }

# Look first, then create. There is no unique constraint on lists.name, so
# ON CONFLICT would not fire and re-running would silently create duplicates.
uuid=$(dc exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA -c \
  "SELECT uuid FROM lists WHERE name='$LIST_NAME' ORDER BY id LIMIT 1;" \
  2>/dev/null | head -1 | tr -d '[:space:]')

if [ -n "$uuid" ]; then
  echo "setup-list: list '$LIST_NAME' already exists, reusing it"
else
  uuid=$(dc exec -T postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tA -c \
    "INSERT INTO lists (uuid, name, type, optin, description)
     VALUES (gen_random_uuid(), '$LIST_NAME', 'public', 'single',
             'Subscribers to the REST AI blog.')
     RETURNING uuid;" 2>/dev/null | head -1 | tr -d '[:space:]')
  echo "setup-list: created list '$LIST_NAME' (public, single opt-in)"
fi
echo "setup-list: list uuid $uuid"

[ -n "$uuid" ] || { echo "setup-list: failed to obtain a list UUID" >&2; exit 1; }
echo "setup-list: list uuid $uuid"

# The list UUID is a public identifier, it appears in the subscribe form HTML.
# It is not a secret, so it is safe to write into the committed site config.
python3 - "$uuid" <<'PY'
import io, re, sys
uuid = sys.argv[1]
p = 'site/hugo.toml'
s = io.open(p, encoding='utf-8').read()
s = re.sub(r'subscribeListUUID = "[^"]*"', 'subscribeListUUID = "%s"' % uuid, s)
io.open(p, 'w', encoding='utf-8').write(s)
print('setup-list: wrote subscribeListUUID into site/hugo.toml')
PY

# Keep .env in step too, for the deploy scripts.
if grep -q '^LISTMONK_LIST_UUID=' .env; then
  sed -i "s|^LISTMONK_LIST_UUID=.*|LISTMONK_LIST_UUID=$uuid|" .env
fi
echo "setup-list: done. Rebuild the site so the form carries the uuid: ./scripts/build.sh"
