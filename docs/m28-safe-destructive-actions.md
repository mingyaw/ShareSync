# M28 Safe Destructive Actions

Status: Complete source-code pass.

M28 protects local product state from accidental destructive actions.

- Android asks for confirmation before clearing photo sync history.
- iOS asks for confirmation before resetting photo history.
- iOS asks for confirmation before forgetting the paired Android phone.
- Confirmation copy explains whether photos are deleted and whether pairing or sync availability can return.
- Destructive controls remain disabled while an iOS transfer is active.

These actions only change ShareSync local history or pairing state. They do not delete photos from Android, iPhone Photos, or iCloud Photos.
