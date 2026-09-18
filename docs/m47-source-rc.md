# M47 Local Transport Security Closure

Status: Complete source-code checkpoint.

Protected requests use HMAC-SHA256 signatures over method, path, timestamp,
nonce, and body hash. Android enforces a timestamp window and one-use nonce per
server session. Beta and Release use QR-pinned HTTPS with no HTTP downgrade;
Debug retains signed local HTTP. Copied diagnostics exclude pairing secrets,
signatures, private keys, and photo content.

QR-pinned HTTPS physical-device signoff remains a release blocker rather than a
source-code blocker.
