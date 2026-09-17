# M29 Consistent Feedback States

Status: Complete source-code pass.

M29 gives the primary workflow a consistent vocabulary and visual treatment for state changes.

- Android status and phase text use semantic ready, active, and informational colors.
- Android action labels use normal sentence casing.
- iOS shows an explicit progress indicator while foreground transfer is active.
- iOS copy confirmation, paused transfer, fetch errors, and transfer errors share one feedback component.
- Feedback components combine icon and message semantics for VoiceOver.

Transfer logic, persistence, and retry behavior are unchanged.
