# ShareSync Error Recovery Matrix

Status: M3 shared UX baseline.

Use this matrix to keep Android and iOS recovery behavior consistent. UI copy can be shorter than this table, but the next action must stay aligned.

| State | Typical Trigger | Error Code | User-Facing Message Direction | Primary Recovery |
| --- | --- | --- | --- | --- |
| Android photos permission missing | Android cannot read MediaStore photos | SS-PERM-001 | Allow photo access on Android before sharing. | Open Android permission flow, then refresh sharing status. |
| iOS Photos permission missing | iPhone cannot import into Photos | SS-PERM-001 | Allow Photos access on iPhone before syncing. | Open iOS Settings or request Photos permission again. |
| Local peer unreachable | Phones are on different networks or Android service stopped | SS-NET-001 | Keep both phones on the same Wi-Fi or Android hotspot. | Reopen Android ShareSync, confirm sharing is ready, then retry from iPhone. |
| Saved endpoint is stale | Android IP/port changed after pairing | SS-NET-404 | The paired Android phone was not found at the saved address. | Use discovery if available; otherwise scan the latest Android QR code. |
| Unexpected peer | Saved endpoint points to a different Android device | SS-AUTH-001 | This endpoint is not the paired Android phone. | Stop retrying this endpoint and re-pair with the intended Android phone. |
| QR pairing expired | iOS scans an old pairing payload | SS-PAIR-001 | Pairing code expired. Generate a new code on Android. | Show a fresh Android QR code and scan again. |
| Invalid signature | Request signature fails on Android | SS-AUTH-001 | Pairing could not be verified. | Clear pairing on iPhone and scan a fresh Android QR code. |
| Transfer interrupted | iOS leaves foreground, network drops, or user cancels | SS-NET-002 | Transfer paused. Completed photos are kept and remaining photos can continue. | Tap Resume Photo Sync. |
| Partial range unavailable | iOS tries to resume from an invalid byte range | SS-REQ-416 | Partial download cannot be resumed from the saved point. | Refresh manifest and redownload that photo. |
| Hash mismatch | Downloaded bytes do not match manifest or response hash | SS-MEDIA-001 | File verification failed and will be retried. | Retry the photo. |
| Size mismatch | Downloaded size differs from expected size | SS-MEDIA-004 | File size changed or transfer was incomplete. | Retry the photo after refreshing manifest. |
| Android media item missing | MediaStore item disappeared after manifest generation | SS-MEDIA-404 | This Android photo is no longer available. | Refresh manifest and skip unavailable items. |
| Imported iOS photo deleted | ShareSync mapping exists but Photos asset is gone | SS-MEDIA-002 | Imported photo is missing and can be imported again. | Refresh manifest, then resume photo sync. |
| Not enough iPhone storage | iOS cannot write downloaded/imported photo | SS-STORE-001 | Free storage on iPhone before syncing. | Free iPhone storage and retry. |
| Method unsupported | App version mismatch or wrong endpoint call | SS-NET-405 | Update ShareSync on both phones. | Install matching builds and retry. |
| Unknown media error | Import or transfer fails without a mapped cause | SS-MEDIA-999 | Something went wrong with this photo. | Retry; if repeated, record evidence with source item id. |

## Product Rules

- Prefer one primary next action per screen.
- Do not ask users to understand raw JSON during normal recovery.
- Keep copy honest about iOS foreground limits.
- Never imply that ShareSync backs up directly to iCloud before iOS Photos import completes.
- Never clear local sync state automatically as a recovery action.
