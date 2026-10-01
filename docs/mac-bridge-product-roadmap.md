# ShareSync Mac Bridge Product Roadmap

Status: Product requirements and branch plan as of 2026-10-01.

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
- Keep Messages access explicit and feature-scoped inside the unified Mac app;
  the product accepts that direct Messages access makes the Mac app non-sandboxed.
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

- Validate launch-at-login registration and approval in a signed installed build.
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

### Implemented on the feasibility branch

- `ShareSyncMac` now contains Photos and Messages as first-class sidebar
  destinations. The Messages core, permission UI, validation, and preview are
  compiled directly into the main target.
- The unified app performs a schema-only compatibility check before message-row access
  and provides explicit permission onboarding in Traditional Chinese and English.
- A durable baseline cursor excludes existing message history and survives restart.
- Controlled validation reads only rows newer than the baseline and reports
  aggregate field availability without displaying or logging bodies or senders.
- Failed validation does not advance the cursor, while successful validation does.
- New-message events normalize into a connector-neutral model with an opaque,
  stable delivery key and Apple timestamp conversion.
- The forwarding pipeline fails closed on sender and service allowlists, blocks
  outgoing and associated events by default, and retries safely through an
  idempotent in-memory connector.
- Conversation identifiers are collected only when the installed Messages
  schema supports them, allowing an optional conversation allowlist to prevent
  an approved sender from matching unrelated chats.
- Pause and local-time schedules stop before reading rows, preserving queued
  messages and the durable cursor until forwarding is allowed again.
- User-defined sensitive terms and likely one-time verification codes are
  blocked locally, with typed denial reasons ready for product UI diagnostics.
- A versioned, content-free delivery ledger records only opaque delivery keys
  and pending/delivered state. Restarts retry pending work with the same key and
  skip confirmed deliveries before contacting a connector.
- A sliding-window rate limiter stops the batch without advancing its cursor,
  allowing later retry instead of silently dropping excess messages.
- A bounded, versioned audit history stores only batch counts, typed outcomes,
  and aggregate denial reasons. It deliberately excludes message bodies,
  sender identifiers, conversation identifiers, and source message IDs.
- Optional attachment joins expose only attachment count and MIME types for
  fidelity decisions. The reader does not access attachment files, paths, or
  filenames.
- Rich text uses an allowlisted secure Foundation attributed-string decoder.
  Unknown private archive formats fail closed and are never decoded through
  private APIs or unrestricted object deserialization.
- The connector boundary receives a minimized envelope instead of the internal
  event. Raw message GUIDs, row IDs, sender accounts, conversation identifiers,
  and associated-message IDs cannot be passed to a connector; optional sender
  labels require an explicit local alias mapping.
- The Messages page offers a separate-baseline forwarding preview. An exact
  sender allowlist is kept only in the running app session; new rows are checked
  through the real policy and delivery pipeline, while only aggregate counts
  and the redacted audit are retained and nothing leaves the Mac.
- Validation and preview state have separate destructive reset actions. Preview
  reset deletes its cursor, delivery ledger, audit counts, and in-memory sender;
  access loss also closes both workflows until permission is restored.
- A testable polling planner now distinguishes idle intervals, immediate
  continuation for full batches, bounded exponential failure backoff, explicit
  rate-limit delays, and immediate wake/network recovery without touching the
  message cursor.
- The main app bundle includes a no-collection privacy manifest and Messages
  usage description. Its release boundary documents non-sandboxed signing,
  notarization, permission, and future connector requirements.
- Connector credentials now have an isolated vault contract and a production
  macOS Keychain implementation using device-only accessibility. No credential
  is stored in cursors, delivery state, audit history, or app preferences.
- Telegram Bot API is the first external connector. It sends JSON only to the
  fixed `https://api.telegram.org` host, rejects redirects, stores its token in
  Keychain, and preserves the cursor when delivery fails.
- Telegram setup, test delivery, explicit baseline, manual forwarding, and
  opt-in polling while the Mac app runs are available in the unified Messages UI.
- Telegram replies can be sent back through Messages only when the Telegram
  account and private Chat ID match and the user replies to a ShareSync-forwarded
  message with a locally stored route. First use requires explicit Messages
  Automation approval.
- The unified app now owns Messages polling for the process lifetime. Explicit
  automatic-forwarding and reply opt-ins resume after launch and continue when
  the window closes while ShareSync remains in the menu bar.
- The unified app can register itself as a supported macOS login item and links
  directly to Login Items when system approval is required.
- Message automation immediately checks for pending work after the Mac wakes or
  network connectivity returns instead of waiting for the next polling interval.
- Telegram forwarding accepts a persisted multi-sender allowlist. Existing
  single-sender settings migrate automatically and removing the final sender
  disables automatic forwarding.

### Remaining

- Complete physical-Mac permission, revocation, and controlled-message validation.
- Verify text, Unicode, group, reply, edit, retract, reaction, attachment
  metadata, sleep catch-up, and deduplication behavior on supported macOS
  versions.
- Add optional conversation rules, schedules, pause controls, and loop prevention.
- Add attachment upload only after explicit media privacy and size-limit design.
- Validate login-item enable, disable, approval, sleep catch-up, and network
  recovery behavior in a signed installed build.
- Validate Telegram reply routing and Messages Automation permission on a
  physical Mac, including denied/revoked permission and an unavailable iMessage
  participant.
- Verify duplicate behavior for the narrow case where Telegram accepts a request
  but the response is lost; Bot API `sendMessage` has no idempotency-key field.
- Complete Developer ID signing and notarization for the unified non-sandboxed app.

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

Notes and Calendar must not be implemented on the iMessage branch. The former
standalone Messages target remains available only as a diagnostic harness; the
shipping product path is the unified `ShareSyncMac` target.
