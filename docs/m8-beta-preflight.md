# M8 Beta Preflight

Status: Complete beta preflight automation for the photo-only MVP.

M8 combines the M6 release-readiness gate and M7 handoff record into one repeatable preflight command.

## Default Preflight

Run this before preparing or sharing internal beta artifacts:

```sh
bash scripts/check-beta-preflight.sh --transport signed-http
```

The default preflight runs:

- Whitespace diff check.
- Release-readiness gate.
- Repository hygiene gate.
- Support snapshot inspector validation.
- Beta handoff record generation.

The generated handoff record is printed to the terminal unless `--handoff-output` is provided.

## Full Preflight

Run the full gate when source code changed and the beta is close to handoff:

```sh
bash scripts/check-beta-preflight.sh --transport signed-http --full
```

The full gate also runs `./scripts/check-m0.sh`, which includes fixture validation, Swift tests, Android unit/Kotlin checks, and the generic iOS build.

## Artifact Recording

After manually producing APK/IPA artifacts outside Git, record checksums:

```sh
bash scripts/check-beta-preflight.sh \
  --transport signed-http \
  --artifact /path/to/ShareSync-android.apk \
  --artifact /path/to/ShareSync-ios.ipa \
  --handoff-output /path/to/ShareSync-beta-handoff.md
```

Do not write generated handoff records, app binaries, signing material, DerivedData, Gradle output, or local credentials into the repository.

## Scope Reminder

M8 does not change product scope:

- Android-to-iOS photos only.
- Local network transfer only.
- iPhone Photos import only; iCloud backup depends on the user's existing iCloud Photos settings.
- No cloud relay, direct iCloud access, Apple ID handling, videos, contacts, files, reverse sync, delete propagation, or unattended iOS background sync.
