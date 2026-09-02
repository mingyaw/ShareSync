# M0 Validation Results

Use this file to record real-device M0 validation runs. Keep one row per scenario so M0 completion is based on repeatable evidence instead of memory.

Status values:

- `Not Run`: not tested on real devices yet.
- `Pass`: expected result was confirmed.
- `Fail`: expected result was not met.
- `Blocked`: could not complete because of setup, device, permission, or build issues.
- `Needs Retest`: previously tested, but code changed enough that the scenario should be rerun.

## Current Summary

| Scenario | Status | Last Run | Devices | Network | Notes |
| --- | --- | --- | --- | --- | --- |
| Baseline one-photo sync | Pass | 2026-09-02 | User real devices | Local | Completed by user report; detailed device names not recorded. |
| Foreground full manifest transfer | Pass | 2026-09-02 | User real devices | Local | Completed by user report; detailed device names not recorded. |
| Repeat sync without duplicates | Pass | 2026-09-02 | User real devices | Local | Completed by user report; detailed device names not recorded. |
| Deleted imported photo retry | Pass | 2026-09-02 | User real devices | Local | Completed by user report; detailed device names not recorded. |
| iOS app restart after pairing | Pass | 2026-09-02 | User real devices | Local | Completed by user report; detailed device names not recorded. |
| Stale iOS pairing reset | Pass | 2026-09-02 | User real devices | Local | Completed by user report; detailed device names not recorded. |
| App restart resume | Pass | 2026-09-02 | User real devices | Local | Completed by user report; detailed device names not recorded. |
| Manual stop and retry | Pass | 2026-09-02 | User real devices | Local | Completed by user report; detailed device names not recorded. |
| Network interruption retry | Pass | 2026-09-02 | User real devices | Local | Completed by user report; detailed device names not recorded. |
| Invalid range response handling | Pass | 2026-09-02 | User real devices | Local | Completed by user report; detailed device names not recorded. |
| Same Wi-Fi transport | Pass | 2026-09-02 | User real devices | Same Wi-Fi | Completed by user report; detailed device names not recorded. |
| Android hotspot transport | Pass | 2026-09-02 | User real devices | Android hotspot | Completed by user report; detailed device names not recorded. |
| iPhone lock or app background during transfer | Pass | 2026-09-02 | User real devices | Local | Completed by user report; detailed device names not recorded. |
| Android app background during transfer | Pass | 2026-09-02 | User real devices | Local | Completed by user report; detailed device names not recorded. |
| Photos permission denied | Pass | 2026-09-02 | User real devices | Local | Completed by user report; detailed device names not recorded. |
| Camera permission denied | Pass | 2026-09-02 | User real devices | Local | Completed by user report; detailed device names not recorded. |
| Low iPhone storage | Pass | 2026-09-02 | User real devices | Local | Completed by user report; detailed device names not recorded. |

## Run Log

Add newest entries at the top.

### 2026-09-02 User-Reported Matrix Completion

```text
Date: 2026-09-02
Android device / OS: User real device, details not recorded
iPhone / iOS: User real device, details not recorded
Network: Same Wi-Fi and Android hotspot scenarios reported complete
Builds: Current M0 builds
Scenarios: Full M0 real-device matrix
Result: Pass by user report
Blocking issues: None reported
Notes: User reported the real-device test matrix is complete. Exact device model, OS versions, build numbers, and copied sync result JSON can be appended in a later evidence refinement pass.
Sync result JSON: Not captured in this summary entry
```

### Template

```text
Date:
Android device / OS:
iPhone / iOS:
Network:
Builds:
Scenarios:
Result:
Blocking issues:
Notes:
Sync result JSON:
```

## M0 Completion Gate

M0 can be called complete when these scenarios are `Pass` on real devices:

- Baseline one-photo sync.
- Foreground full manifest transfer.
- Repeat sync without duplicates.
- Deleted imported photo retry.
- iOS app restart after pairing.
- Stale iOS pairing reset.
- Manual stop and retry.
- Network interruption retry.
- Same Wi-Fi transport.
- Android hotspot transport.
- iPhone lock or app background during transfer.
- Photos permission denied.

Known M0 limitations may remain documented if they do not break the core local photo sync goal.
