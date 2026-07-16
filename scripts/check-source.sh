#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

swiftc -frontend -parse "$ROOT"/macos/Sources/GlassTranslate/*.swift "$ROOT"/macos/Tests/GlassTranslateTests/*.swift
find "$ROOT/windows" \( -name '*.xaml' -o -name '*.manifest' \) -print0 | xargs -0 -n1 xmllint --noout

echo "Swift syntax and XML checks passed."

