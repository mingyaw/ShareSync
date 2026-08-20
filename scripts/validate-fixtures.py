#!/usr/bin/env python3

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCHEMAS = ROOT / "shared" / "schemas"
FIXTURES = ROOT / "shared" / "fixtures"


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def require_keys(name: str, value: dict, keys: list[str]):
    missing = [key for key in keys if key not in value]
    if missing:
        raise AssertionError(f"{name} missing keys: {', '.join(missing)}")


def validate_schema_files():
    for path in sorted(SCHEMAS.glob("*.json")):
        load_json(path)
        print(f"ok schema json: {path.relative_to(ROOT)}")


def validate_pairing_payload():
    payload = load_json(FIXTURES / "sample-pairing-payload.json")
    require_keys(
        "sample-pairing-payload",
        payload,
        [
            "version",
            "type",
            "deviceId",
            "deviceName",
            "platform",
            "publicKey",
            "ip",
            "port",
            "pairingToken",
            "expiresAt",
        ],
    )
    assert payload["version"] == 1
    assert payload["type"] == "sharesync_pairing"
    assert payload["platform"] == "android"
    assert isinstance(payload["port"], int)
    print("ok fixture: shared/fixtures/sample-pairing-payload.json")


def validate_manifest():
    manifest = load_json(FIXTURES / "sample-manifest.json")
    require_keys(
        "sample-manifest",
        manifest,
        ["version", "sourceDeviceId", "generatedAt", "cursor", "media", "contacts", "files"],
    )
    assert manifest["version"] == 1
    assert isinstance(manifest["media"], list)
    assert isinstance(manifest["contacts"], list)
    assert isinstance(manifest["files"], list)

    for index, asset in enumerate(manifest["media"]):
        require_keys(
            f"sample-manifest.media[{index}]",
            asset,
            ["assetId", "sourceDeviceId", "mediaType", "fileName", "mimeType", "size"],
        )
        assert asset["mediaType"] in ("photo", "video")
        assert isinstance(asset["size"], int)
        assert asset["size"] >= 0

    print("ok fixture: shared/fixtures/sample-manifest.json")


def main():
    validate_schema_files()
    validate_pairing_payload()
    validate_manifest()


if __name__ == "__main__":
    main()

