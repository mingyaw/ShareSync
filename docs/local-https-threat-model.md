# Local HTTPS Threat Model

Status: M2 decision record. Implementation remains signed local HTTP until a dedicated M3 security milestone or pre-release hardening branch.

## Current M2 Transport

ShareSync M2 uses same-network local HTTP plus signed protected requests:

- iOS pairs by scanning Android's QR payload.
- The pairing token acts as the current HMAC shared secret.
- Protected local requests include device id, session id, timestamp, nonce, request body hash, and signature.
- Android validates signatures and rejects stale or replayed requests within the active local server session.

This is acceptable for M2 developer validation because the product is still photo-only, physical-device tested, and not distributed as a broader beta.

## Assets To Protect

- Android photo metadata in the manifest.
- Android photo bytes served by `/v1/media/{assetId}`.
- iOS import result history posted back to Android.
- Pairing token and trusted device metadata.
- Local endpoint information: Android IP, port, and advertised Bonjour service.

## In-Scope Threats

| Threat | M2 Mitigation | Remaining Risk |
| --- | --- | --- |
| Unknown local device fetches manifest/media | Signed protected requests after QR pairing | QR token compromise would allow access until pairing/session changes |
| Replay of captured request | Timestamp and nonce validation | Nonce memory is process-local unless persisted |
| Android IP changes after pairing | Bonjour discovery plus health device-id validation | Networks without mDNS require saved endpoint or QR refresh |
| Unexpected Android device at saved endpoint | iOS verifies `/v1/health` device id against paired device | Health itself is not encrypted in M2 |
| Passive local network sniffing | None at transport layer in M2 | Photo bytes and metadata can be observed by a network attacker |
| Active man-in-the-middle | Request signatures protect request authenticity | Response confidentiality/integrity still needs HTTPS or response signatures |

## HTTPS Options

### Option A: Self-Signed Certificate Pinned In QR

Android generates a local self-signed certificate and includes its fingerprint in the QR pairing payload. iOS pins that fingerprint for the paired device.

Pros:

- No public CA dependency.
- Good fit for local-only transfer.
- QR pairing already provides a trust ceremony.

Cons:

- Certificate rotation and Android app reinstall require a clear re-pair flow.
- Debugging local TLS failures can be confusing for users.
- Implementation must handle IP-address certificates carefully.

### Option B: App-Level Response Signing

Keep local HTTP but sign response payloads and media hashes with the paired secret or device key.

Pros:

- Avoids local TLS certificate UX.
- Protects response integrity.
- Smaller change than HTTPS.

Cons:

- Does not provide confidentiality.
- Large media streaming needs careful chunk or whole-file verification.
- Still looks like insecure transport to reviewers and network tools.

### Option C: Local HTTPS With Trust-On-First-Use

iOS accepts and pins the first certificate seen for a paired Android device.

Pros:

- Simple first-run flow.
- Encrypts transport after first connection.

Cons:

- Weaker against first-connection MITM.
- Harder to explain than QR-pinned trust.

## M2 Decision

Do not implement local HTTPS in M2.

M2 should keep the tested signed local HTTP implementation and finish product reliability first:

- durable pairing,
- endpoint recovery,
- cancellation/resume,
- deleted-photo retry,
- validation evidence,
- user-facing readiness states.

## M3 Recommendation

Implement Option A in a dedicated M3 security milestone:

1. Add certificate fingerprint to the QR pairing payload schema.
2. Generate or persist an Android local certificate per device install.
3. Pin the certificate fingerprint in iOS paired-device state.
4. Switch protected endpoints to HTTPS.
5. Keep request signatures even after HTTPS for replay and authorization protection.
6. Add certificate rotation and clear pairing recovery UX.

## Release Gate

Before any broader beta, store-facing build, or non-developer release, ShareSync must either:

- ship local HTTPS with QR-pinned trust, or
- explicitly document why a signed local HTTP beta is acceptable for that audience and risk profile.
