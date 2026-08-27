#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE_LOG="${TMPDIR:-/tmp}/sharesync_m0_xcodebuild.log"

cd "$ROOT_DIR"

echo "== Fixture validation =="
python3 scripts/validate-fixtures.py
python3 scripts/compare-sync-results.py \
  shared/fixtures/sample-sync-result.json \
  shared/fixtures/sample-sync-result.json

echo
echo "== Swift package tests =="
swift test

echo
echo "== Android unit tests and Kotlin compile =="
(
  cd android
  ./gradlew :app:testDebugUnitTest :app:compileDebugKotlin
)

echo
echo "== iOS app build =="
xcodebuild \
  -project ios/ShareSync.xcodeproj \
  -scheme ShareSync \
  -destination 'generic/platform=iOS' \
  build > "$XCODE_LOG"

echo "iOS build log: $XCODE_LOG"
echo
echo "M0 checks passed."
