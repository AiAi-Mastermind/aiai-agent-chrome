#!/bin/bash
# Maintainer script (not for clients): refresh the launcher and jev-drive from pg-skills, record the source
# commit, and build dist/agent-chrome-kit-<version>.zip. The client SKILL.md in skill/ is edited by hand.
set -euo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${PG_SKILLS:-$HOME/Coding/pg-skills}/skills/agent-chrome"
cd "$KIT"
[ -z "$(git -C "$SRC" status --porcelain -- .)" ] || { echo "pg-skills agent-chrome has uncommitted changes; commit first" >&2; exit 1; }
cp "$SRC/bin/agent-chrome" "$SRC/bin/jev-drive" skill/bin/
cp "$SRC/config/jev-public-hosts.json" skill/config/
chmod 0755 skill/bin/agent-chrome skill/bin/jev-drive
COMMIT=$(git -C "$SRC" rev-parse --short HEAD)
VERSION="$(date +%Y.%m.%d)-$COMMIT"
printf 'version %s\nsource pg-skills %s\nlauncher sha256 %s\njev-drive sha256 %s\n' "$VERSION" "$COMMIT" \
  "$(shasum -a 256 skill/bin/agent-chrome | cut -c1-64)" "$(shasum -a 256 skill/bin/jev-drive | cut -c1-64)" > VERSION
mkdir -p dist
rm -f "dist/agent-chrome-kit-$VERSION.zip"
zip -qr "dist/agent-chrome-kit-$VERSION.zip" README.md VERSION install.sh uninstall.sh skill docs -x '*/__pycache__/*' '*.DS_Store'
echo "built dist/agent-chrome-kit-$VERSION.zip"
