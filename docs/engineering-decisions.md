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

## ED-005 M0 Allows HTTP, MVP Requires HTTPS

Decision: M0 can use HTTP to validate local transfer and Photos import. MVP must use HTTPS and signed requests.

Reason: certificate and trust handling should not block the first technical proof, but production cannot ship cleartext transfer.

## ED-006 No Delete Sync in MVP

Decision: MVP never deletes target data.

Reason: duplicate prevention and conservative merge are safer than destructive sync while sync identity is still maturing.

