# M30 UI Beta Freeze

Status: Complete static checkpoint.

M30 freezes the second product UI pass for the photo-only MVP and adds a repeatable static quality gate.

## Automated Gate

Run:

```bash
bash scripts/check-ui-quality.sh
```

The gate checks:

- Android light and dark resource files are valid XML.
- Required Android semantic colors exist in both appearances.
- The Android screen does not regress to hard-coded UI colors.
- English and Traditional Chinese iOS strings are valid.
- Destructive-action and active-transfer copy exists in both iOS languages.
- iOS adaptive appearance, compact layout, confirmation, and feedback primitives remain present.

The UI quality gate runs from beta preflight and the full M0 gate. This checkpoint does not claim real-device visual, accessibility, signing, store, or distribution approval.
