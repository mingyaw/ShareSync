# M50 Photo MVP Source Release Candidate

Status: Source complete on 2026-09-18.

M50 freezes the photo-only Android-to-iPhone source track as a Release Candidate.
The supported path is local foreground transfer from a paired Android phone into
iPhone Photos, followed by Apple's normal iCloud Photos behavior. There is no
ShareSync cloud relay, Apple ID access, reverse sync, video, contacts, files,
delete propagation, or unattended iOS background promise.

The `check-m50-source-rc.sh` gate verifies milestone evidence, UI/product gates,
release configuration, repository hygiene, privacy packaging, orchestration,
device discovery, deletion handling, resumable transport, and request security.

This is not public-release signoff. Required remaining evidence is QR-pinned
HTTPS physical-device validation, the intended device/stress matrix, signed
archives, TestFlight/closed beta, store metadata, and store review.
