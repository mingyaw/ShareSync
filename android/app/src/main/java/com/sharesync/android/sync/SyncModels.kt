package com.sharesync.android.sync

data class PairingPayload(
    val version: Int = 1,
    val type: String = "sharesync_pairing",
    val deviceId: String,
    val deviceName: String,
    val platform: String = "android",
    val publicKey: String,
    val ip: String,
    val port: Int,
    val pairingToken: String,
    val expiresAt: String,
)

data class SyncManifest(
    val version: Int = 1,
    val sourceDeviceId: String,
    val generatedAt: String,
    val cursor: String,
    val media: List<MediaAsset>,
    val contacts: List<ContactItem> = emptyList(),
    val files: List<FileItem> = emptyList(),
)

data class MediaAsset(
    val assetId: String,
    val sourceDeviceId: String,
    val mediaType: MediaType,
    val fileName: String,
    val mimeType: String,
    val size: Long,
    val sha256: String? = null,
    val createdAt: String? = null,
    val modifiedAt: String? = null,
    val takenAt: String? = null,
    val width: Int? = null,
    val height: Int? = null,
    val durationMs: Long? = null,
    val relativePath: String? = null,
)

enum class MediaType {
    photo,
    video,
}

data class ContactItem(
    val contactId: String,
    val sourceDeviceId: String,
    val displayName: String,
    val phones: List<String>,
    val emails: List<String>,
)

data class FileItem(
    val fileId: String,
    val sourceDeviceId: String,
    val fileName: String,
    val relativePath: String,
    val size: Long,
    val mimeType: String? = null,
    val sha256: String? = null,
)

data class SyncResult(
    val syncBatchId: String,
    val targetDeviceId: String,
    val results: List<SyncItemResult>,
)

data class SyncItemResult(
    val itemType: SyncItemType,
    val sourceItemId: String,
    val targetItemId: String?,
    val status: SyncItemStatus,
    val errorCode: String? = null,
)

enum class SyncItemType {
    media,
    contact,
    file,
}

enum class SyncItemStatus {
    synced,
    skipped,
    failed,
    conflicted,
}

