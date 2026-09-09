# M4 - QR-Pinned HTTPS

Status: Active after M3 pre-release hardening completion on 2026-09-08.

Goal: implement the M3 local security direction by moving the photo-only main axis from signed local HTTP toward QR-pinned HTTPS, while keeping request signing and preserving compatibility until real-device validation is ready.

## Scope

M4 keeps the same photo-only product axis:

- Android remains the source device and local transfer server.
- iOS remains the foreground receiver and iCloud Photos gateway.
- No cloud relay, Apple ID handling, or third-party storage integration is introduced.
- HTTPS work must not remove request signing.
- Transport changes should be feature-gated or staged until real-device validation resumes.

## Main Tasks

### M4.1 Android Certificate Provider Foundation

- [x] Add Android local certificate descriptor and provider abstraction.
- [x] Add deterministic SHA-256 fingerprint calculation tests.
- [x] Add transport security factory for QR-pinned HTTPS pairing metadata.
- [ ] Add Android Keystore-backed certificate generation and persistence.
- [ ] Define explicit certificate rotation behavior in Android runtime.

### M4.2 Android Pairing Integration

- [ ] Wire persisted Android certificate fingerprint into pairing QR payload generation.
- [ ] Keep signed HTTP pairing payload compatibility during migration.
- [ ] Add Android UI/status copy for HTTPS-ready transport mode.

### M4.3 iOS Certificate Pinning Foundation

- [ ] Store pairing transport security metadata with paired-device state.
- [ ] Add iOS certificate fingerprint validator.
- [ ] Add mismatch and no-downgrade recovery tests.
- [ ] Confirm Clear Pairing removes pinning metadata while Reset Local Sync State preserves it.

### M4.4 Transport Switch

- [ ] Add Android local HTTPS server path behind an explicit mode switch.
- [ ] Add iOS URL/session selection for signed HTTP vs QR-pinned HTTPS.
- [ ] Keep signed request validation active on HTTPS endpoints.
- [ ] Add unit coverage for wrong certificate, stale token, and invalid signature paths.

### M4.5 Validation Readiness

- [ ] Update M0/M2 validation documents with HTTPS-specific cases.
- [ ] Keep `./scripts/check-m0.sh` green before real-device validation.
- [ ] Defer real-device HTTPS signoff until explicitly requested.

## Progress Log

### 2026-09-09 M4 Started

Started M4 with the lowest-risk Android foundation slice:

- Added local certificate descriptor/provider abstractions without changing the running local server.
- Added deterministic certificate fingerprint tests so QR-pinned HTTPS metadata has a stable contract.
- Added a pairing transport security factory that can feed QR payload metadata once Android certificate persistence is wired in.
