# Messages Attachment Privacy And Size Limits

Status: explicit opt-in product integration implemented for JPEG and PNG
forwarding; physical-Mac and live Telegram validation remain release gates.

## Current Product Contract

By default, ShareSync reads only the attachment count and MIME type columns
exposed by the Messages database. It does not read attachment filenames, paths,
byte sizes, or file contents. Telegram receives no attachment count or type
metadata by default. When the user explicitly enables attachment summaries,
Telegram receives only the count and MIME types. Attachment-only messages still
produce a generic notice so the user knows that content remained on the Mac.

The summary preference is local to the Mac, is disabled by default, and is
deleted with the Telegram configuration. It does not change Messages database
access or grant media-upload permission.

## Future Upload Gate

Binary attachment forwarding is available only after every condition below is
implemented and the user separately opts in:

- A separate opt-in explains that media bytes will leave the Mac for Telegram.
- Sender and optional conversation allowlists are evaluated before file access.
- Only regular files inside the canonical Messages Attachments directory are
  eligible; symbolic links and paths escaping that directory are rejected.
- The initial allowlist is JPEG and PNG images only. Video, audio, documents,
  archives, contact cards, locations, and Live Photo companions remain blocked.
- Each file is limited to 10 MiB, each message to four files, and each message
  batch to 20 MiB. Limits are checked before and after opening the file.
- No format conversion, thumbnail generation, temporary copy, or persistent
  media cache is permitted in the first upload milestone.
- Telegram requests use a dedicated fixed-host multipart transport that applies
  the same redirect rejection, timeout, and system TLS trust rules as text.
- A failed or ambiguous upload does not advance the Messages cursor. Delivery
  state keeps only an opaque key and aggregate outcome.
- Logs, audit history, and UI diagnostics never contain filenames, paths,
  message IDs, sender identifiers, or media bytes.

`MessageAttachmentUploadPolicy` now implements the default-off gate, canonical
root containment, symbolic-link rejection, regular-file checks, JPEG/PNG
allowlisting, per-file and aggregate limits, and post-read size verification.
The pre-transport check revalidates that uploads are still enabled and the MIME
type remains allowed.

`TelegramBotMediaUploader` implements an in-memory multipart request limited to
Telegram's fixed HTTPS host and `sendPhoto` method. It uses only generic
`sharesync.jpg` or `sharesync.png` filenames, inherits redirect rejection and
timeouts from the Telegram transport, and maps Telegram rate-limit responses.
It never receives an original filename as request metadata and creates no
temporary media copy.

`MessageAttachmentAccessCoordinator` evaluates the existing sender,
conversation, direction, service, associated-event, and sensitive-content rules
before asking an attachment provider for any path. The content loader then
revalidates the whole candidate batch immediately before opening files, reads in
bounded chunks, and reads at most one byte beyond the validated size to detect
growth. A disabled policy, changed size, missing file, or failed read returns no
payload.

`SQLiteMessageAttachmentCandidateProvider` is the only component that reads
`attachment.filename`. It opens the Messages database read-only, queries rows
only for an already-approved message `ROWID`, and accepts only absolute or
leading-home-marker paths. Missing schema, MIME type, filename, or a relative
path fails the whole request. The general event reader remains path-blind.

The forwarding pipeline can now accept an optional attachment delivery
coordinator. Text and each attachment use separate opaque part keys in the
content-free delivery ledger. A failed attachment keeps the message cursor in
place, while later retries skip parts that already returned a confirmed success.
An attachment event with no candidate rows fails closed.

Run results and the bounded audit retain only aggregate delivered and
already-confirmed attachment counts. They never retain filenames, paths, media
bytes, source row IDs, or Telegram message IDs. Legacy audit records decode
missing attachment counters as zero.

Attachment candidate, access, and validation failures are recorded only as the
aggregate `attachmentRejected` outcome. The record does not retain the rejected
path, MIME type, filename, sender, conversation, or message body.

The unified Mac app now instantiates these components only when the stored
`MessageAttachmentConsent` is enabled and matches the current consent version.
The independent summary preference does not grant file access. Disabling media
upload removes the consent version and returns the next forwarding pass to the
path-blind metadata flow; Telegram reset removes both preferences.

## Acceptance Gate

A synthetic attachment outside the Messages directory, a symbolic link, an
unsupported MIME type, an oversized file, and a batch over the aggregate limit
must all fail closed before network delivery. An allowed image may be read only
after policy approval, delivered to the fixed Telegram host, and retried without
adding sensitive data to the local ledger or audit history.

The synthetic end-to-end gate now covers root escape, symbolic links,
unsupported MIME types, per-file limits, aggregate limits, fixed-host multipart
delivery, generic filenames, Telegram rate limiting, confirmed-part retry, and
cursor preservation. Physical Messages permission and live Telegram media
delivery remain separate release checks.
