#!/usr/bin/env bash
# Puts the files Drift needs on the web into every app's web/ folder:
#
#   sqlite3.wasm     official build of the package:sqlite3 version locked in
#                    pubspec.lock (GitHub release of simolus3/sqlite3.dart)
#   drift_worker.js  drift's web worker, compiled here against the locked
#                    packages so both sides use the same sqlite3 version
#
# Run it from anywhere after upgrading drift or sqlite3, then commit the
# changed web/ files.
#
#   SQLITE3_WASM=/path/to/sqlite3.wasm tool/web_assets.sh
#
# uses a local copy of sqlite3.wasm instead of downloading it. Its SHA-256 is
# printed so it can be compared with the digest shown on the release page.
set -euo pipefail

cd "$(dirname "$0")/.."
flutter pub get >/dev/null

locked() {
  awk -v pkg="  $1:" '$0 == pkg {p=1} p && /version:/ {gsub(/"/, "", $2); print $2; exit}' pubspec.lock
}

package_root() {
  python3 -I -c '
import json, sys
from urllib.parse import urlparse, unquote
cfg = json.load(open(".dart_tool/package_config.json"))
uri = next(p["rootUri"] for p in cfg["packages"] if p["name"] == sys.argv[1])
print(unquote(urlparse(uri).path))
' "$1"
}

sqlite_version="$(locked sqlite3)"
drift_version="$(locked drift)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if [[ -n "${SQLITE3_WASM:-}" ]]; then
  cp "$SQLITE3_WASM" "$tmp/sqlite3.wasm"
else
  curl -fsSL -o "$tmp/sqlite3.wasm" \
    "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-${sqlite_version}/sqlite3.wasm"
fi

dart compile js -O4 --packages=.dart_tool/package_config.json \
  -o "$tmp/drift_worker.js" "$(package_root drift)/web/drift_worker.dart" >/dev/null

for app in apps/*/; do
  [[ -d "$app/web" ]] && grep -q 'drift_flutter:' "$app/pubspec.yaml" || continue
  cp "$tmp/sqlite3.wasm" "$tmp/drift_worker.js" "$app/web/"
  echo "updated ${app}web"
done

echo "sqlite3 ${sqlite_version}, drift ${drift_version}"
sha256sum "$tmp/sqlite3.wasm" | awk '{print "sqlite3.wasm sha256: " $1}'
