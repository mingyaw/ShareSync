# M5 - Release Candidate Polish

Status: Active after M4 QR-pinned HTTPS readiness completion on 2026-09-11.

Goal: turn the photo-only main axis into a safer release-candidate shape without expanding scope beyond Android-to-iOS photo sync. M5 keeps real-device HTTPS signoff deferred until explicitly requested, but removes implementation rough edges that would make later validation or packaging risky.

## Scope Guardrails

- MVP remains photos only.
- No cloud relay, external server, or third-party storage is introduced.
- iOS still requires foreground user control for sync.
- QR-pinned HTTPS remains opt-in until physical-device signoff is completed.
- Signed request validation must stay active for both HTTP and HTTPS transports.

## Tracks

### M5.1 Transport Mode Release Gate

- [x] Replace source-code HTTPS toggles with an explicit Android build flag.
- [x] Keep signed local HTTP as the default developer/debug mode.
- [x] Document the opt-in QR-pinned HTTPS validation build command.
- [x] Add release-readiness checks that fail if HTTPS is enabled without validation evidence.

### M5.2 Pairing And Device Binding Product Polish

- [ ] Show clearer Android/iOS copy for remembered pairing versus new pairing.
- [ ] Keep IP changes recoverable through discovery, health validation, or QR refresh.
- [ ] Document when a user should re-pair versus retry sync.

### M5.3 Diagnostics And Support Package

- [ ] Add copyable environment summary on Android.
- [ ] Add copyable environment summary on iOS.
- [ ] Redact pairing token and request secrets from copied diagnostics.

### M5.4 Pre-Release Packaging Hygiene

- [ ] Update README status from active M4 to active M5.
- [ ] Add pre-release limitations and validation gates to developer handoff docs.
- [ ] Keep hygiene, Swift tests, Android tests, and M0 gate green.

## Progress Log

### 2026-09-11 M5 Started

Started M5 with the lowest-risk release-gate slice:

- Added an explicit Android Gradle property for QR-pinned HTTPS validation builds.
- Kept default builds on signed local HTTP so staged HTTPS cannot accidentally become the default path before physical-device signoff.
- Added unit coverage for the default transport flag.
- Added a release-readiness check that blocks QR-pinned HTTPS release readiness while M4 physical-device validation remains deferred or pending.
