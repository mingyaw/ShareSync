# Messages Bridge Release Boundary

Status: distribution requirements for Messages inside the unified Mac app.

## Unified Product

`ShareSyncMac` contains both the Android photo bridge and the Messages feature.
The Messages page performs permission onboarding, controlled validation, and
local forwarding preview directly in the main app. Because macOS protects the
Messages database outside the app container, the unified product is intentionally
non-sandboxed.

The main app must keep a stable release bundle identifier and signing requirement.
Changing either can make macOS treat an update as a different app and require the
user to review permission again.

`ShareSync Messages Bridge.app` remains a diagnostic target for development and
schema troubleshooting. It is not the shipping product path and must not be
installed alongside the release app during permission acceptance testing.

## Permission Contract

- The app explains Messages access before opening System Settings.
- A compatibility check reads schema metadata only.
- Message rows are read only after the user creates a baseline.
- Existing history before that baseline is excluded.
- Local validation and preview do not send network requests.
- Permission loss closes validation and preview until access is restored.
- Reset removes the selected workflow's local cursor and redacted state.
- Telegram-to-iMessage sending requires a separate, explicit opt-in and macOS
  Automation permission for Messages. Incoming Telegram text is accepted only
  as a reply to a locally mapped forwarded message from the configured private
  chat owner; Telegram cannot provide an arbitrary recipient.

The app never attempts to automate System Settings or grant permission itself.

## Signing And Notarization

Release acceptance requires all of the following:

1. Archive `ShareSyncMac` with a Developer ID Application identity and hardened runtime.
2. Verify that the app has only the local-network, Photos, and explicitly reviewed Messages-related access required by its features.
3. Confirm `PrivacyInfo.xcprivacy` is present in the signed app bundle.
4. Submit the archive to Apple's notary service and staple the accepted ticket.
5. Verify the stapled artifact on a clean supported macOS account.
6. Confirm an update signed by the same requirement retains the expected permission behavior.

Do not distribute an ad-hoc-signed feasibility build as a production artifact.

## Connector Gate

The Telegram Bot connector is the first reviewed external destination. Its
release and any later connector must satisfy all of the following:

- credentials must be stored through `MessageConnectorCredentialVault`; the
  production Mac implementation uses a device-only macOS Keychain item;
- the connector must accept only `MessageConnectorEnvelope`;
- endpoints must use the exact Telegram HTTPS host; the current transport rejects
  every HTTP redirect rather than forwarding message content to another URL;
- TLS validation must use system trust;
- the opaque delivery key must be used for idempotency where supported;
- network failures must preserve the message cursor;
- logs and analytics must remain free of bodies and source identifiers;
- the privacy manifest and permission copy must be reviewed again.
- reverse-message routes and the Telegram update cursor must remain local and be
  deleted by Telegram reset;
- AppleScript source must remain fixed, with recipient and body passed as
  arguments rather than interpolated into executable script text.
- Attachment metadata and binary image upload use separate opt-ins. Binary
  upload is limited to JPEG/PNG, requires the current versioned consent, and is
  governed by `message-attachment-privacy.md`; it remains a physical-validation
  release gate.
