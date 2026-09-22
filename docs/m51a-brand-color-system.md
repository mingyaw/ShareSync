# M51A Local Bridge Brand Color System

Status: Complete source-code pass.

M51A gives ShareSync a distinct product palette rooted in its core story: one
trusted local bridge carries photos from an Android phone to an iPhone without a
ShareSync cloud relay. Brand colors and operational status colors have separate
jobs so the interface no longer reads like a green engineering dashboard.

## Brand Story

- **Bridge Blue** represents the dependable local path between the two phones.
- **Handoff Coral** represents the human action of pairing and handing photos
  from one device to the other.
- **Vault Green** is reserved for privacy, safety, and completed transfer states.
- Cool paper and charcoal neutrals keep the product quiet and leave room for
  photo content and semantic feedback.

## Palette

| Role | Light | Dark | Usage |
| --- | --- | --- | --- |
| Primary / Bridge Blue | `#3159C6` | `#AFC2FF` | Primary actions, selected navigation, progress |
| Accent / Handoff Coral | `#C84F37` | `#FFAD99` | Pairing identity and cross-device handoff |
| Success / Vault Green | `#197653` | `#6FD6A8` | Connected, imported, complete |
| Warning | `#A65A16` | `#F3B66D` | Recoverable attention |
| Information | `#24708F` | `#79C5E8` | Neutral network and support information |
| Error | `#B3261E` | `#FFB4AB` | Failed or blocked actions |
| Background | `#F7F8FC` | `#111318` | App canvas |
| Surface | `#FFFFFF` | `#191B21` | Functional panels |
| Alternate surface | `#EEF1FA` | `#242936` | Selected and grouped content |
| Primary text | `#1B1D24` | `#F2F3FA` | Main content |
| Secondary text | `#5C606D` | `#C3C6D2` | Supporting content |
| Divider | `#DDE1EC` | `#3A3F4C` | Quiet boundaries |

The QR code always stays on pure white to preserve scanner contrast in both
appearances.

## Application Rules

- Do not use success green as the general brand or button color.
- Do not use coral for destructive actions; destructive actions remain red.
- Do not fill whole screens with blue. The canvas and primary surfaces stay
  neutral, while blue identifies actions and active navigation.
- Use color with an icon or text label for every operational state.
- Keep Android Material 3 behavior and iOS native control behavior instead of
  forcing pixel-identical components across platforms.

## Platform Assets

- Android semantic resources define the full light and dark palette.
- iOS `ShareSyncTheme` defines matching adaptive colors.
- The app icon uses Bridge Blue as its field, white device outlines, and a warm
  handoff disc with coral transfer arrows.
- Android adaptive icon and the iOS 1024 px icon share the same color story.

## Verification

Run:

```bash
bash scripts/check-ui-quality.sh
bash scripts/check-product-readiness.sh
```

Physical-device screenshot review remains part of the M51A visual QA matrix and
does not change the M50 transport or photo-sync scope.
