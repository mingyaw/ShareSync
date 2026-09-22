# M24 Visual Design System

Status: Complete lightweight visual design system pass.

M24 turns the existing UI guidelines into small native theme tokens for the photo-only MVP.

## Tokens

The implemented tone set follows `docs/ui-design-guidelines.md`:

- Primary: `#087F70` light / `#69D4BC` dark
- Success: `#16803A`
- Warning: `#B65E34`
- Error: `#B42318`
- Info: `#286E9B`
- Neutral text, grouped backgrounds, surfaces, and subtle dividers

## Android

Android now uses Material 3 colors in `ShareSyncComposeTheme` for:

- App background.
- Panel surfaces.
- Panel borders.
- Section accent bars.
- Primary and secondary text.
- Grouped settings, action icons, and light/dark system surfaces.

## iOS

iOS now uses `ShareSyncTheme` and `ShareSyncTone` in `ShareSyncDesignSystem.swift` for:

- Background and surfaces.
- Summary status tones.
- Metric backgrounds and borders.
- Status row dividers.
- The same teal ShareSync identity used by Android while retaining native SwiftUI controls.

## Scope

This is a source-level visual system pass, not a Figma-grade design system. Real-device screenshot QA remains deferred.
