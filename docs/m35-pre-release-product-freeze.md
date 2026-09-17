# M35 Pre-release Product Freeze

Status: Complete static checkpoint.

M35 freezes the photo-only MVP product source before physical-device and distribution signoff.

Run:

```bash
bash scripts/check-product-readiness.sh
bash scripts/check-beta-preflight.sh --transport signed-http
```

The product gate validates:

- Android and iOS app identity assets.
- The 1024 px iOS AppIcon source.
- English and Traditional Chinese setup and privacy copy.
- Debug, Beta, and Release identifiers and channels.
- Android backup policy and iOS build-channel metadata.

## Remaining Release Gates

- Physical-device transfer and Photos/iCloud observation.
- Home-screen icon and launch appearance review.
- VoiceOver, TalkBack, large text, and dark appearance review.
- Release signing, provisioning, archive, install, and upgrade testing.
- Current App Store and Google Play privacy declarations and review requirements.
- QR-pinned HTTPS signoff if selected for release transport.

Until those gates are recorded, M35 is a source-code checkpoint rather than store approval.
