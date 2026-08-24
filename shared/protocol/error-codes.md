# ShareSync Error Codes

Format:

```text
SS-{DOMAIN}-{CODE}
```

| Code | Meaning | User-facing direction |
|---|---|---|
| SS-PAIR-001 | QR code expired | Regenerate the pairing code |
| SS-AUTH-001 | Invalid signature | Re-pair the trusted device |
| SS-REQ-001 | Invalid request | Refresh pairing and retry |
| SS-NET-001 | Peer unreachable | Confirm both phones are on the same Wi-Fi |
| SS-NET-002 | Transfer interrupted | Sync will resume automatically |
| SS-NET-404 | Local endpoint not found | Refresh pairing and retry |
| SS-NET-405 | HTTP method not allowed | Update the app and retry |
| SS-MEDIA-001 | Hash mismatch | File will be downloaded again |
| SS-MEDIA-404 | Media item not found | Refresh the manifest and retry |
| SS-MEDIA-URI | Media URI unavailable | Refresh the manifest and retry |
| SS-MEDIA-STREAM | Media stream unavailable | Refresh the manifest and retry |
| SS-CONTACT-001 | Contacts permission denied | Allow contacts access |
| SS-FILE-001 | iCloud container unavailable | Enable iCloud Drive |
| SS-PERM-001 | Photos permission denied | Allow photos access |
| SS-STORE-001 | Not enough storage | Free storage and retry |
| SS-IOSBG-001 | iOS background time expired | Open the app to continue |
| SS-MEDIA-002 | Imported Photos asset missing | The item can be imported again |
| SS-MEDIA-999 | Unknown media transfer error | Retry the item |
