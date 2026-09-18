#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

for milestone in {43..50}; do
  test -s "docs/m${milestone}-source-rc.md"
  test -s "tasks/m${milestone}-source-rc.md"
done

bash scripts/check-ui-quality.sh
bash scripts/check-product-readiness.sh
bash scripts/check-release-readiness.sh --transport signed-http
bash scripts/check-repo-hygiene.sh

plutil -lint ios/ShareSyncApp/PrivacyInfo.xcprivacy >/dev/null
rg -q 'PrivacyInfo.xcprivacy in Resources' ios/ShareSync.xcodeproj/project.pbxproj
rg -q 'sinceCursor: manifestCursor' ios/ShareSyncApp/ManifestFetchViewModel.swift
rg -q 'BonjourLocalPeerDiscovery' ios/ShareSyncApp/ManifestFetchViewModel.swift
rg -q '\.missing' ios/ShareSync/Transfer/M0PhotoTransferPlanner.swift
rg -q 'Range: bytes=0-' shared/protocol/api-contract.md
rg -q 'RequestSignatureValidator' android/app/src/main/java/com/sharesync/android/transfer/server/LocalSyncRouter.kt

echo "M50 source RC checks passed. Physical-device and store submission gates remain separate."
