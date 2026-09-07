# M2 Device Validation Results

Status: Pending physical-device execution.

This file records evidence for the M2 photo-only product reliability milestone. Automated checks can keep code paths stable, but M2 signoff requires physical Android and iPhone validation because Photos permission, iCloud Photos behavior, local network discovery, and app foreground/background handling are OS-controlled.

## Required Device Matrix

| Case | Android Device | Android Version | iPhone Device | iOS Version | Network | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| M2-DM-001 | TBD | TBD | TBD | TBD | Same Wi-Fi | Pending | Baseline local network path |
| M2-DM-002 | TBD | TBD | TBD | TBD | Android hotspot | Pending | Validates travel/no-router path |
| M2-DM-003 | TBD | TBD | TBD | TBD | Same Wi-Fi with Android endpoint change | Pending | Validates discovery or clear endpoint error |

## Validation Cases

### M2-PHOTO-001 Single Photo Import

Purpose: confirm the smallest Android-to-iOS photo path still works.

| Field | Value |
| --- | --- |
| Date | TBD |
| Devices | TBD |
| Network | TBD |
| Android manifest photo count | TBD |
| iOS imported count before test | TBD |
| iOS imported count after test | TBD |
| Android latest result | Pending |
| Pass/Fail | Pending |
| Notes | TBD |

Expected result: one Android photo downloads, imports into the ShareSync Backup album, and Android receives a synced result for that source item.

### M2-PHOTO-002 Sync All Photos

Purpose: confirm foreground all-photo sync reaches a complete state.

| Field | Value |
| --- | --- |
| Date | TBD |
| Devices | TBD |
| Network | TBD |
| Android manifest photo count | TBD |
| iOS final transfer status | Pending |
| Android latest result synced count | TBD |
| Android latest result failed count | TBD |
| Pass/Fail | Pending |
| Notes | TBD |

Expected result: iOS completes or shows only actionable failures, and Android latest sync result matches the iOS final synced/failed counts.

### M2-PHOTO-003 Deleted Imported Photo Retry

Purpose: confirm iOS can detect an imported photo that was later deleted from Photos and make it retryable.

| Field | Value |
| --- | --- |
| Date | TBD |
| Devices | TBD |
| Network | TBD |
| Deleted photo source item | TBD |
| iOS status after manifest refresh | Pending |
| iOS status after resume | Pending |
| Android latest result | Pending |
| Pass/Fail | Pending |
| Notes | TBD |

Expected result: the deleted imported photo moves back into the remaining/retryable set after manifest refresh, then imports again on resume.

### M2-PHOTO-004 Reset Local Sync State

Purpose: confirm validation reset clears ShareSync state without deleting existing Photos library items.

| Field | Value |
| --- | --- |
| Date | TBD |
| Devices | TBD |
| Network | TBD |
| State before reset | TBD |
| State after reset | TBD |
| Photos album preserved | Pending |
| Pass/Fail | Pending |
| Notes | TBD |

Expected result: iOS clears local ShareSync mappings/results/events and can rerun sync, while previously imported Photos remain in the Photos library.

### M2-PHOTO-005 App Restart Pairing And Progress Restore

Purpose: confirm ordinary app restarts keep pairing and durable sync state.

| Field | Value |
| --- | --- |
| Date | TBD |
| Devices | TBD |
| Network | TBD |
| Paired Android restored | Pending |
| Latest sync result restored | Pending |
| Imported/downloaded counts restored | Pending |
| Pass/Fail | Pending |
| Notes | TBD |

Expected result: iOS launches with the last paired Android endpoint/device metadata and restored sync state. If Android's endpoint changed, iOS discovers the paired peer or shows a clear endpoint error without discarding progress.

### M2-PHOTO-006 Foreground/Background Interruption

Purpose: confirm iOS interruption handling matches the M2 foreground limitation.

Checklist: [M2 iOS Foreground/Background Checklist](m2-ios-foreground-background-checklist.md)

| Field | Value |
| --- | --- |
| Date | TBD |
| Devices | TBD |
| Network | TBD |
| Interruption type | Manual cancel / Home / Lock / Endpoint change |
| Imported count before interruption | TBD |
| Imported count after resume | TBD |
| Duplicate imports observed | Pending |
| Android latest result after resume | Pending |
| Pass/Fail | Pending |
| Notes | TBD |

Expected result: leaving the iOS foreground pauses transfer, completed items stay recorded, remaining items can resume, and pairing is not required again for an unchanged paired Android device.

## Signoff Notes

- M2 is photo-only. Do not use video, contacts, file sync, reverse sync, or unattended iOS background behavior as M2 blockers.
- A failed endpoint discovery case can still pass if the app shows a clear recovery path and does not lose progress.
- Any duplicated imported photo after resume is a blocker for M2.
- Any successful iOS sync whose result is not visible on Android is a blocker for M2.
