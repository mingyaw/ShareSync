#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

inspector=(python3 scripts/inspect-support-snapshot.py)
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

echo "== Valid support snapshots =="
"${inspector[@]}" shared/fixtures/sample-support-snapshot-android.json --summary-only >/dev/null
"${inspector[@]}" shared/fixtures/sample-support-snapshot-ios.json --summary-only >/dev/null
echo "ok valid support snapshots"

expect_failure() {
  local label="$1"
  local expected="$2"
  shift 2

  local output
  set +e
  output="$("$@" 2>&1)"
  local status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    echo "Expected failure for $label, but command passed." >&2
    exit 1
  fi

  if [[ "$output" != *"$expected"* ]]; then
    echo "Expected failure for $label to include: $expected" >&2
    echo "$output" >&2
    exit 1
  fi

  echo "ok rejected $label"
}

python3 -c 'import json, sys; value=json.load(open(sys.argv[1])); del value["nextStep"]; json.dump(value, open(sys.argv[2], "w"))' \
  shared/fixtures/sample-support-snapshot-ios.json "$tmp_dir/missing-next-step.json"
python3 -c 'import json, sys; value=json.load(open(sys.argv[1])); value["nextStep"]="sync_remaining_photos"; json.dump(value, open(sys.argv[2], "w"))' \
  shared/fixtures/sample-support-snapshot-android.json "$tmp_dir/android-ios-next-step.json"
python3 -c 'import json, sys; value=json.load(open(sys.argv[1])); value["nextStep"]="scan_from_iphone"; json.dump(value, open(sys.argv[2], "w"))' \
  shared/fixtures/sample-support-snapshot-ios.json "$tmp_dir/ios-android-next-step.json"
python3 -c 'import json, sys; value=json.load(open(sys.argv[1])); value["pairingToken"]="secret"; json.dump(value, open(sys.argv[2], "w"))' \
  shared/fixtures/sample-support-snapshot-ios.json "$tmp_dir/sensitive-marker.json"

echo
echo "== Invalid support snapshots =="
expect_failure "missing nextStep" "nextStep must be a non-empty string" \
  "${inspector[@]}" "$tmp_dir/missing-next-step.json"
expect_failure "Android snapshot with iOS nextStep" "nextStep is not valid for android: sync_remaining_photos" \
  "${inspector[@]}" "$tmp_dir/android-ios-next-step.json"
expect_failure "iOS snapshot with Android nextStep" "nextStep is not valid for ios: scan_from_iphone" \
  "${inspector[@]}" "$tmp_dir/ios-android-next-step.json"
expect_failure "sensitive marker leakage" "sensitive marker must not appear outside redaction: $.pairingToken" \
  "${inspector[@]}" "$tmp_dir/sensitive-marker.json"

echo
echo "Support snapshot inspector tests passed."
