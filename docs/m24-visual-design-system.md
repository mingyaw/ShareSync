# M24 Visual Design System

Status: Complete lightweight visual design system pass.

M24 turns the existing UI guidelines into small native theme tokens for the photo-only MVP.

## Tokens

The implemented tone set follows `docs/ui-design-guidelines.md`:

- Primary: `#2563EB`
- Success: `#16A34A`
- Warning: `#D97706`
- Error: `#DC2626`
- Info: `#0891B2`
- Neutral text, grouped backgrounds, surfaces, and subtle dividers

## Android

Android now uses a local `ShareSyncTheme` in `MainActivity` for:

- App background.
- Panel surfaces.
- Panel borders.
- Section accent bars.
- Primary and secondary text.

## iOS

iOS now uses `ShareSyncTheme` and `ShareSyncTone` in `ContentView` for:

- Background and surfaces.
- Summary status tones.
- Metric backgrounds and borders.
- Status row dividers.

## Scope

This is a source-level visual system pass, not a Figma-grade design system. Real-device screenshot QA remains deferred.
