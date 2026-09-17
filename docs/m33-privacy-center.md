# M33 Privacy Center

Status: Complete source-code pass.

M33 makes the photo-only privacy boundary visible inside both apps.

- Photos transfer directly over the local network to the paired phone.
- ShareSync does not operate a photo cloud relay.
- Device identity, pairing, and completion records stay in app-local storage.
- Clearing local history does not delete photos.
- On iPhone, Photos and the user's existing iCloud Photos settings control iCloud backup after import.

See [Privacy Data Summary](privacy-data-summary.md) for the engineering inventory. Store declarations still require review against the final binaries and current store policies.
