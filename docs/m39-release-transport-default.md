# M39 Release Transport Default

Status: Complete source-code checkpoint.

Android Debug uses signed local HTTP for development. Beta and Release force QR-pinned HTTPS and continue requiring signed requests. Pairing carries the certificate SHA-256 fingerprint and iOS rejects mismatched certificates without downgrading to HTTP.

The transport implementation and automated tests are complete. Same-Wi-Fi and hotspot certificate validation on physical devices remains a release gate.
