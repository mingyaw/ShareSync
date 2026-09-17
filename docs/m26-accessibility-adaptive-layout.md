# M26 Accessibility And Adaptive Layout

Status: Complete source-code pass.

M26 strengthens the photo-only MVP screen for larger system text, compact widths, and assistive technology without changing pairing or transfer behavior.

## Android

- The app title and product panel titles are exposed as accessibility headings.
- Primary status and next-step updates use polite live regions.
- The pairing QR code has a localized content description.
- Body copy has slightly increased line spacing while preserving system font scaling.
- Existing full-width actions retain a minimum 48 dp touch height.

## iOS

- The product title and titled panels expose heading traits.
- Summary metrics switch from a horizontal row to a vertical stack when the row no longer fits.
- Support sync actions switch from side-by-side to stacked controls when space is constrained.
- Status rows switch to a vertical label/value layout instead of shrinking or truncating content.
- Status rows and metrics are grouped into useful VoiceOver elements.
- Existing SwiftUI semantic fonts continue to follow Dynamic Type.

## Deferred Visual QA

Real-device checks remain deferred until explicitly resumed:

- VoiceOver and TalkBack traversal order.
- Largest accessibility text sizes in English and Traditional Chinese.
- Compact iPhone keyboard interaction.
- Android display-size and font-size combinations.
- Light and dark appearance screenshots.
