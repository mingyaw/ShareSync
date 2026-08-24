#!/usr/bin/env python3

import json
from datetime import datetime
from pathlib import Path
from typing import Any


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


def resolve_ref(schema: dict[str, Any], ref: str) -> dict[str, Any]:
    if not ref.startswith("#/"):
        raise AssertionError(f"unsupported schema ref: {ref}")

    current: Any = schema
    for part in ref.removeprefix("#/").split("/"):
        if not isinstance(current, dict) or part not in current:
            raise AssertionError(f"schema ref not found: {ref}")
        current = current[part]

    if not isinstance(current, dict):
        raise AssertionError(f"schema ref does not point to an object: {ref}")
    return current


def validate_json_schema(value: Any, node: dict[str, Any], root_schema: dict[str, Any], path: str):
    if "$ref" in node:
        validate_json_schema(value, resolve_ref(root_schema, node["$ref"]), root_schema, path)
        return

    if "type" in node:
        allowed_types = node["type"] if isinstance(node["type"], list) else [node["type"]]
        if not any(matches_json_type(value, allowed_type) for allowed_type in allowed_types):
            raise AssertionError(f"{path} expected type {node['type']}, got {type(value).__name__}")

    if "const" in node and value != node["const"]:
        raise AssertionError(f"{path} expected const {node['const']!r}, got {value!r}")

    if "enum" in node and value not in node["enum"]:
        raise AssertionError(f"{path} expected one of {node['enum']}, got {value!r}")

    if isinstance(value, str):
        if "minLength" in node and len(value) < node["minLength"]:
            raise AssertionError(f"{path} expected minLength {node['minLength']}")
        if node.get("format") == "date-time":
            validate_date_time(value, path)

    if isinstance(value, int) and not isinstance(value, bool):
        if "minimum" in node and value < node["minimum"]:
            raise AssertionError(f"{path} expected minimum {node['minimum']}, got {value}")
        if "maximum" in node and value > node["maximum"]:
            raise AssertionError(f"{path} expected maximum {node['maximum']}, got {value}")

    if isinstance(value, dict):
        required = node.get("required", [])
        for key in required:
            if key not in value:
                raise AssertionError(f"{path}.{key} is required")

        properties = node.get("properties", {})
        if node.get("additionalProperties") is False:
            extras = sorted(set(value) - set(properties))
            if extras:
                raise AssertionError(f"{path} has additional properties: {', '.join(extras)}")

        for key, child in properties.items():
            if key in value:
                validate_json_schema(value[key], child, root_schema, f"{path}.{key}")

    if isinstance(value, list) and "items" in node:
        for index, item in enumerate(value):
            validate_json_schema(item, node["items"], root_schema, f"{path}[{index}]")


def matches_json_type(value: Any, json_type: str) -> bool:
    if json_type == "object":
        return isinstance(value, dict)
    if json_type == "array":
        return isinstance(value, list)
    if json_type == "string":
        return isinstance(value, str)
    if json_type == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if json_type == "number":
        return isinstance(value, int | float) and not isinstance(value, bool)
    if json_type == "boolean":
        return isinstance(value, bool)
    if json_type == "null":
        return value is None
    raise AssertionError(f"unsupported json schema type: {json_type}")


def validate_date_time(value: str, path: str):
    try:
        datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise AssertionError(f"{path} expected RFC3339 date-time, got {value!r}") from error


def validate_fixture_against_schema(fixture_name: str, schema_name: str):
    fixture_path = FIXTURES / fixture_name
    schema_path = SCHEMAS / schema_name
    fixture = load_json(fixture_path)
    schema = load_json(schema_path)
    validate_json_schema(fixture, schema, schema, fixture_name)
    print(f"ok schema validation: {fixture_path.relative_to(ROOT)} -> {schema_path.relative_to(ROOT)}")


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
    validate_fixture_against_schema("sample-pairing-payload.json", "pairing-payload.schema.json")
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

    validate_fixture_against_schema("sample-manifest.json", "manifest.schema.json")
    print("ok fixture: shared/fixtures/sample-manifest.json")


def validate_sync_result():
    result = load_json(FIXTURES / "sample-sync-result.json")
    require_keys(
        "sample-sync-result",
        result,
        ["syncBatchId", "targetDeviceId", "results"],
    )
    assert isinstance(result["results"], list)
    for index, item in enumerate(result["results"]):
        require_keys(
            f"sample-sync-result.results[{index}]",
            item,
            ["itemType", "sourceItemId", "status"],
        )
        assert item["itemType"] in ("media", "contact", "file")
        assert item["status"] in ("synced", "skipped", "failed", "conflicted")

    validate_fixture_against_schema("sample-sync-result.json", "sync-result.schema.json")
    print("ok fixture: shared/fixtures/sample-sync-result.json")


def main():
    validate_schema_files()
    validate_pairing_payload()
    validate_manifest()
    validate_sync_result()


if __name__ == "__main__":
    main()
