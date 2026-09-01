#!/usr/bin/env bash
# Build the site with a given theme.
#
#   ./scripts/build.sh                 build the active theme into site/public
#   ./scripts/build.sh congo           build congo into site/public
#   ./scripts/build.sh congo dist/congo  build congo into dist/congo
#
# Hugo runs in a pinned container, so nothing needs installing on the host and
# every machine builds with byte identical tooling.

set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

# Hugo versions are per theme, on purpose.
#
# There is a real split in the ecosystem right now. Hugo 0.158.0 changed how
# partials are looked up, which broke themes that used the old "partials/"
# prefix. Newer themes require 0.158.0 or later, older ones have not caught up:
#
#   Blowfish, TailBliss, Hugoplate  need >= 0.158.0 (Blowfish needs >= 0.162.0)
#   PaperMod, blog-awesome          break on >= 0.158.0
#
# Because builds run in containers, each theme simply gets the version it
# supports. This matters for the A/B decision: picking a theme that is pinned
# to an old Hugo means inheriting that constraint until upstream catches up.
HUGO_IMAGE_NEW="${HUGO_IMAGE_NEW:-hugomods/hugo:debian-node-git-0.165.0}"
HUGO_IMAGE_OLD="${HUGO_IMAGE_OLD:-hugomods/hugo:debian-node-git-0.157.0}"

hugo_image_for() {
  case "$1" in
    *) echo "$HUGO_IMAGE_NEW" ;;
  esac
}

ACTIVE_THEME_FILE=".active-theme"

# Which theme? Argument wins, then .active-theme, then the default.
if [ $# -ge 1 ] && [ -n "${1:-}" ]; then
  THEME="$1"
elif [ -f "$ACTIVE_THEME_FILE" ]; then
  THEME="$(tr -d '[:space:]' < "$ACTIVE_THEME_FILE")"
else
  THEME="papermod"
fi

OUT="${2:-site/public}"

if [ ! -d "site/themes/$THEME" ]; then
  echo "build: theme '$THEME' is not installed under site/themes/" >&2
  echo "available: $(ls -1 site/themes/ 2>/dev/null | tr '\n' ' ')" >&2
  exit 1
fi

# Base config plus the theme specific overlay, if one exists.
CONFIGS="hugo.toml"
if [ -f "site/config/themes/$THEME.toml" ]; then
  CONFIGS="hugo.toml,config/themes/$THEME.toml"
fi

# The repo root is mounted at /project and Hugo runs from /project/site, so an
# output path is simply /project/<OUT> and lands on the host.
HUGO_DEST="/project/$OUT"

HUGO_IMAGE="$(hugo_image_for "$THEME")"
echo "build: theme=$THEME  config=$CONFIGS  out=$OUT"
echo "build: hugo=${HUGO_IMAGE##*:}"

# Themes that ship a package.json need their dependencies before Hugo can
# process the Tailwind pipeline. Installed inside the container, into the
# theme directory, never onto the host.
NPM_STEP=""
if [ -f "site/themes/$THEME/package.json" ]; then
  if [ ! -d "site/themes/$THEME/node_modules" ]; then
    PM=$(python3 -c "
import json
d=json.load(open('site/themes/$THEME/package.json'))
pm=d.get('packageManager') or (d.get('devEngines',{}).get('packageManager',{}) or {}).get('name') or 'npm'
print(pm.split('@')[0])
" 2>/dev/null || echo npm)
    echo "build: installing $PM dependencies for $THEME (first run only)"
    if [ "$PM" = "pnpm" ]; then
      INSTALL="npm install -g pnpm --loglevel=error >/dev/null 2>&1 && pnpm install --no-frozen-lockfile --reporter=silent"
    else
      INSTALL="npm install --no-audit --no-fund --loglevel=error"
    fi
    NPM_STEP="cd /project/site/themes/$THEME && $INSTALL && cd /project/site &&"
  fi
fi

docker run --rm \
  -v "$PWD:/project" \
  -w /project/site \
  --user "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -e HUGO_ENV=production \
  -e HUGO_CACHEDIR=/tmp/hugo_cache \
  "$HUGO_IMAGE" \
  sh -c "export PATH=/project/site/themes/$THEME/node_modules/.bin:\$PATH; ${NPM_STEP} hugo --gc --minify --cleanDestinationDir \
           --theme '$THEME' \
           --config '$CONFIGS' \
           --destination '$HUGO_DEST'"

echo "build: wrote $OUT"
