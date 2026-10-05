# ShareSync Development Handoff - 2026-10-05

This document closes the current implementation stage and is the starting point
for the next development conversation.

## Product Direction

- Android remains the primary phone and source device.
- `ShareSyncMac` is the main bridge for photos, ShareSync Notes, and Messages.
- Photo and note exchange stays on the local network without a ShareSync cloud
  relay. Telegram is an explicit external destination only for the Messages
  forwarding feature.
- iOS development is paused. Do not expand the iOS feature line until the Mac
  product path is stable.
- Real-device validation was intentionally deferred during this stage.

## Active Branches

### Messages and Telegram bridge

- Branch: `codex/imessage-feasibility`
- Latest functional commit: `f9e8a04 Validate persisted Telegram reply routes`
- This is the current checkout at stage close.
- The unified `ShareSyncMac` app is the product target. `ShareSync Messages
  Bridge.app` remains a diagnostic target.

Implemented product behavior includes:

- opt-in, allowlisted, post-baseline Messages reads;
- Telegram Bot forwarding with Keychain credentials and strict endpoint policy;
- attachment metadata and separately consented JPEG/PNG upload;
- local audit, cursor, rate-limit, and at-most-once delivery state;
- Telegram replies routed back to the original iMessage handle through explicit
  macOS Messages Automation permission;
- private-chat ownership checks and reply-to-forwarded-message enforcement;
- distinct sender display labels and reply recipient handles;
- strict Telegram delivery receipts, response validation, rate-limit handling,
  cursor monotonicity, and persisted reply-route validation.

Latest verification:

- `swift test`: 260 tests passed, 0 failed.
- `ShareSyncMac` Debug macOS build: succeeded with code signing disabled.
- `ShareSyncMessagesBridge` Debug macOS build: succeeded with code signing
  disabled.

### Bidirectional ShareSync Notes

- Branch: `codex/notes-sync`
- Latest functional commit: `d2c5c26 Return stable note storage errors`
- This branch is independently pushed and clean.

Implemented product behavior includes:

- ShareSync-owned versioned notes on Android and macOS;
- create, edit, tag, search, and tombstone deletion on both platforms;
- signed `GET /v1/notes` and `POST /v1/notes` local-network exchange;
- deterministic bidirectional merge, idempotency, and visible conflict copies;
- manual Mac sync plus automatic note sync after eligible photo sync runs;
- atomic local storage and persisted sync receipts on both platforms;
- receipt invalidation after local edits;
- paired Android device identity validation before Mac merge;
- 8 MiB snapshot bounds and stable `SS-NOTES-503` storage failures.

Latest verification on the Notes branch:

- Swift package tests: 140 passed, 0 failed.
- Android `:app:testDebugUnitTest`: passed.
- `ShareSyncMac` Debug macOS build: succeeded with code signing disabled.

## Important Boundaries

- ShareSync Notes currently persist in each app's local storage. They do not yet
  integrate with Apple Notes, Google Keep, or iCloud Drive.
- Telegram Bot traffic leaves the local network by explicit user choice. Photo
  and note payloads do not use Telegram.
- Message bodies and source identifiers must not be added to logs or analytics.
- Telegram reset must continue to remove credentials, cursors, reply routes,
  delivery state, and redacted audit state.
- Preserve Git author identity as `HansLi <mingyaw1229@gmail.com>`.
- Do not run physical-device tests unless the user re-enables them.

## Branch Integration Warning

The two feature branches share merge base
`c1fd0fdf8c06e4b95f75d6a6f98c6d2fbd2b03a4` but have developed independently.
At stage close, Messages has 60 branch-only commits and Notes has 16 branch-only
commits. Do not merge one feature branch directly into the other without first
reviewing overlapping Mac project, app model, navigation, localization, and
package changes.

Use a dedicated integration branch or worktree. Merge one branch, resolve and
test, then merge the other. Keep both source branches intact until the integrated
Mac app and Android build pass their full automated suites.

## Recommended Next Stage

1. Create a dedicated integration branch from the intended product baseline.
2. Integrate Messages and Notes into one `ShareSyncMac` build, resolving shared
   project and UI files deliberately.
3. Run Swift, Android, both macOS target builds, and shared fixture validation.
4. Perform the deferred physical validation matrix for Messages permissions,
   Telegram forwarding/replies, Android-to-Mac notes, Mac-to-Android notes,
   concurrent conflicts, and deletion propagation.
5. Decide the Notes backup target: retain app-local storage or add user-visible
   Markdown in iCloud Drive. Do not imply iCloud backup until that decision is
   implemented and verified.
6. Define per-peer deletion acknowledgements before compacting tombstones.
7. Complete Developer ID signing, hardened-runtime review, notarization, and
   clean-account permission acceptance before distribution.

## Suggested New Conversation Prompt

> Continue ShareSync from `docs/development-handoff-2026-10-05.md`. Inspect the
> current Git branches and remote heads before editing. Preserve the Android
> primary-phone and ShareSyncMac bridge architecture, keep iOS paused, do not run
> physical-device tests without renewed approval, and preserve author identity
> `HansLi <mingyaw1229@gmail.com>`.
