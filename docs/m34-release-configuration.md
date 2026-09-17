# M34 Release Configuration

Status: Complete source-code pass.

M34 separates development distribution from the production identifiers.

| Channel | Android | iOS |
| --- | --- | --- |
| Debug | `.debug` application suffix | `com.sharesync.ios.debug` |
| Beta | `.beta` application suffix | `com.sharesync.ios.beta` |
| Release | `com.sharesync.android` | `com.sharesync.ios` |

- Both platforms expose a build channel in generated build metadata.
- Android pairing metadata uses `BuildConfig.VERSION_NAME`.
- iOS display names distinguish Dev, Beta, and Release builds.
- Android and iOS version numbers remain synchronized by the release-readiness gate.

Signing identities and store provisioning are intentionally outside source control.
