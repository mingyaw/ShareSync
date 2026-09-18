# M44 - Durable Device Binding

Status: Complete on 2026-09-18.

- [x] Persist paired-device identity and last known endpoint.
- [x] Advertise and discover the active Android endpoint with Bonjour/mDNS.
- [x] Prefer discovery after IP changes and retain saved-endpoint fallback.
- [x] Validate health device ID before using a refreshed endpoint.
- [x] Reject changed QR-pinned certificate identity without downgrade.
