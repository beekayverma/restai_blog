# Runbook

## Daily operations

```bash
make up        # start the stack
make down      # stop it, data volumes are kept
make logs      # follow logs
make build     # rebuild the site after editing content
make test      # full acceptance suite
```

## Reaching the Listmonk admin

The admin panel is bound to loopback and is **not** proxied by Caddy, so it is
not reachable from the public site. On the server, tunnel to it:

```bash
ssh -L 9000:127.0.0.1:9000 you@your-server
```

Then open http://localhost:9000. Credentials are in `.env`:

```bash
grep LISTMONK_ADMIN_PASSWORD .env
```

## Subscribers

The list is **single opt-in**, which means no confirmation email and therefore
no SMTP relay is needed. That is deliberate for launch.

**Before sending a first campaign**, switch the list to double opt-in in the
admin and configure an SMTP relay. Unverified addresses only start to matter
once you are actually sending, at which point they damage deliverability.

Export subscribers from the admin, or straight from the database:

```bash
docker compose -f compose/docker-compose.yml --env-file .env exec -T postgres \
  psql -U listmonk -d listmonk -c "\copy (SELECT email, name, created_at FROM subscribers) TO STDOUT WITH CSV HEADER" \
  > subscribers.csv
```

## Backups

```bash
make backup                                    # dump database and uploads
make restore ARCHIVE=backups/restai-backup-...tar.gz
```

Archives land in `backups/`, which is gitignored because it contains subscriber
email addresses. The newest 14 are kept.

Posts are markdown in git and need no backup. The subscriber list is the only
state that cannot be reconstructed.

Schedule it on the server:

```cron
30 3 * * * cd /srv/restai_blog && ./scripts/backup.sh >> /var/log/restai-backup.log 2>&1
```

**Test the restore.** An untested backup is not a backup. `make test` exercises
a full round trip and asserts the subscriber count is unchanged.

## Updating

**Site content**: edit markdown, `make build`.

**Themes** are pinned submodules. To move one forward:

```bash
cd site/themes/congo && git fetch --tags && git checkout v2.15.0
cd - && make test
```

If you update Hugoplate, re-run `./scripts/vendor-modules.sh` and re-check
`site/layouts/_partials/essentials/style.html`, which is a copy of an upstream
template and can drift.

**Container images** are pinned in `compose/docker-compose.yml`. Bump the tag,
`make down && make up`, then `make test`.

## Rotating secrets

```bash
./scripts/init-env.sh --force
```

This invalidates the current PostgreSQL password, so the existing data volume
will no longer be readable. Back up first, recreate the volume, then restore.

## Troubleshooting

**Site shows old content.** Caddy serves `site/public`. Run `make build`.

**Subscribe returns 500.** Almost always a missing or wrong list UUID. Run
`./scripts/setup-list.sh` then `make build`.

**Build fails after pulling.** Themes are submodules:
`git submodule update --init --recursive`.

**Permission denied on build output.** Builds run as your own user. If older
root owned files remain, clear them with a container rather than sudo:

```bash
docker run --rm -v "$PWD:/project" alpine:3.20 \
  sh -c "find /project -user 0 -not -path '*/.git/*' -exec rm -rf {} +"
```
