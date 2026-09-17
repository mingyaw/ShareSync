#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

transport="signed-http"
validation_status="Automated checks only; real-device validation deferred."
handoff_output=""
run_full="false"
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
    --artifact)
      artifacts+=("${2:-}")
      artifact_count=$((artifact_count + 1))
      shift 2
      ;;
    --handoff-output)
      handoff_output="${2:-}"
      shift 2
      ;;
    --full)
      run_full="true"
      shift
      ;;
    --help|-h)
      cat <<'USAGE'
Usage: scripts/check-beta-preflight.sh [--transport signed-http|qr-pinned-https] [--validation-status TEXT] [--artifact FILE] [--handoff-output FILE] [--full]

Runs beta handoff preflight checks and generates a handoff record.

Default checks:
  - git diff --check
  - scripts/check-ui-quality.sh
  - scripts/check-product-readiness.sh
  - scripts/check-release-readiness.sh
  - scripts/check-repo-hygiene.sh
  - scripts/test-support-snapshot-inspector.sh
  - scripts/inspect-support-snapshot.py
  - scripts/generate-beta-handoff.sh

Use --full to also run scripts/check-m0.sh. Real-device validation is intentionally not run by this script.
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

echo "== Whitespace check =="
git diff --check

echo
echo "== UI quality =="
bash scripts/check-ui-quality.sh

echo
echo "== Product readiness =="
bash scripts/check-product-readiness.sh

echo
echo "== Release readiness =="
bash scripts/check-release-readiness.sh --transport "$transport"

echo
echo "== Repository hygiene =="
bash scripts/check-repo-hygiene.sh

echo
echo "== Support snapshot inspector =="
python3 scripts/inspect-support-snapshot.py shared/fixtures/sample-support-snapshot-android.json --summary-only
python3 scripts/inspect-support-snapshot.py shared/fixtures/sample-support-snapshot-ios.json --summary-only

echo
echo "== Support snapshot inspector tests =="
bash scripts/test-support-snapshot-inspector.sh

if [[ "$run_full" == "true" ]]; then
  echo
  echo "== Full M0 gate =="
  ./scripts/check-m0.sh
fi

handoff_args=(
  --transport "$transport"
  --validation-status "$validation_status"
)

if [[ "$artifact_count" -gt 0 ]]; then
  for artifact in "${artifacts[@]}"; do
    handoff_args+=(--artifact "$artifact")
  done
fi

echo
echo "== Beta handoff record =="
if [[ -n "$handoff_output" ]]; then
  bash scripts/generate-beta-handoff.sh "${handoff_args[@]}" --output "$handoff_output"
else
  bash scripts/generate-beta-handoff.sh "${handoff_args[@]}"
fi

echo
echo "Beta preflight checks passed."
