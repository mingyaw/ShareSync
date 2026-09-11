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

echo "Release readiness checks passed for transport: $transport"
