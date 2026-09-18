# ShareSync Privacy Data Summary

Status: Engineering inventory for the photo-only MVP.

| Data | Location | Purpose | Removal |
| --- | --- | --- | --- |
| Android photo metadata | Android memory and local manifest response | Build the available photo list | Rebuilt from MediaStore |
| Photo bytes | Direct local transfer; temporary iOS file before import | Import into iPhone Photos | Temporary transfer files are cleared by transfer lifecycle |
| Device identity | App-local Android storage | Stable paired-device identity | Android app data removal |
| Pairing secret and endpoint | App-local storage on the paired devices | Authenticate local requests and reconnect | Forget pairing or app data removal |
| Photo completion history | App-local storage on both devices | Prevent duplicate transfers and support retry | Reset or clear photo history |
| Imported photo reference | App-local iOS storage | Reconcile deleted imported photos | Reset photo history or app data removal |
| Support snapshot | Generated locally and copied only by user action | Troubleshooting | Clipboard lifecycle controlled by the OS/user |

ShareSync has no application-operated photo relay, account system, advertising SDK, or analytics SDK in the M41 source tree. iCloud behavior is provided by Apple Photos after import and depends on the user's settings.

This inventory must be compared with final binaries, dependencies, and current store questionnaires before distribution.
