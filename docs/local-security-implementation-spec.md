# Local Security Implementation Spec

Status: M3 implementation contract.

This document turns the M2 local HTTPS decision into an implementation plan. M3 should prepare the protocol and product behavior first, then switch transport only after both Android and iOS can validate the same QR-pinned certificate contract.

## Security Goals

- Keep ShareSync local-only: no relay service, cloud broker, or third-party storage.
- Protect Android photo metadata and photo bytes from passive local-network observers before broader beta.
- Keep signed requests after HTTPS so pairing still authorizes access and prevents replay.
- Make trust recoverable through visible product actions: scan a fresh QR code, clear pairing, or restart Android sharing.

## Selected Design

M3 uses QR-pinned HTTPS.

Android generates a local self-signed certificate, computes its SHA-256 fingerprint, and includes that fingerprint in the pairing QR payload. iOS stores the fingerprint with the paired Android device and accepts HTTPS connections only when the presented certificate matches the stored fingerprint.

Signed HTTP remains supported during the transition. A pairing payload without `transportSecurity` means the peer is using the current signed local HTTP mode.

## Pairing Payload Extension

The version 1 pairing payload may include:

```json
{
  "transportSecurity": {
    "mode": "qr_pinned_https",
    "certificateFingerprintSha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    "certificateFingerprintEncoding": "hex",
    "certificateNotBefore": "2026-09-08T00:00:00Z",
    "certificateNotAfter": "2027-09-08T00:00:00Z"
  }
}
```

Compatibility rules:

- Missing `transportSecurity`: use signed local HTTP.
- `mode = signed_http`: use signed local HTTP.
- `mode = qr_pinned_https`: use HTTPS plus request signatures.
- iOS must reject unknown modes.
- iOS must show recovery guidance, not silently downgrade, when a paired HTTPS device later presents the wrong certificate.

## Android Responsibilities

Certificate generation:

- Generate one local self-signed certificate per Android app install.
- Store the private key and certificate in Android Keystore where possible.
- The certificate common name should be ShareSync local device identity, not a public DNS name.
- Include IP subject alternative names only when the platform TLS stack requires them for local HTTPS validation.

Certificate persistence:

- Certificate and private key survive normal app restarts.
- Android app data deletion or uninstall creates a new device identity and new certificate.
- Certificate rotation is explicit: stop sharing, generate new certificate, invalidate old QR payloads, and require iOS re-pairing.

Server behavior:

- Keep `/v1/health`, `/v1/manifest`, `/v1/media/{assetId}`, and `/v1/sync-result` behavior unchanged at the API level.
- Serve protected endpoints over HTTPS when `qr_pinned_https` is active.
- Continue validating `X-ShareSync-*` signed request headers.
- Return stable error codes for invalid token, invalid signature, stale timestamp, replay nonce, and certificate-mode mismatch.

## iOS Responsibilities

Pairing storage:

- Store `transportSecurity` with paired-device state.
- Keep legacy pairings valid when `transportSecurity` is missing.
- Clear the stored certificate fingerprint only through Clear Pairing.
- Reset Local Sync State must not remove the pinned certificate.

Connection behavior:

- Use HTTP for missing `transportSecurity` or `signed_http`.
- Use HTTPS for `qr_pinned_https`.
- Pin certificate by exact SHA-256 fingerprint match.
- Do not accept trust-on-first-use for a payload that already carries a certificate fingerprint.
- Do not downgrade a pinned HTTPS pairing to HTTP automatically.

Recovery UX:

- Wrong certificate: tell the user the Android phone may have changed; clear pairing and scan the current Android QR code.
- Expired certificate: restart Android sharing; if still blocked, clear pairing and rescan.
- Network failure before TLS: keep existing endpoint/local-network guidance.
- Invalid request signature after TLS: clear pairing and rescan.

## Implementation Order

1. Extend shared pairing schema and fixtures with optional `transportSecurity`.
2. Add iOS and Android pairing models/tests for optional QR-pinned HTTPS metadata.
3. Add Android certificate provider abstraction with deterministic test fixture support.
4. Persist Android certificate/key material and expose fingerprint to the QR payload factory.
5. Add iOS certificate pinning abstraction with unit tests around fingerprint matching and mismatch recovery.
6. Switch the local server/client transport behind a feature flag or build-time setting.
7. Keep signed request validation enabled and rerun M0/M2 physical validation before marking HTTPS as release-ready.

## M3 Decision

M3 should implement QR-pinned HTTPS before any broader beta, but it should not remove signed local HTTP until:

- existing physical-device photo sync passes over HTTPS,
- wrong-certificate recovery is understandable in both languages,
- Android app reinstall and iOS re-pair behavior are validated,
- and request-signature tests remain green.
