#!/usr/bin/env python3

import argparse
import json
from pathlib import Path
from typing import Any


ALLOWED_ITEM_TYPES = {"media", "contact", "file"}
ALLOWED_STATUSES = {"synced", "skipped", "failed", "conflicted"}


def load_sync_result(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)

    validate_sync_result(value, path)
    return value


def validate_sync_result(value: Any, path: Path):
    if not isinstance(value, dict):
        raise AssertionError(f"{path}: root must be an object")

    required = {"syncBatchId", "targetDeviceId", "results"}
    missing = sorted(required - set(value))
    if missing:
        raise AssertionError(f"{path}: missing keys: {', '.join(missing)}")

    extra = sorted(set(value) - required)
    if extra:
        raise AssertionError(f"{path}: unexpected keys: {', '.join(extra)}")

    if not isinstance(value["syncBatchId"], str):
        raise AssertionError(f"{path}: syncBatchId must be a string")
    if not isinstance(value["targetDeviceId"], str):
        raise AssertionError(f"{path}: targetDeviceId must be a string")
    if not isinstance(value["results"], list):
        raise AssertionError(f"{path}: results must be an array")

    for index, item in enumerate(value["results"]):
        validate_sync_item(item, path, index)


def validate_sync_item(item: Any, path: Path, index: int):
    if not isinstance(item, dict):
        raise AssertionError(f"{path}: results[{index}] must be an object")

    required = {"itemType", "sourceItemId", "status"}
    allowed = required | {"targetItemId", "errorCode"}
    missing = sorted(required - set(item))
    if missing:
        raise AssertionError(f"{path}: results[{index}] missing keys: {', '.join(missing)}")

    extra = sorted(set(item) - allowed)
    if extra:
        raise AssertionError(f"{path}: results[{index}] unexpected keys: {', '.join(extra)}")

    if item["itemType"] not in ALLOWED_ITEM_TYPES:
        raise AssertionError(f"{path}: results[{index}].itemType is not supported")
    if not isinstance(item["sourceItemId"], str):
        raise AssertionError(f"{path}: results[{index}].sourceItemId must be a string")
    if item["status"] not in ALLOWED_STATUSES:
        raise AssertionError(f"{path}: results[{index}].status is not supported")

    target_item_id = item.get("targetItemId")
    if target_item_id is not None and not isinstance(target_item_id, str):
        raise AssertionError(f"{path}: results[{index}].targetItemId must be a string or null")

    error_code = item.get("errorCode")
    if error_code is not None and not isinstance(error_code, str):
        raise AssertionError(f"{path}: results[{index}].errorCode must be a string or null")


def canonical(value: dict[str, Any]) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def main():
    parser = argparse.ArgumentParser(
        description="Compare iOS and Android copied ShareSync sync result JSON."
    )
    parser.add_argument("left", type=Path, help="First sync result JSON file")
    parser.add_argument("right", type=Path, help="Second sync result JSON file")
    args = parser.parse_args()

    left = load_sync_result(args.left)
    right = load_sync_result(args.right)

    if canonical(left) != canonical(right):
        raise SystemExit("sync results differ")

    print("ok sync results match")


if __name__ == "__main__":
    main()
