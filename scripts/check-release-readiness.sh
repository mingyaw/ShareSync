#!/usr/bin/env bash
set -euo pipefail

transport="signed-http"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --transport)
      transport="${2:-}"
      shift 2
      ;;
    --help|-h)
      cat <<'USAGE'
Usage: scripts/check-release-readiness.sh [--transport signed-http|qr-pinned-https]

Checks pre-release gates that should fail fast before a build is treated as release-ready.
USAGE
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

case "$transport" in
  signed-http)
    ;;
  qr-pinned-https)
    results_file="docs/m2-device-validation-results.md"
    if [[ ! -f "$results_file" ]]; then
      echo "Missing validation results file: $results_file" >&2
      exit 1
    fi

    if rg -q "M4 QR-pinned HTTPS signoff is deferred|Deferred until explicitly requested|\\| Pass/Fail \\| Pending \\|" "$results_file"; then
      echo "QR-pinned HTTPS is not release-ready: M4 physical-device validation is still deferred or pending." >&2
      echo "Complete M4-SEC-001, M4-SEC-002, and M4-SEC-003 in $results_file before using this transport for release readiness." >&2
      exit 1
    fi
    ;;
  *)
    echo "Unsupported transport: $transport" >&2
    exit 2
    ;;
esac

ios_info_plist="ios/ShareSyncApp/Info.plist"
ios_privacy_manifest="ios/ShareSyncApp/PrivacyInfo.xcprivacy"
if [[ ! -f "$ios_info_plist" ]]; then
  echo "Missing iOS Info.plist: $ios_info_plist" >&2
  exit 1
fi

if [[ ! -f "$ios_privacy_manifest" ]]; then
  echo "Missing iOS privacy manifest: $ios_privacy_manifest" >&2
  exit 1
fi

plutil -lint "$ios_privacy_manifest" >/dev/null
rg -q 'NSPrivacyTracking' "$ios_privacy_manifest"
rg -q 'NSPrivacyAccessedAPICategoryUserDefaults' "$ios_privacy_manifest"
rg -q 'NSPrivacyAccessedAPICategoryDiskSpace' "$ios_privacy_manifest"
rg -q 'PrivacyInfo.xcprivacy in Resources' ios/ShareSync.xcodeproj/project.pbxproj

android_build_file="android/app/build.gradle.kts"
android_manifest_file="android/app/src/main/AndroidManifest.xml"
ios_project_file="ios/ShareSync.xcodeproj/project.pbxproj"

if [[ ! -f "$android_build_file" ]]; then
  echo "Missing Android build file: $android_build_file" >&2
  exit 1
fi

for permission in READ_MEDIA_IMAGES POST_NOTIFICATIONS FOREGROUND_SERVICE_DATA_SYNC; do
  if ! rg -q "android.permission.${permission}" "$android_manifest_file"; then
    echo "Missing Android release permission declaration: ${permission}" >&2
    exit 1
  fi
done

if [[ ! -f "$ios_project_file" ]]; then
  echo "Missing iOS project file: $ios_project_file" >&2
  exit 1
fi

android_version_name=$(awk -F'"' '/versionName =/ { print $2; exit }' "$android_build_file")
android_version_code=$(awk -F'= ' '/versionCode =/ { print $2; exit }' "$android_build_file" | tr -d ' ')
ios_marketing_versions=$(awk -F'= ' '/MARKETING_VERSION =/ { gsub(/;/, "", $2); print $2 }' "$ios_project_file" | sort -u)
ios_build_versions=$(awk -F'= ' '/CURRENT_PROJECT_VERSION =/ { gsub(/;/, "", $2); print $2 }' "$ios_project_file" | sort -u)
ios_marketing_version=$(printf '%s\n' "$ios_marketing_versions" | sed -n '1p')
ios_build_version=$(printf '%s\n' "$ios_build_versions" | sed -n '1p')

if [[ -z "$android_version_name" || -z "$android_version_code" || -z "$ios_marketing_version" || -z "$ios_build_version" ]]; then
  echo "Missing app version metadata. Android versionName/versionCode and iOS MARKETING_VERSION/CURRENT_PROJECT_VERSION are required." >&2
  exit 1
fi

if [[ "$(printf '%s\n' "$ios_marketing_versions" | sed '/^$/d' | wc -l | tr -d ' ')" != "1" ]]; then
  echo "iOS MARKETING_VERSION values are inconsistent across build configurations:" >&2
  printf '%s\n' "$ios_marketing_versions" >&2
  exit 1
fi

if [[ "$(printf '%s\n' "$ios_build_versions" | sed '/^$/d' | wc -l | tr -d ' ')" != "1" ]]; then
  echo "iOS CURRENT_PROJECT_VERSION values are inconsistent across build configurations:" >&2
  printf '%s\n' "$ios_build_versions" >&2
  exit 1
fi

if [[ "$android_version_name" != "$ios_marketing_version" ]]; then
  echo "Android versionName ($android_version_name) must match iOS MARKETING_VERSION ($ios_marketing_version)." >&2
  exit 1
fi

if [[ "$android_version_code" != "$ios_build_version" ]]; then
  echo "Android versionCode ($android_version_code) must match iOS CURRENT_PROJECT_VERSION ($ios_build_version)." >&2
  exit 1
fi

if /usr/libexec/PlistBuddy -c "Print :NSAppTransportSecurity:NSAllowsArbitraryLoads" "$ios_info_plist" >/dev/null 2>&1; then
  echo "iOS ATS is too broad: NSAllowsArbitraryLoads must not be enabled for release readiness." >&2
  exit 1
fi

if [[ "$transport" == "signed-http" ]]; then
  local_networking=$(/usr/libexec/PlistBuddy -c "Print :NSAppTransportSecurity:NSAllowsLocalNetworking" "$ios_info_plist" 2>/dev/null || true)
  if [[ "$local_networking" != "true" ]]; then
    echo "Signed local HTTP requires NSAllowsLocalNetworking=true in $ios_info_plist." >&2
    exit 1
  fi
fi

echo "Release readiness checks passed for transport: $transport"
