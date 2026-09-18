# M44 Durable Device Binding

Status: Complete source-code checkpoint.

Pairing is bound to Android device identity, token, public metadata, and optional
TLS certificate fingerprint rather than a permanent IP address. Bonjour/mDNS is
used to refresh the endpoint, `/v1/health` must return the trusted device ID, and
the saved endpoint remains a fallback where discovery is unavailable. A changed
identity or pinned certificate requires explicit re-pairing.
