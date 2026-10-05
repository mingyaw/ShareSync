package com.sharesync.android.notes

import org.json.JSONObject
import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.concurrent.ConcurrentHashMap

data class NoteSyncReceipt(
    val schemaVersion: Int = CURRENT_SCHEMA_VERSION,
    val completedAtEpochMillis: Long,
    val peerDeviceId: String,
    val receivedBatchId: String,
    val changedCount: Int,
    val conflictCount: Int,
) {
    init {
        require(schemaVersion == CURRENT_SCHEMA_VERSION) { "Unsupported note receipt schema: $schemaVersion" }
        require(completedAtEpochMillis >= 0) { "Completion time must not be negative" }
        require(peerDeviceId.isNotBlank() && receivedBatchId.isNotBlank()) { "Receipt identifiers are required" }
        require(changedCount >= 0 && conflictCount >= 0) { "Receipt counts must not be negative" }
    }

    companion object {
        const val CURRENT_SCHEMA_VERSION = 1
    }
}

interface NoteSyncReceiptStore {
    fun load(): NoteSyncReceipt?
    fun save(receipt: NoteSyncReceipt)
    fun clear()
}

class InMemoryNoteSyncReceiptStore(initialReceipt: NoteSyncReceipt? = null) : NoteSyncReceiptStore {
    private var receipt = initialReceipt

    @Synchronized
    override fun load(): NoteSyncReceipt? = receipt

    @Synchronized
    override fun save(receipt: NoteSyncReceipt) {
        this.receipt = receipt
    }

    @Synchronized
    override fun clear() {
        receipt = null
    }
}

class FileNoteSyncReceiptStore(private val file: File) : NoteSyncReceiptStore {
    private val lock = fileLocks.computeIfAbsent(file.absoluteFile.normalize().path) { Any() }

    override fun load(): NoteSyncReceipt? = synchronized(lock) {
        if (!file.exists()) return@synchronized null
        decode(file.readText())
    }

    override fun save(receipt: NoteSyncReceipt) = synchronized(lock) {
        file.parentFile?.mkdirs()
        val temporary = File(file.parentFile, "${file.name}.tmp")
        temporary.writeText(encode(receipt))
        try {
            Files.move(
                temporary.toPath(),
                file.toPath(),
                StandardCopyOption.REPLACE_EXISTING,
                StandardCopyOption.ATOMIC_MOVE,
            )
        } catch (_: Exception) {
            Files.move(temporary.toPath(), file.toPath(), StandardCopyOption.REPLACE_EXISTING)
        }
        Unit
    }

    override fun clear() = synchronized(lock) {
        if (file.exists() && !file.delete()) {
            error("Unable to clear note sync receipt")
        }
    }

    private fun encode(receipt: NoteSyncReceipt): String = JSONObject()
        .put("schemaVersion", receipt.schemaVersion)
        .put("completedAtEpochMillis", receipt.completedAtEpochMillis)
        .put("peerDeviceId", receipt.peerDeviceId)
        .put("receivedBatchId", receipt.receivedBatchId)
        .put("changedCount", receipt.changedCount)
        .put("conflictCount", receipt.conflictCount)
        .toString(2)

    private fun decode(json: String): NoteSyncReceipt {
        val payload = JSONObject(json)
        return NoteSyncReceipt(
            schemaVersion = payload.getInt("schemaVersion"),
            completedAtEpochMillis = payload.getLong("completedAtEpochMillis"),
            peerDeviceId = payload.getString("peerDeviceId"),
            receivedBatchId = payload.getString("receivedBatchId"),
            changedCount = payload.getInt("changedCount"),
            conflictCount = payload.getInt("conflictCount"),
        )
    }

    companion object {
        private val fileLocks = ConcurrentHashMap<String, Any>()

        fun defaultFile(filesDir: File): File =
            File(File(filesDir, "ShareSync"), "note-sync-receipt-v1.json")
    }
}
