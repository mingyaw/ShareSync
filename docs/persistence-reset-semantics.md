# Persistence And Reset Semantics

Status: M3 product contract.

This document defines which local ShareSync state survives normal app use, which state is cleared by product controls, and what happens after app deletion.

## iOS Persisted State

| State | Default File | Purpose | Cleared By |
| --- | --- | --- | --- |
| Paired device session | `paired-device-session.json` | Android device trust, pairing token, last known endpoint | Clear Pairing, app deletion |
| Media download/import state | `media-download-state.json` | Queued, downloaded, imported, missing, failed, partial photo state | Reset Local Sync State, app deletion |
| Latest sync result | `latest-sync-result.json` | Last iOS result payload prepared for Android | Reset Local Sync State, app deletion |
| Sync events | `sync-events.json` | Recent local audit/history events | Reset Local Sync State, app deletion |

## Android Persisted State

| State | Default Storage | Purpose | Cleared By |
| --- | --- | --- | --- |
| Device identity | SharedPreferences `share_sync_device_identity` | Stable Android device id/name/public key for QR payloads | App data deletion or uninstall |
| Latest sync result | `latest-sync-result.json` | Last merged iOS result payload received by Android | Clear sync history, app deletion |
| Sync events | `sync-events.json` | Recent Android-side result history | Clear sync history, app deletion |

## Product Controls

### iOS Clear Pairing

Clear Pairing removes only the paired Android device session and endpoint fields. It should not erase downloaded/imported photo records, latest sync result, or sync events.

Use this when:

- Android generated a fresh QR code.
- The paired endpoint points to the wrong Android phone.
- Pairing token/signature validation fails repeatedly.

### iOS Reset Local Sync State

Reset Local Sync State removes iOS local download/import records, latest sync result, and sync events. It should not remove paired-device trust.

Use this when:

- A tester needs to rerun sync from a clean ShareSync state.
- Local sync state appears corrupt.
- Validation needs to prove imported Photos library items remain after ShareSync state is cleared.

### Android Clear Sync History

Clear sync history removes Android latest sync result and sync events. It should not change Android device identity or QR identity.

Use this when:

- A tester wants to rebuild Android manifest filtering from a clean result history.
- Validation needs to confirm iPhone can post a fresh result after Android history is cleared.

## App Deletion Behavior

Deleting the iOS app deletes ShareSync's local pairing, import mapping, latest result, and event history. Photos already imported into iOS Photos remain in the Photos library, but after reinstall ShareSync no longer knows which Android source assets produced them. Those Android photos may become eligible for import again.

Deleting Android app data or uninstalling Android ShareSync deletes the Android device identity and local sync result/event state. The iPhone should treat the next Android install as a new pairing target unless a future durable cross-install identity feature is added.

## M3 Rules

- Never clear local sync state automatically as an error recovery action.
- Never delete Photos library items as part of reset or clear pairing.
- Keep diagnostics explicit: users should be able to tell whether they are clearing pairing, sync state, or Android history.
- Any future bidirectional or delete-sync feature must define a new persistence contract before implementation.
