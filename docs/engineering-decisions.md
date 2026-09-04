# ShareSync Engineering Decisions

## ED-001 Native Apps

Decision: use Kotlin for Android and Swift for iOS.

Reason: sync reliability depends on platform APIs such as MediaStore, PhotoKit, background transfer, Contacts, BLE, local networking, and iCloud Documents.

## ED-002 Android Controls MVP Sync

Decision: Android is the source/controller for MVP.

Reason: Android background scanning and scheduling are more reliable than iOS always-on background execution.

## ED-003 iOS Is the iCloud Gateway

Decision: iOS receives local data and writes it into Photos, Contacts, or the app iCloud Documents container.

Reason: Android cannot directly write to the user's iCloud Photos or iCloud Drive through a supported public Android API.

## ED-004 Local Transfer Only

Decision: no third-party cloud relay in MVP.

Reason: product value depends on private, local transfer.

## ED-005 M1 Uses Signed Local HTTP, HTTPS Moves To Pre-Release Hardening

Decision: M1 may use same-network local HTTP when every protected request is signed with the paired-device secret, timestamp, and nonce. Local HTTPS remains required before any broader beta, store review, or non-developer release.

Reason: self-signed local HTTPS certificate trust and rotation would add user-visible setup friction before the photo-only MVP is product-stable. Signed requests already prevent token-only access, stale endpoint reuse, and replay within the local network threat model, while keeping local HTTPS as an explicit pre-release hardening branch.

## ED-006 No Delete Sync in MVP

Decision: MVP never deletes target data.

Reason: duplicate prevention and conservative merge are safer than destructive sync while sync identity is still maturing.
