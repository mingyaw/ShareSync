# ShareSync Notes Model / ShareSync 記事模型

Status: Android and macOS local-data milestone, schema version 1.

狀態：Android 與 macOS 本機資料里程碑，schema version 1。

## Product boundary / 產品邊界

ShareSync notes are owned by ShareSync. Android remains the primary phone and
the Mac is the local bridge and peer. The model does not read Apple Notes,
Google Keep, or another vendor database, and no ShareSync cloud relay is
introduced.

ShareSync 記事由 ShareSync 管理。Android 仍是主要手機，Mac 是本地橋接與同步端。
此模型不讀取 Apple Notes、Google Keep 或其他廠商的私有資料庫，也不引入
ShareSync 雲端中繼。

## Version contract / 版本契約

Every note contains a schema version, stable UUID, title, Markdown body,
creation and update times, normalized tags, a revision stamp, an optional
parent revision, an optional deletion time, and an optional original-note ID
for conflict copies.

每則記事包含 schema 版本、穩定 UUID、標題、Markdown 本文、建立與更新時間、
正規化標籤、revision stamp、可選的 parent revision、可選的刪除時間，以及衝突副本
所使用的原始記事 ID。

A revision stamp is `(sequence, deviceId)`. A local edit increments the
sequence and stores the previous stamp as its parent. The device ID is the
durable identity already owned by the pairing layer. This explicit parent is
what distinguishes a fast-forward from two offline edits based on the same
revision.

Revision stamp 為 `(sequence, deviceId)`。本機修改會遞增 sequence，並把上一個 stamp
存為 parent。device ID 沿用配對層的耐久裝置識別；明確的 parent 可分辨正常快轉與
兩台裝置從同一版本離線修改的情形。

## Merge and deletion / 合併與刪除

- An identical revision is idempotent.
- A direct child replaces its parent; receiving a parent after its child keeps
  the child.
- Divergent revisions are concurrent. A deterministic winner is selected by
  revision ordering, while the losing live content is stored under a stable
  conflict-copy ID and marked with `conflictOfNoteId`.
- A tombstone wins over a concurrent live edit to prevent resurrection. The
  live edit remains available as a conflict copy.
- Concurrent tombstones converge without making an empty conflict copy.
- Tombstones clear title, body, and tags. Their retention and compaction window
  must be decided before transport deletion acknowledgements ship.

- 完全相同的 revision 可安全重試，不產生額外變更。
- 直接子版本取代父版本；先收到子版本後再收到父版本時保留子版本。
- 分歧版本視為同時修改：以 revision 排序選出一致的主版本，另一份仍有內容的版本
  會用穩定 ID 儲存為衝突副本，並以 `conflictOfNoteId` 標記。
- tombstone 與同時發生的編輯衝突時，tombstone 優先以避免記事復活，編輯內容則保留
  為衝突副本。
- 兩個同時產生的 tombstone 直接收斂，不建立空白衝突副本。
- tombstone 會清空標題、本文與標籤；在傳輸層啟用刪除確認前，仍須決定保留與壓縮週期。

## Local persistence / 本機持久化

Android stores a versioned JSON envelope in
`filesDir/ShareSync/notes-v1.json`. macOS stores the same envelope at
`Application Support/ShareSync/notes-v1.json`. Both use an atomic replacement
write and surface decode errors instead of silently discarding the user's
notes. The `ShareSyncNotes` Swift Package target owns the Mac model, codec,
repository, persistence, and merge policy. Both Kotlin and Swift tests decode
`shared/fixtures/sample-note-store.json`; the Swift round trip also verifies
that required nullable fields remain explicit JSON `null` values.

Android 將版本化 JSON envelope 儲存在 `filesDir/ShareSync/notes-v1.json`，macOS 則使用
`Application Support/ShareSync/notes-v1.json`。兩端皆以 atomic replace 寫入；解碼錯誤
會明確回報，不會靜默丟棄使用者記事。`ShareSyncNotes` Swift Package target 包含 Mac 的
model、codec、repository、持久化與 merge policy。Kotlin 與 Swift 測試都會解碼
`shared/fixtures/sample-note-store.json`，Swift round trip 另驗證必要的 nullable 欄位仍以
明確 JSON `null` 保存。UI、搜尋與簽章區網傳輸將在後續里程碑沿用此契約。

macOS 的本機 revision 使用 `MacNoteDeviceIdentity` 所提供、持久化於 `UserDefaults` 的
`mac-<uuid>` device ID。衝突副本 ID 精確沿用 Android 的 Java UUID v3 算法：對
`sharesync-note-conflict|<note-id>|<sorted-revision-pair>` 的 UTF-8 bytes 計算 MD5 並設定
RFC 4122 version/variant bits，因此兩端不論合併順序都會產生相同 ID。

## Snapshot exchange / 快照交換

The first transport contract is `NoteSyncBatch` schema version 1. It carries a
non-empty batch ID, source device ID, generation time, and a unique set of full
note revisions including tombstones. Encoders sort notes by stable ID, and
decoders reject duplicate IDs before merging. Repositories merge the batch in a
deterministic order and return aggregate accepted, kept, unchanged, conflict,
and conflict-copy counts. The contract is validated by
`shared/fixtures/sample-note-sync-batch.json` on Kotlin, Swift, and the shared
fixture gate.

第一版傳輸契約為 `NoteSyncBatch` schema version 1，包含非空白 batch ID、來源裝置 ID、
產生時間，以及 ID 唯一的完整記事 revision（包含 tombstone）。編碼時依穩定 ID 排序，
解碼時會在合併前拒絕重複 ID。Repository 以固定順序合併整批資料，並回報接受、保留、
未變更、衝突與衝突副本數量。Kotlin、Swift 與共用 fixture gate 都使用
`shared/fixtures/sample-note-sync-batch.json` 驗證此契約。

Android now exposes the contract through signed `GET /v1/notes` and
`POST /v1/notes` endpoints. `GET` creates a full repository snapshot with a new
batch ID; `POST` verifies that the signed device ID matches the batch source,
merges all revisions, persists the result, and returns aggregate merge counts.
The production composition stores notes atomically in
`filesDir/ShareSync/notes-v1.json`.

`ShareSyncMac` now compiles the shared note model directly and provides a
manual bidirectional sync action. One cycle resolves the paired Android
endpoint, downloads and merges its signed snapshot, then uploads the complete
merged Mac snapshot with the same device-scoped credential. The app keeps note
status separate from photo transfer status, persists notes under Application
Support, and retains them when the Android pairing is removed. The Android HTTP
reader consumes request bodies by UTF-8 byte length, so CJK note content matches
the signed bytes and is not truncated.

The Mac product surface also supports creating, editing, tagging, and deleting
notes. Deleted notes become hidden tombstones rather than disappearing from the
store, so the next sync can propagate the deletion. Removing a paired phone does
not remove these notes or tombstones.

Android 已透過需簽章的 `GET /v1/notes` 與 `POST /v1/notes` 提供此契約。`GET` 會以新
batch ID 建立完整 repository 快照；`POST` 會驗證簽章裝置 ID 與批次來源相同，合併並
持久化所有 revision，再回傳彙總結果。正式組裝使用
`filesDir/ShareSync/notes-v1.json` 原子寫入。

`ShareSyncMac` 現已直接編譯共用記事模型，並提供手動雙向同步。每次同步會解析已綁定
Android 端點、下載並合併簽章快照，再以相同裝置憑證回推 Mac 合併後的完整快照。記事
狀態與照片傳輸狀態彼此獨立，資料保存在 Application Support，解除 Android 配對時也
不會刪除。Android HTTP 讀取器依 UTF-8 位元組長度接收 body，因此繁中記事不會被截斷，
簽章內容也能保持一致。

Mac 產品介面亦可新增、編輯、加標籤與刪除記事。刪除後會轉為隱藏 tombstone，而非直接
從資料庫消失，所以下次同步能將刪除狀態傳到另一端；解除手機配對也不會清除記事或
tombstone。
