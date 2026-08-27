#!/usr/bin/env python3

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RESULTS_FILE = ROOT / "docs" / "m0-validation-results.md"
ALLOWED_STATUSES = {"Not Run", "Pass", "Fail", "Blocked", "Needs Retest"}
REQUIRED_GATE_SCENARIOS = {
    "Baseline one-photo sync",
    "Foreground full manifest transfer",
    "Repeat sync without duplicates",
    "Deleted imported photo retry",
    "iOS app restart after pairing",
    "Stale iOS pairing reset",
    "Manual stop and retry",
    "Network interruption retry",
    "Same Wi-Fi transport",
    "Android hotspot transport",
    "iPhone lock or app background during transfer",
    "Photos permission denied",
}


def extract_summary_rows(markdown: str) -> dict[str, str]:
    rows: dict[str, str] = {}
    in_summary = False

    for raw_line in markdown.splitlines():
        line = raw_line.strip()
        if line == "## Current Summary":
            in_summary = True
            continue
        if in_summary and line.startswith("## "):
            break
        if not in_summary or not line.startswith("|"):
            continue
        if line.startswith("| Scenario ") or line.startswith("| ---"):
            continue

        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) < 2:
            raise AssertionError(f"invalid summary row: {line}")
        scenario, status = cells[0], cells[1]
        if status not in ALLOWED_STATUSES:
            raise AssertionError(f"{scenario}: unsupported status {status!r}")
        rows[scenario] = status

    return rows


def extract_gate_scenarios(markdown: str) -> set[str]:
    scenarios: set[str] = set()
    in_gate = False

    for raw_line in markdown.splitlines():
        line = raw_line.strip()
        if line == "## M0 Completion Gate":
            in_gate = True
            continue
        if in_gate and line.startswith("## "):
            break
        if in_gate and line.startswith("- "):
            scenarios.add(line.removeprefix("- ").rstrip("."))

    return scenarios


def main():
    markdown = RESULTS_FILE.read_text(encoding="utf-8")
    summary_rows = extract_summary_rows(markdown)
    gate_scenarios = extract_gate_scenarios(markdown)

    missing_rows = sorted(REQUIRED_GATE_SCENARIOS - set(summary_rows))
    if missing_rows:
        raise AssertionError(f"missing summary rows: {', '.join(missing_rows)}")

    missing_gate = sorted(REQUIRED_GATE_SCENARIOS - gate_scenarios)
    if missing_gate:
        raise AssertionError(f"missing completion gate scenarios: {', '.join(missing_gate)}")

    print("ok m0 validation results")


if __name__ == "__main__":
    main()
