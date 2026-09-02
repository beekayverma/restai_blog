#!/usr/bin/env bash
# Build the same content with every candidate theme, then serve each on its own
# port so they can be compared side by side.
#
#   ./scripts/ab-build.sh          build all, then serve
#   ./scripts/ab-build.sh --build  build only
#   ./scripts/ab-build.sh --serve  serve what is already built
#
# This is the A/B: identical content, identical base config, one theme each.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

THEMES=(congo blowfish blog-awesome)
BASE_PORT=8081
MODE="${1:---all}"

build_all() {
  local rc=0
  for t in "${THEMES[@]}"; do
    printf '\n--- building %s ---\n' "$t"
    if timeout 900 ./scripts/build.sh "$t" "dist/$t" >"/tmp/ab_$t.log" 2>&1; then
      echo "  ok: $(find "dist/$t" -name '*.html' | wc -l) pages, $(du -sh "dist/$t" | cut -f1)"
    else
      echo "  FAILED, see /tmp/ab_$t.log"
      grep -m1 -oE 'ERROR.{0,200}' "/tmp/ab_$t.log" | sed 's/^/    /'
      rc=1
    fi
  done
  return $rc
}

serve_all() {
  echo
  echo "Serving. Open these side by side, then stop with: ./scripts/ab-build.sh --stop"
  local port=$BASE_PORT
  for t in "${THEMES[@]}"; do
    if [ -d "dist/$t" ]; then
      docker rm -f "restai-ab-$t" >/dev/null 2>&1
      docker run -d --name "restai-ab-$t" \
        -p "$port:80" \
        -v "$PWD/dist/$t:/usr/share/nginx/html:ro" \
        nginx:alpine >/dev/null 2>&1 \
        && printf '  %-14s http://localhost:%s\n' "$t" "$port"
      port=$((port + 1))
    fi
  done
}

stop_all() {
  for t in "${THEMES[@]}"; do docker rm -f "restai-ab-$t" >/dev/null 2>&1; done
  echo "stopped all A/B preview servers"
}

case "$MODE" in
  --build) build_all ;;
  --serve) serve_all ;;
  --stop)  stop_all ;;
  *)       build_all; serve_all ;;
esac
