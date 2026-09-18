# M41 Versioned Sync Ledger

Status: Complete source-code checkpoint.

Android sync results and iOS media download/import records now persist in schema-versioned envelopes. Both stores continue reading their previous unversioned JSON formats, so an app upgrade preserves duplicate prevention, retry state, and imported-photo mappings. Unknown future schema versions are rejected instead of being interpreted incorrectly.

Uninstall behavior is unchanged: app-private ledgers are removed with the app, so a reinstall starts with no ShareSync completion history.
