#!/usr/bin/env python3

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
SCHEMA_PATH = ROOT / "shared" / "schemas" / "support-snapshot.schema.json"
SENSITIVE_MARKERS = (
    "pairingtoken",
    "requestsignature",
    "sharedsecret",
    "authorization",
    "x-sharesync-signature",
)


def load_json(path: Path | None) -> dict[str, Any]:
    if path is None:
        raw = sys.stdin.read()
    else:
        raw = path.read_text(encoding="utf-8")

    try:
        value = json.loads(raw)
    except json.JSONDecodeError as error:
        raise SystemExit(f"Invalid JSON: {error}") from error

    if not isinstance(value, dict):
        raise SystemExit("Support snapshot must be a JSON object.")
    return value


def validate_snapshot(snapshot: dict[str, Any]) -> list[str]:
    schema = load_schema()
    errors: list[str] = []

    for key in schema["required"]:
        if key not in snapshot:
            errors.append(f"missing required field: {key}")

    if snapshot.get("schemaVersion") != 1:
        errors.append("schemaVersion must be 1")
    if snapshot.get("type") != "sharesync_support_snapshot":
        errors.append("type must be sharesync_support_snapshot")
    if snapshot.get("platform") not in ("android", "ios"):
        errors.append("platform must be android or ios")
    if not isinstance(snapshot.get("appVersion"), str) or not snapshot.get("appVersion"):
        errors.append("appVersion must be a non-empty string")
    if not isinstance(snapshot.get("phase"), str) or not snapshot.get("phase"):
        errors.append("phase must be a non-empty string")
    if not isinstance(snapshot.get("transport"), str) or not snapshot.get("transport"):
        errors.append("transport must be a non-empty string")

    generated_at = snapshot.get("generatedAt")
    if not isinstance(generated_at, str):
        errors.append("generatedAt must be a string")
    else:
        try:
            datetime.fromisoformat(generated_at.replace("Z", "+00:00"))
        except ValueError:
            errors.append("generatedAt must be an RFC3339 date-time")

    redaction = snapshot.get("redaction")
    if not isinstance(redaction, dict):
        errors.append("redaction must be an object")
    else:
        for key in ("pairingToken", "requestSignature", "sharedSecret"):
            if redaction.get(key) != "excluded":
                errors.append(f"redaction.{key} must be excluded")

    if not isinstance(snapshot.get("sync"), dict):
        errors.append("sync must be an object")

    sensitive_paths = find_sensitive_values(snapshot)
    for path in sensitive_paths:
        errors.append(f"sensitive marker must not appear outside redaction: {path}")

    return errors


def load_schema() -> dict[str, Any]:
    with SCHEMA_PATH.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def find_sensitive_values(value: Any, path: str = "$") -> list[str]:
    findings: list[str] = []
    if path.startswith("$.redaction"):
        return findings

    if isinstance(value, dict):
        for key, child in value.items():
            lowered_key = key.lower()
            if any(marker in lowered_key for marker in SENSITIVE_MARKERS):
                findings.append(f"{path}.{key}")
            findings.extend(find_sensitive_values(child, f"{path}.{key}"))
    elif isinstance(value, list):
        for index, item in enumerate(value):
            findings.extend(find_sensitive_values(item, f"{path}[{index}]"))
    elif isinstance(value, str):
        lowered_value = value.lower()
        if any(marker in lowered_value for marker in SENSITIVE_MARKERS):
            findings.append(path)

    return findings


def summarize(snapshot: dict[str, Any]) -> str:
    platform = snapshot.get("platform", "unknown")
    version = snapshot.get("appVersion", "unknown")
    build = snapshot.get("buildNumber")
    version_text = f"{version} ({build})" if build is not None else str(version)
    sync = snapshot.get("sync") if isinstance(snapshot.get("sync"), dict) else {}

    lines = [
        "Support snapshot summary",
        f"- Platform: {platform}",
        f"- Version: {version_text}",
        f"- Phase: {snapshot.get('phase', 'unknown')}",
        f"- Transport: {snapshot.get('transport', 'unknown')}",
        f"- Endpoint: {snapshot.get('endpoint', 'not provided')}",
    ]

    if platform == "android":
        android = snapshot.get("android") if isinstance(snapshot.get("android"), dict) else {}
        latest_request = snapshot.get("latestRequest") if isinstance(snapshot.get("latestRequest"), dict) else {}
        lines.extend(
            [
                f"- Server running: {android.get('serverRunning', 'unknown')}",
                f"- Pending photos: {android.get('pendingPhotos', 'unknown')}",
                f"- Latest request: {latest_request.get('endpoint', 'none')} / {latest_request.get('statusCode', 'none')}",
                f"- Latest sync: synced {sync.get('synced', 0)}, skipped {sync.get('skipped', 0)}, failed {sync.get('failed', 0)}",
            ]
        )
    elif platform == "ios":
        ios = snapshot.get("ios") if isinstance(snapshot.get("ios"), dict) else {}
        lines.extend(
            [
                f"- Binding: {snapshot.get('binding', 'unknown')}",
                f"- Manifest: {ios.get('manifest', 'unknown')}",
                f"- Batch progress: {ios.get('batchProgress', 'none')}",
                f"- Sync result return: {ios.get('syncResultReturn', 'unknown')}",
                f"- Photos: imported {sync.get('imported', 0)}, remaining {sync.get('remaining', 0)}, failed {sync.get('failed', 0)}, partial {sync.get('partial', 0)}",
            ]
        )

    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate and summarize a ShareSync support snapshot.")
    parser.add_argument("snapshot", nargs="?", type=Path, help="Snapshot JSON file. Reads stdin when omitted.")
    parser.add_argument("--summary-only", action="store_true", help="Only print the summary when valid.")
    args = parser.parse_args()

    snapshot = load_json(args.snapshot)
    errors = validate_snapshot(snapshot)
    if errors:
        print("Support snapshot validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    if not args.summary_only:
        print("Support snapshot validation passed.")
        print()
    print(summarize(snapshot))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
