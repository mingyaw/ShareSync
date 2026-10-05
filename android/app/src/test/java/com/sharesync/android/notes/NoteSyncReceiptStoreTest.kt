package com.sharesync.android.notes

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import java.io.File
import java.nio.file.Files

class NoteSyncReceiptStoreTest {
    @Test
    fun fileStorePersistsLatestReceiptAcrossReload() {
        val directory = Files.createTempDirectory("sharesync-note-receipt").toFile()
        val file = File(directory, "receipt.json")
        val receipt = NoteSyncReceipt(
            completedAtEpochMillis = 1_800_000_000_000,
            peerDeviceId = "mac-device-001",
            receivedBatchId = "mac-batch-001",
            changedCount = 2,
            conflictCount = 1,
        )

        try {
            FileNoteSyncReceiptStore(file).save(receipt)
            assertEquals(receipt, FileNoteSyncReceiptStore(file).load())
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun fileStoreRejectsUnsupportedReceiptWithoutReplacingIt() {
        val directory = Files.createTempDirectory("sharesync-note-receipt").toFile()
        val file = File(directory, "receipt.json")
        file.writeText(
            """
            {
              "schemaVersion": 99,
              "completedAtEpochMillis": 1800000000000,
              "peerDeviceId": "mac-device-001",
              "receivedBatchId": "mac-batch-001",
              "changedCount": 2,
              "conflictCount": 1
            }
            """.trimIndent(),
        )

        try {
            assertThrows(IllegalArgumentException::class.java) {
                FileNoteSyncReceiptStore(file).load()
            }
            assertEquals(99, org.json.JSONObject(file.readText()).getInt("schemaVersion"))
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun clearRemovesPersistedReceipt() {
        val directory = Files.createTempDirectory("sharesync-note-receipt").toFile()
        val file = File(directory, "receipt.json")
        val store = FileNoteSyncReceiptStore(file)
        val receipt = NoteSyncReceipt(
            completedAtEpochMillis = 1_800_000_000_000,
            peerDeviceId = "mac-device-001",
            receivedBatchId = "mac-batch-001",
            changedCount = 0,
            conflictCount = 0,
        )

        try {
            store.save(receipt)
            store.clear()

            assertEquals(null, FileNoteSyncReceiptStore(file).load())
            store.clear()
        } finally {
            directory.deleteRecursively()
        }
    }
}
