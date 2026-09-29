# ShareSync Mac Bridge Product Roadmap

Status: Product requirements and branch plan as of 2026-09-29.

## Product Background

ShareSync serves an Android-first user whose daily work environment and long-term
data storage remain centered on macOS and iCloud. The product does not try to
turn Android into an iPhone or operate a ShareSync cloud relay. It uses the Mac
as a local bridge between the user's primary Android phone and selected Apple
ecosystem services.

Platform roles:

- Android is the primary phone and the main source of photos and ShareSync notes.
- macOS is the always-available local bridge, automation host, and conflict UI.
- iCloud provides Apple-owned Photos, document, and calendar synchronization.
- iOS photo receiving remains available but is paused as an active development
  line and is not required for the Mac-centered workflows.

## Product Principles

- Prefer direct local-network transfer between Android and Mac.
- Do not add a ShareSync-operated cloud relay.
- Request sensitive Mac permissions only for the feature that needs them.
- Keep the existing sandboxed photo gateway isolated from Messages access.
- Make every external forwarding destination explicit to the user.
- Use durable device identity, signed requests, versioned ledgers, tombstones,
  and idempotency keys for cross-device state.
- Do not promise execution while the Mac is shut down, logged out, or asleep.

## Branch Map

| Major function | Branch | Purpose |
| --- | --- | --- |
| Android photo to iCloud Photos | `codex/mac-gateway` | Existing photo gateway and reliability closure |
| iMessage forwarding | `codex/imessage-feasibility` | Permission, fidelity, rules, and connector feasibility |
| Bidirectional notes | `codex/notes-sync` | ShareSync-owned note model and Android/Mac synchronization |
| Bidirectional calendar | `codex/calendar-sync` | Android/Mac EventKit synchronization through a dedicated calendar |

An integration branch should be created only after at least one new feature
passes its own acceptance gate. It will own shared navigation, the permission
center, activity history, login-item behavior, and release packaging.

## Photo Gateway

### Implemented

- Mac-generated QR pairing completed by Android over the local network.
- Device-scoped credentials, signed requests, revocation, and gateway ownership.
- Bonjour endpoint rediscovery when the Android address changes.
- Paged photo manifests, sequential transfer, resume, validation, and PhotoKit
  import into the ShareSync Backup album.
- Duplicate prevention, Photos deletion reconciliation, completion return, and
  retry state.
- Sync-all, cancellation, recent history, menu-bar actions, and awake-session
  scheduling.

### Remaining

- Launch-at-login support using supported macOS APIs.
- Sleep/wake and network-change recovery.
- Long-running reliability and large-library physical-device validation.
- QR-pinned HTTPS physical-device signoff and certificate lifecycle validation.
- Mac-specific unit and UI test targets.
- App icon, privacy manifest, Beta/Release channels, signing, notarization, and
  packaging.
- Permission, low-storage, Android-offline, and Photos failure recovery UX.
- Final validation that imported Photos appear through iCloud on another Apple
  device.

### Acceptance Gate

The Mac can run for 72 hours while awake, recover from Android and Wi-Fi address
changes, import without duplicates, return completion state, and resume after an
interruption without requiring a new pairing.

## iMessage Forwarding

### Confirmed

- The Mac already receives iMessage through Apple Messages.
- The local Messages database exists but macOS denies ordinary process access.
- There is no public API for reading a complete Messages transcript.
- iOS is not required for the proposed Mac forwarding workflow.

### Remaining

- Build a separately permissioned Messages Bridge helper without expanding the
  photo gateway's sandbox privileges.
- Add explicit other-app-data permission onboarding and revocation handling.
- Inspect schema only before reading any controlled test message.
- Verify text, Unicode, group, reply, edit, retract, reaction, attachment
  metadata, sleep catch-up, and deduplication behavior on supported macOS
  versions.
- Establish a baseline cursor so existing history is not forwarded when the
  feature is enabled.
- Normalize new-message events without logging message bodies.
- Add sender and conversation allowlists, sensitive-message blocking, schedules,
  preview mode, pause, rate limits, and loop prevention.
- Implement a local fake connector before adding one official bot or webhook API.
- Store connector credentials in Keychain and use idempotency keys for retries.
- Define the separately distributed Developer ID and notarization strategy.

### Acceptance Gate

A user-created controlled test message is detected once, normalized correctly,
filtered by a local rule, and delivered once to a fake connector. Existing
history and unrelated conversations are never emitted.

## Bidirectional Notes

### Scope

The first release synchronizes ShareSync-owned notes. It does not read or modify
the private Apple Notes, Google Keep, or vendor Notes databases. Notes may be
exported to those apps through user-initiated sharing later.

### Remaining

- Define a versioned note model with ID, title, Markdown body, timestamps, tags,
  revision, device ID, and deletion tombstone.
- Add Android storage, editor, search, and local change tracking.
- Add Mac storage, editor, search, and local change tracking.
- Reuse local pairing and signed transport with note-specific authorization.
- Implement pull, push, acknowledgement, retry, and idempotent merge behavior.
- Define concurrent-edit handling and visible conflict copies.
- Decide between user-visible Markdown files in iCloud Drive and structured data
  in the ShareSync iCloud container; iCloud Drive Markdown is the preferred
  first milestone.
- Add optional manual import/export without promising native Notes integration.
- Define attachment limits only after text synchronization is stable.

### Acceptance Gate

A note created offline on Android appears on Mac, a Mac edit returns to Android,
simultaneous edits create a visible conflict instead of silent data loss, and a
deletion propagates once through an explicit tombstone policy.

## Bidirectional Calendar

### Scope

The first release uses a dedicated ShareSync calendar. The Mac accesses Calendar
through EventKit with explicit user permission. It does not modify arbitrary
personal or work calendars by default.

### Remaining

- Define a versioned event model with stable ID, title, notes, location, start,
  end, all-day state, time zone, recurrence, alarms, revision, and tombstone.
- Add Android Calendar Provider integration or a ShareSync-owned calendar store.
- Add Mac EventKit permission, dedicated-calendar creation, and event mapping.
- Persist Android, ShareSync, and EventKit identifiers without relying on titles.
- Implement bidirectional incremental changes, acknowledgements, and loop
  prevention.
- Handle time-zone changes, daylight-saving transitions, recurrence, exceptions,
  and offline edits.
- Define conflict and deletion behavior before enabling automatic propagation.
- Exclude invitations, attendee responses, organizer changes, and cross-account
  moves from the first milestone.

### Acceptance Gate

An event created on Android appears in the dedicated iCloud calendar through the
Mac, a Mac edit returns to Android, recurring events retain correct local times,
and retries do not create duplicate events.

## Shared Mac Platform Work

The integration line must eventually provide:

- One overview for Photos, Messages, Notes, and Calendar health.
- Per-feature permission isolation and clear explanations.
- A shared device list without sharing feature permissions accidentally.
- Per-feature request-signing scope and revocation.
- A versioned activity ledger with redacted diagnostics.
- Keychain-backed secrets and encrypted pending queues where content is retained.
- Launch-at-login, sleep/wake recovery, network recovery, pause, and safe shutdown.
- Traditional Chinese and English localization, accessibility, and adaptive UI.
- Developer ID signing, hardened runtime, notarization, migration, and uninstall
  behavior.

## Delivery Order

1. Close photo gateway reliability and distribution gaps.
2. Complete the iMessage controlled-message feasibility gate.
3. Implement one message forwarding connector only after that gate passes.
4. Build text-only bidirectional ShareSync Notes.
5. Build dedicated-calendar bidirectional synchronization.
6. Create the integration branch and unify navigation, permissions, activity,
   lifecycle, and packaging.

Notes and Calendar must not be implemented on the iMessage branch. The iMessage
helper must not be merged into the photo gateway until its permission boundary
and distribution strategy are accepted.
