#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -z "${SDKROOT:-}" && -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
  export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
fi
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/wonder-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR:-/tmp}/wonder-swift-cache"

swift build -c release
APP="$ROOT/.build/Wonder.app"
CONTENTS="$APP/Contents"
rm -rf "$APP"
# Remove the obsolete pre-rename bundle so it cannot be launched alongside
# Wonder and leave a second “GlassTranslate” menu-bar item running.
rm -rf "$ROOT/.build/GlassTranslate.app"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$ROOT/.build/release/Wonder" "$CONTENTS/MacOS/Wonder"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Resources/Wonder.icns" "$CONTENTS/Resources/Wonder.icns"
chmod +x "$CONTENTS/MacOS/Wonder"
# A project-local development identity keeps Accessibility authorization stable
# across source rebuilds without weakening the designated requirement.
"$ROOT/scripts/sign-app.sh" "$APP"
echo "$APP"
