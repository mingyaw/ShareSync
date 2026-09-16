#!/usr/bin/env bash
set -euo pipefail

transport="signed-http"
validation_status="Automated checks only; real-device validation deferred."
output_file=""
artifacts=()
artifact_count=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --transport)
      transport="${2:-}"
      shift 2
      ;;
    --validation-status)
      validation_status="${2:-}"
      shift 2
      ;;
    --output)
      output_file="${2:-}"
      shift 2
      ;;
    --artifact)
      artifacts+=("${2:-}")
      artifact_count=$((artifact_count + 1))
      shift 2
      ;;
    --help|-h)
      cat <<'USAGE'
Usage: scripts/generate-beta-handoff.sh [--transport signed-http|qr-pinned-https] [--validation-status TEXT] [--artifact FILE] [--output FILE]

Generates a markdown beta handoff record with commit, version, transport, and release-readiness status.
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
  signed-http|qr-pinned-https)
    ;;
  *)
    echo "Unsupported transport: $transport" >&2
    exit 2
    ;;
esac

android_build_file="android/app/build.gradle.kts"
ios_project_file="ios/ShareSync.xcodeproj/project.pbxproj"

android_version_name=$(awk -F'"' '/versionName =/ { print $2; exit }' "$android_build_file")
android_version_code=$(awk -F'= ' '/versionCode =/ { print $2; exit }' "$android_build_file" | tr -d ' ')
ios_marketing_version=$(awk -F'= ' '/MARKETING_VERSION =/ { gsub(/;/, "", $2); print $2; exit }' "$ios_project_file")
ios_build_version=$(awk -F'= ' '/CURRENT_PROJECT_VERSION =/ { gsub(/;/, "", $2); print $2; exit }' "$ios_project_file")
commit_sha=$(git rev-parse HEAD)
branch_name=$(git branch --show-current)
generated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [[ -n "$(git status --porcelain)" ]]; then
  working_tree_status="dirty"
else
  working_tree_status="clean"
fi

readiness_output=$(bash scripts/check-release-readiness.sh --transport "$transport")
android_support_summary=$(python3 scripts/inspect-support-snapshot.py shared/fixtures/sample-support-snapshot-android.json --summary-only)
ios_support_summary=$(python3 scripts/inspect-support-snapshot.py shared/fixtures/sample-support-snapshot-ios.json --summary-only)

artifact_rows=""
if [[ "$artifact_count" -gt 0 ]]; then
  for artifact in "${artifacts[@]}"; do
    if [[ -z "$artifact" ]]; then
      echo "Artifact path must not be empty." >&2
      exit 2
    fi

    if [[ ! -f "$artifact" ]]; then
      echo "Artifact does not exist or is not a file: $artifact" >&2
      exit 1
    fi

    if git ls-files --error-unmatch "$artifact" >/dev/null 2>&1; then
      echo "Artifact must not be tracked by Git: $artifact" >&2
      exit 1
    fi

    artifact_name=$(basename "$artifact")
    artifact_bytes=$(wc -c < "$artifact" | tr -d ' ')
    artifact_sha256=$(shasum -a 256 "$artifact" | awk '{ print $1 }')
    artifact_rows+="- \`$artifact_name\`: $artifact_bytes bytes, sha256 \`$artifact_sha256\`"$'\n'
  done
fi

if [[ -z "$artifact_rows" ]]; then
  artifact_rows="- No external artifacts recorded."
fi

emit_handoff() {
  cat <<EOF
# ShareSync Beta Handoff

Generated at: $generated_at

## Build Identity

- Commit: \`$commit_sha\`
- Branch: \`${branch_name:-detached}\`
- Working tree: \`$working_tree_status\`
- Android: \`$android_version_name ($android_version_code)\`
- iOS: \`$ios_marketing_version ($ios_build_version)\`
- Transport: \`$transport\`

## Readiness

- Release readiness gate: passed
- Validation status: $validation_status
- Support snapshot triage: Android and iOS sample snapshots passed local validation.

\`\`\`text
$readiness_output
\`\`\`

## Support Snapshot Triage

Android sample:

\`\`\`text
$android_support_summary
\`\`\`

iOS sample:

\`\`\`text
$ios_support_summary
\`\`\`

## Deferred Validation

- Real-device Android photo scanning, local network transfer, iOS Photos import, and iCloud Photos observation remain deferred unless the validation status above says otherwise.
- QR-pinned HTTPS release readiness remains deferred until M4 physical-device validation is completed and recorded.
- App Store and Google Play packaging, signing, and review checks are outside this source-code handoff record.

## Artifact Checksums

$artifact_rows

## Scope

- Photo-only Android-to-iOS local-network sync.
- iPhone imports received photos into Photos; iCloud backup depends on the user's existing iCloud Photos settings.
- No ShareSync cloud relay, third-party storage, Apple ID handling, iCloud credential access, or iCloud Drive access.
- No videos, contacts, files, reverse sync, delete propagation, or unattended iOS background sync.

## Required Handoff Notes

- Record where the Android and iOS artifacts are stored outside Git.
- Record whether physical-device validation was run or explicitly deferred.
- Record known limitations discovered during packaging or testing.
EOF
}

if [[ -n "$output_file" ]]; then
  mkdir -p "$(dirname "$output_file")"
  emit_handoff > "$output_file"
  echo "Beta handoff record written: $output_file"
else
  emit_handoff
fi
