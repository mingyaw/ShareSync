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
| Baseline one-photo sync | Not Run | - | - | - | Pair, fetch manifest, download one item, confirm Photos import and Android sync result. |
| Foreground full manifest transfer | Not Run | - | - | - | Run `Download Remaining` with both apps foregrounded. |
| Repeat sync without duplicates | Not Run | - | - | - | Fetch/download again after successful import; confirm previously imported photos are skipped. |
| Deleted imported photo retry | Not Run | - | - | - | Delete imported iOS Photos item, fetch again, confirm it becomes retryable. |
| iOS app restart after pairing | Not Run | - | - | - | Confirm paired Android endpoint/token restore while Android server session is still valid. |
| Stale iOS pairing reset | Not Run | - | - | - | Restart Android server, clear iOS pairing, scan fresh QR, fetch manifest. |
| App restart resume | Not Run | - | - | - | Restart iOS after download/import boundary; confirm no duplicate import. |
| Manual stop and retry | Not Run | - | - | - | Stop active transfer, fetch again, retry remaining items. |
| Network interruption retry | Not Run | - | - | - | Interrupt Wi-Fi/hotspot during transfer, reconnect, retry. |
| Invalid range response handling | Not Run | - | - | - | Development API validation for `416` and iOS partial validation path. |
| Same Wi-Fi transport | Not Run | - | - | - | Both devices on same LAN. |
| Android hotspot transport | Not Run | - | - | - | iPhone connected to Android hotspot. |
| iPhone lock or app background during transfer | Not Run | - | - | - | Confirm foreground-only pause and retry path. |
| Android app background during transfer | Not Run | - | - | - | Confirm current M0 limitation or device-specific behavior. |
| Photos permission denied | Not Run | - | - | - | Confirm permission error appears before transfer work. |
| Camera permission denied | Not Run | - | - | - | Confirm manual payload fallback remains usable. |
| Low iPhone storage | Not Run | - | - | - | Confirm `SS-STORE-001` and Android failed result report. |

## Run Log

Add newest entries at the top.

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
