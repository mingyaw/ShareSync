# iMessage Capture Feasibility

> Product decision update (2026-09-29): the user accepted the non-sandboxed
> distribution tradeoff and requested direct integration into `ShareSyncMac`.
> The separate target described below remains a diagnostic harness; the shipping
> implementation now lives in the unified Mac app with explicit permission UI.

Status: macOS implementation in progress. Read-only incremental access, local
policy evaluation, Telegram Bot forwarding, and constrained reply routing are
integrated in `ShareSyncMac`.

## Telegram Forwarding

`ShareSyncMac` uses Telegram Bot API `sendMessage` as its first production
message destination. The user supplies a BotFather token, destination Chat ID,
and one exact iMessage sender allowlist entry. The token is stored in the macOS
Keychain; the Chat ID and sender setting remain in local preferences.

Forwarding is opt-in and starts from an explicit baseline, so existing Messages
history is not sent. Manual forwarding and a 10-second in-app polling mode share
the same cursor, opaque delivery ledger, sensitive-content policy, rate limiter,
and aggregate audit store. The connector accepts only Telegram's fixed HTTPS
host and rejects HTTP redirects. Attachments are summarized by count and MIME
type in this phase; attachment files are not uploaded.

Telegram-to-iMessage replies are deliberately narrower than forwarding. The
configured Chat ID must be a private chat whose user ID matches the update
sender. The Telegram message must be a native reply to a message previously
forwarded by this ShareSync installation, whose message ID is mapped locally to
the original iMessage handle. ShareSync does not accept recipient names,
addresses, or bot commands from Telegram. Sending is performed by a fixed
AppleScript with recipient and body passed as process arguments, and macOS asks
for Messages Automation permission on first use.

On first enablement, pending bot updates are baselined and ignored. The update
cursor and at most 1,000 reply routes persist locally so the app can resume after
a restart. Reset removes both stores. Reply polling runs only while ShareSync is
running and automatic Telegram polling is enabled, or when the user checks
manually.

## Goal

Determine whether ShareSync can obtain a user's existing iMessage conversations
or observe new iMessage messages on iOS or macOS. This investigation must not
read real message contents, weaken the shipping app sandbox, or add message data
to the photo-sync protocol without a separate privacy and security review.

## Decision Summary

| Platform | Existing iMessage history | New iMessage interception | Product suitability |
| --- | --- | --- | --- |
| iOS | Not available to third-party apps through public APIs | Not available | Do not implement |
| macOS App Store build | No supported Messages history API; the sandbox blocks another app's data | No supported interception API | Do not implement |
| macOS separately distributed diagnostic build | Direct access to local Messages storage may be technically possible after explicit user authorization | Polling local storage may observe changes, but is unsupported and fragile | Research-only, not part of ShareSync MVP |

## iOS Boundary

The Messages framework supports sticker packs and iMessage app extensions that
create app-specific content inside a conversation. It does not expose the user's
conversation history to the containing app or extension.

IdentityLookup message-filter extensions receive only eligible SMS and MMS from
unknown senders. Apple explicitly excludes iMessage from this flow. The filter
extension is also isolated and cannot export message contents to its containing
app.

Consequences:

- ShareSync cannot read existing iMessage conversations on iPhone.
- ShareSync cannot monitor all incoming iMessages in the background.
- An iMessage app extension could send ShareSync-specific content, but cannot be
  used as a general iMessage backup mechanism.
- Screen scraping, notification scraping, private frameworks, jailbreak-only
  access, and undocumented database access are outside product scope.

## macOS Boundary

Apple provides no public API for reading the Messages transcript database. A
normal sandboxed Mac App Store app cannot read another app's protected data
container. ShareSync currently enables App Sandbox and requests only network and
Photos access, so its production target must remain unable to access Messages.

A separately distributed, non-sandboxed research build could ask the user for
highly sensitive file access and attempt read-only access to local Messages
storage. This is not equivalent to a supported API:

- Storage paths and SQLite schemas are private implementation details.
- macOS privacy controls may deny access or require explicit authorization.
- Database changes can break the reader without notice.
- Attachments, edits, reactions, unsent messages, iCloud reconciliation, and
  deleted records require separate semantics.
- Polling a database is not a reliable real-time interception contract.
- Shipping this behavior would require a separate privacy review, distribution
  strategy, threat model, encryption design, and informed consent flow.

Apple Events automation is not a replacement for history access. It introduces
Automation permission and does not provide a stable, complete transcript API.

## Safe Proof-of-Concept Gate

Do not add message access to the current macOS target. If research continues,
create a separate local-only target with a different bundle identifier and all
of the following constraints:

1. Explicit user opt-in before requesting access.
2. Read-only operation against a user-selected test database copy, not the live
   Messages database.
3. Synthetic fixtures for parser development and automated tests.
4. No network transmission, Android transfer, analytics, or logging of message
   bodies.
5. Redacted diagnostics that expose counts and schema versions only.
6. A hard storage boundary separating this experiment from ShareSync photos.
7. No claim of App Store compatibility or real-time interception.

The first PoC should answer only:

- Can a copied database be opened read-only?
- Can conversations, participants, messages, timestamps, attachments, edits,
  and reactions be normalized without exposing content in logs?
- Can incremental changes be detected deterministically from synthetic data?
- What breaks across supported macOS versions?

## Product Recommendation

Keep iMessage outside the ShareSync product roadmap. The only defensible future
option is an explicitly separate macOS archival utility based on user-initiated
imports or a separately consented local diagnostic build. It must not be framed
as cross-platform iMessage interception, and it must not block the photo-sync
release track.

## Primary References

- Apple Developer: Messages framework
  https://developer.apple.com/documentation/messages
- Apple Developer: SMS and MMS Message Filtering
  https://developer.apple.com/documentation/identitylookup/sms-and-mms-message-filtering
- Apple Developer: Protecting user data with App Sandbox
  https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox
- Apple Developer: Accessing files from the macOS App Sandbox
  https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox
