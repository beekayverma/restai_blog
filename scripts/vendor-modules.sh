#!/usr/bin/env bash
# Vendor a theme's Hugo modules into site/_vendor.
#
# Only Hugoplate needs this: it is a starter template built on Hugo Modules
# rather than a self contained theme. Vendoring means the modules are committed
# to this repo, so every later build is offline, reproducible and auditable,
# and the production build image never needs a Go toolchain.
#
# Run this again only when you deliberately want to update the modules.
#
#   ./scripts/vendor-modules.sh [theme]     default: hugoplate

set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

THEME="${1:-hugoplate}"
GO_IMAGE="${GO_IMAGE:-hugomods/hugo:debian-go-git-0.165.0}"
CONFIG="hugo.toml,config/themes/$THEME.toml"

if [ ! -f "site/config/themes/$THEME.toml" ]; then
  echo "vendor: no module config at site/config/themes/$THEME.toml" >&2
  exit 1
fi

echo "vendor: theme=$THEME  image=${GO_IMAGE##*:}"
echo "vendor: this step needs network access, later builds do not"

docker run --rm \
  -v "$PWD:/project" \
  -w /project/site \
  --user "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -e GOPATH=/tmp/go \
  -e GOFLAGS=-mod=mod \
  -e HUGO_CACHEDIR=/tmp/hugo_cache \
  "$GO_IMAGE" \
  sh -c "
    set -e
    [ -f go.mod ] || hugo mod init github.com/beekayverma/restai_blog
    # --config must precede the subcommand: 'hugo mod get' forwards any
    # trailing flags it does not recognise straight through to 'go get'.
    hugo --config '$CONFIG' mod vendor
  "

echo
echo "vendor: modules now in site/_vendor"
find site/_vendor -maxdepth 3 -name 'go.mod' 2>/dev/null | wc -l | xargs echo "vendor: module count:"
du -sh site/_vendor 2>/dev/null | cut -f1 | xargs echo "vendor: size:"
