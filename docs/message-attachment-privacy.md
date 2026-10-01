# Messages Attachment Privacy And Size Limits

Status: approved design boundary; binary attachment upload is not implemented.

## Current Product Contract

ShareSync reads only the attachment count and MIME type columns exposed by the
Messages database. It does not read attachment filenames, paths, byte sizes, or
file contents. Telegram receives no attachment count or type metadata by
default. When the user explicitly enables attachment summaries, Telegram
receives only the count and MIME types. Attachment-only messages still produce
a generic notice so the user knows that content remained on the Mac.

The summary preference is local to the Mac, is disabled by default, and is
deleted with the Telegram configuration. It does not change Messages database
access or grant media-upload permission.

## Future Upload Gate

Binary attachment forwarding must remain unavailable until every condition
below is implemented and tested:

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

## Acceptance Gate

A synthetic attachment outside the Messages directory, a symbolic link, an
unsupported MIME type, an oversized file, and a batch over the aggregate limit
must all fail closed before network delivery. An allowed image may be read only
after policy approval, delivered to the fixed Telegram host, and retried without
adding sensitive data to the local ledger or audit history.
