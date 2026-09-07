# M2 iOS Foreground/Background Checklist

This checklist validates ShareSync's M2 photo-only interruption behavior on physical devices. Do not use it for simulator-only signoff.

## Required Setup

- Android device has ShareSync open or backgrounded with the foreground service running.
- iPhone is paired with the Android device and can fetch the Android photo manifest.
- Both devices are on the same local Wi-Fi or hotspot network.
- iPhone Photos permission is set to Full Access or Limited Access with enough selected photos.
- Android has at least 30 photos available so the transfer takes long enough to interrupt.

## Test Cases

### 1. Manual Cancel Then Resume

1. On iPhone, start Sync All Photos.
2. Wait until at least one photo is imported.
3. Tap Cancel.
4. Confirm the UI shows a cancelled state and remaining photos can be retried.
5. Tap Resume Photo Sync.
6. Confirm already imported photos are not imported again.
7. Confirm remaining photos continue and the final state becomes complete or shows only real failures.

Expected result: imported photos are skipped, downloaded partial work is reused when possible, and the Android sync-result endpoint receives the updated result after resume.

### 2. Home Button Or App Switcher Interruption

1. On iPhone, start Sync All Photos.
2. While transfer is active, leave ShareSync using Home/app switcher.
3. Wait 10 seconds.
4. Return to ShareSync.
5. Confirm the UI reports that transfer was paused because the app left the foreground.
6. Tap Resume Photo Sync.

Expected result: completed items remain recorded and the next sync continues remaining photos without requiring pairing again.

### 3. Screen Lock Interruption

1. On iPhone, start Sync All Photos.
2. Lock the screen while transfer is active.
3. Wait 10 seconds.
4. Unlock and return to ShareSync.
5. Resume photo sync.

Expected result: the app either resumes remaining items or shows a clear cancelled/paused state. It must not show an active transfer if no transfer task is running.

### 4. Android Endpoint Change During Pause

1. Pair iPhone with Android and start Sync All Photos.
2. Interrupt iPhone transfer by leaving the app.
3. Change Android network endpoint by switching Wi-Fi/hotspot.
4. Reopen Android ShareSync and confirm QR/status is ready.
5. Return to iPhone and tap Resume Photo Sync.

Expected result: iPhone should discover the paired Android device when possible. If discovery fails, it should show a reachable endpoint error without clearing imported/downloaded progress.

## Evidence To Record

- iPhone model and iOS version.
- Android model and Android version.
- Network type: Wi-Fi, phone hotspot, or router.
- Photo count tested.
- Whether pairing survived the interruption.
- Whether imported count stayed stable after resume.
- Whether Android latest sync result matched iPhone final result.
- Any error code or UI state shown during failure.
