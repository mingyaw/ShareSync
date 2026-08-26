# ShareSync Local API Contract

Version: 1  
Transport: Local HTTPS over Wi-Fi or Android hotspot  
M0 allowance: HTTP is allowed for prototype only; MVP must use HTTPS plus signed requests.

## Common Headers

All paired requests must include:

```text
X-ShareSync-Version: 1
X-Device-Id: <device-id>
X-Session-Id: <session-id>
X-Timestamp: <unix-ms>
X-Nonce: <random-string>
X-Signature: <base64-signature>
```

M0 currently enforces this lightweight pairing header for protected endpoints:

```text
X-ShareSync-Pairing-Token: <pairing-token-from-qr-payload>
```

Signature payload:

```text
METHOD + "\n" +
PATH + "\n" +
X-Timestamp + "\n" +
X-Nonce + "\n" +
SHA256(body)
```

## Endpoints

### Health

```http
GET /v1/health
```

Returns device and protocol readiness.

### Pairing

```http
POST /v1/pairing/accept
Content-Type: application/json
```

iOS calls this endpoint after scanning the Android QR payload.

### Manifest

```http
GET /v1/manifest?sinceCursor=<cursor>
```

Returns metadata available for sync. M0 currently returns photo media only.

### Media Download

```http
GET /v1/media/{assetId}
Range: bytes=0-
```

Streams one photo for M0. Range support is required for MVP.

Supported M0 range forms:

- `bytes=<start>-`
- `bytes=<start>-<end>`
- `bytes=-<suffixLength>`

Successful partial responses return `206 Partial Content` with `Content-Range`. Unsatisfiable ranges return `416 Range Not Satisfiable`, `Content-Range: bytes */<totalSize>`, and `SS-REQ-416`.

### Contacts Export

```http
GET /v1/contacts/export?ids=<comma-separated-contact-ids>
```

Returns normalized contacts.

### File Download

```http
GET /v1/files/{fileId}
Range: bytes=0-
```

Streams one document file. Range support is required for MVP.

### Sync Result

```http
POST /v1/sync/result
Content-Type: application/json
```

Target device reports item-level import results back to source device.

## M0 Scope

M0 implements only:

- `GET /v1/health`
- `GET /v1/manifest`
- `GET /v1/media/{assetId}`
- `POST /v1/sync/result`
- local HTTP allowed only for first-device PoC
- lightweight pairing-token header enforcement on protected endpoints
- photo media only
- full HTTPS and signed requests remain required before MVP release
