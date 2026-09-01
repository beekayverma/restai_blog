#!/usr/bin/env bash
# Acceptance suite for the REST AI blog.
#
# Written before the implementation, per the TDD rule. Every check below is
# expected to FAIL on a fresh checkout and to go green as each phase lands.
#
# Usage:
#   ./tests/acceptance.sh          run everything
#   ./tests/acceptance.sh static   build and content checks only, no containers
#   ./tests/acceptance.sh services container, subscribe and backup checks only
#
# Env overrides:
#   SITE_OUT   built site directory        (default site/public)
#   BASE_URL   running site               (default http://localhost:8080)
#   LISTMONK   running Listmonk           (default http://localhost:9000)

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

SITE_OUT="${SITE_OUT:-site/public}"
BASE_URL="${BASE_URL:-http://localhost:8080}"
LISTMONK="${LISTMONK:-http://localhost:9000}"
MODE="${1:-all}"

LINKEDIN='linkedin.com/in/bhupender-v-042a2450'
pass_n=0; fail_n=0; skip_n=0

pass() { printf '\033[32m  PASS\033[0m  %s\n' "$1"; pass_n=$((pass_n+1)); }
fail() { printf '\033[31m  FAIL\033[0m  %s\n' "$1"; [ $# -gt 1 ] && printf '        %s\n' "$2"; fail_n=$((fail_n+1)); }
skip() { printf '\033[33m  SKIP\033[0m  %s\n' "$1"; skip_n=$((skip_n+1)); }
head_() { printf '\n\033[1m%s\033[0m\n' "$1"; }

have_site()  { [ -d "$SITE_OUT" ]; }
url_up()     { curl -fsS -o /dev/null --max-time 5 "$1" 2>/dev/null; }
compose()    { docker compose -f compose/docker-compose.yml --env-file .env "$@" 2>/dev/null; }

# =============================================================== 1. style
run_style() {
  head_ "1. Style and secrets"
  if [ -x scripts/check-style.sh ]; then
    if out=$(./scripts/check-style.sh 2>&1); then
      pass "check-style clean"
    else
      fail "check-style reported problems" "$(echo "$out" | grep -E '^(FAIL|  )' | head -5)"
    fi
  else
    fail "scripts/check-style.sh missing or not executable"
  fi
}

# =============================================================== 2. build
run_build() {
  head_ "2. Build"
  if [ ! -f site/hugo.toml ]; then
    fail "site/hugo.toml does not exist"
    return
  fi
  if [ ! -x scripts/build.sh ]; then
    fail "scripts/build.sh missing or not executable"
    return
  fi
  if out=$(./scripts/build.sh 2>&1); then
    if echo "$out" | grep -qiE '^(WARN|ERROR)'; then
      fail "build emitted warnings" "$(echo "$out" | grep -iE '^(WARN|ERROR)' | head -3)"
    else
      pass "site builds with no warnings"
    fi
  else
    fail "build failed" "$(echo "$out" | tail -3)"
  fi
}

# ============================================================= 3. content
run_content() {
  head_ "3. Content and structure"

  if ! have_site; then
    fail "no built site at $SITE_OUT, skipping content checks"
    return
  fi

  # Home carries the initiative, not just a post list.
  if [ -f "$SITE_OUT/index.html" ]; then
    if grep -qi 'responsible.*ethical.*safe.*trustworthy' "$SITE_OUT/index.html"; then
      pass "home page states the REST AI initiative"
    else
      fail "home page does not expand the REST AI acronym"
    fi
  else
    fail "home page missing at $SITE_OUT/index.html"
  fi

  # Blog listing exists.
  if [ -f "$SITE_OUT/blog/index.html" ]; then
    pass "blog listing exists at /blog/"
  else
    fail "blog listing missing at $SITE_OUT/blog/index.html"
  fi

  # About page carries the real LinkedIn URL.
  if [ -f "$SITE_OUT/about/index.html" ]; then
    if grep -q "$LINKEDIN" "$SITE_OUT/about/index.html"; then
      pass "about page links the correct LinkedIn profile"
    else
      fail "about page is missing the LinkedIn URL"
    fi
  else
    fail "about page missing at $SITE_OUT/about/index.html"
  fi

  # Ordering, verified from RSS pubDates rather than trusting the theme's markup.
  if [ -f "$SITE_OUT/index.xml" ]; then
    local dates count
    dates=$(grep -o '<pubDate>[^<]*</pubDate>' "$SITE_OUT/index.xml" \
            | sed 's/<[^>]*>//g' || true)
    count=$(echo "$dates" | grep -c . || true)
    if [ "$count" -lt 1 ]; then
      fail "RSS feed has no items"
    elif [ "$count" -eq 1 ]; then
      pass "RSS feed valid (1 item, ordering not yet assertable)"
    else
      # Convert to epoch and confirm the sequence is non increasing.
      local sorted
      sorted=$(echo "$dates" | while read -r d; do date -d "$d" +%s 2>/dev/null || echo 0; done)
      if [ "$sorted" = "$(echo "$sorted" | sort -rn)" ]; then
        pass "posts sort newest to oldest ($count items, verified by date)"
      else
        fail "posts are NOT in newest first order"
      fi
    fi
  else
    fail "RSS feed missing at $SITE_OUT/index.xml"
  fi

  [ -f "$SITE_OUT/sitemap.xml" ] && pass "sitemap.xml generated" || fail "sitemap.xml missing"

  # Subscribe form must exist and point somewhere real.
  # Hugo --minify strips attribute quotes, so accept action=/subscribe too.
  if grep -rqsE 'action="?/subscribe' "$SITE_OUT"/index.html "$SITE_OUT"/blog 2>/dev/null; then
    pass "subscribe form present and posting to /subscribe"
  else
    fail "no subscribe form posting to /subscribe found"
  fi

  # OpenGraph, because LinkedIn is the distribution channel.
  if grep -qs 'property="og:title"' "$SITE_OUT/index.html"; then
    pass "OpenGraph tags present for link previews"
  else
    fail "OpenGraph tags missing, shared links will render badly on LinkedIn"
  fi
}

# ============================================================ 4. services
run_services() {
  head_ "4. Services"

  if ! docker info >/dev/null 2>&1; then
    fail "docker is not available"
    return
  fi
  if [ ! -f compose/docker-compose.yml ]; then
    fail "compose/docker-compose.yml does not exist"
    return
  fi

  if url_up "$LISTMONK/health"; then
    pass "listmonk health endpoint responds"
  else
    fail "listmonk not reachable at $LISTMONK/health"
  fi

  # Postgres must be up AND carry the Listmonk schema.
  if compose exec -T postgres pg_isready -U listmonk >/dev/null 2>&1; then
    pass "postgres accepting connections"
    if compose exec -T postgres psql -U listmonk -d listmonk -tAc \
         "select to_regclass('public.subscribers')" 2>/dev/null | grep -q subscribers; then
      pass "listmonk schema installed in postgres"
    else
      fail "listmonk schema not found in postgres"
    fi
  else
    fail "postgres not accepting connections"
  fi

  # Nothing but Postgres. Assert no other database crept into the stack.
  if grep -qiE 'image:.*(mysql|mariadb|mongo)' compose/docker-compose.yml 2>/dev/null; then
    fail "a non Postgres database is present in the compose file"
  else
    pass "postgres is the only database in the stack"
  fi
}

# ====================================================== 5. subscribe e2e
run_subscribe() {
  head_ "5. Subscribe, end to end"

  if ! url_up "$BASE_URL/"; then
    fail "site not being served at $BASE_URL"
    return
  fi

  local addr="acceptance-$$@restai.test"
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
         -X POST "$BASE_URL/subscribe" \
         -H 'Content-Type: application/x-www-form-urlencoded' \
         --data-urlencode "email=$addr" \
         --data-urlencode "name=Acceptance Test" \
         --data-urlencode 'l=' 2>/dev/null)

  if [ "$code" = "200" ] || [ "$code" = "302" ]; then
    pass "subscribe endpoint accepted the submission (HTTP $code)"
  else
    fail "subscribe endpoint returned HTTP $code"
    return
  fi

  # The real assertion: it reached the database.
  local found
  found=$(compose exec -T postgres psql -U listmonk -d listmonk -tAc \
          "select count(*) from subscribers where email='$addr'" 2>/dev/null | tr -d '[:space:]')
  if [ "$found" = "1" ]; then
    pass "subscriber row created in postgres"
    compose exec -T postgres psql -U listmonk -d listmonk -tAc \
      "delete from subscribers where email='$addr'" >/dev/null 2>&1
  else
    fail "no subscriber row in postgres for the submitted address"
  fi
}

# ============================================================ 6. security
run_security() {
  head_ "6. Security headers"

  if ! url_up "$BASE_URL/"; then
    fail "site not being served at $BASE_URL"
    return
  fi

  local headers
  headers=$(curl -sSI --max-time 5 "$BASE_URL/" 2>/dev/null | tr 'A-Z' 'a-z')
  for h in x-content-type-options referrer-policy content-security-policy permissions-policy; do
    if echo "$headers" | grep -q "^$h:"; then
      pass "$h set"
    else
      fail "$h missing"
    fi
  done

  # The Listmonk admin panel must not be publicly reachable.
  if curl -fsS -o /dev/null --max-time 5 "$BASE_URL/admin" 2>/dev/null; then
    fail "listmonk admin is reachable through the public site"
  else
    pass "listmonk admin not exposed publicly"
  fi
}

# ============================================================== 7. backup
run_backup() {
  head_ "7. Backup and restore"

  if [ ! -x scripts/backup.sh ] || [ ! -x scripts/restore.sh ]; then
    fail "backup.sh or restore.sh missing or not executable"
    return
  fi

  local before after archive
  before=$(compose exec -T postgres psql -U listmonk -d listmonk -tAc \
           'select count(*) from subscribers' 2>/dev/null | tr -d '[:space:]')
  if [ -z "$before" ]; then
    fail "cannot read subscriber count, is the stack up?"
    return
  fi

  if ! archive=$(./scripts/backup.sh 2>/dev/null | tail -1); then
    fail "backup.sh failed"
    return
  fi
  if [ ! -f "$archive" ]; then
    fail "backup did not produce an archive at $archive"
    return
  fi
  pass "backup produced $archive"

  if ./scripts/restore.sh "$archive" >/dev/null 2>&1; then
    after=$(compose exec -T postgres psql -U listmonk -d listmonk -tAc \
            'select count(*) from subscribers' 2>/dev/null | tr -d '[:space:]')
    if [ "$before" = "$after" ]; then
      pass "restore round trip preserved subscriber count ($before)"
    else
      fail "restore changed subscriber count" "before=$before after=$after"
    fi
  else
    fail "restore.sh failed"
  fi
}

# ================================================================== main
echo "REST AI blog acceptance suite"
echo "============================="

case "$MODE" in
  static)   run_style; run_build; run_content ;;
  services) run_services; run_subscribe; run_security; run_backup ;;
  *)        run_style; run_build; run_content
            run_services; run_subscribe; run_security; run_backup ;;
esac

printf '\n\033[1mResult\033[0m  %d passed, %d failed, %d skipped\n' "$pass_n" "$fail_n" "$skip_n"
[ "$fail_n" -eq 0 ] || exit 1
