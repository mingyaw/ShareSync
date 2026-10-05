import Foundation
import XCTest
@testable import ShareSyncNotes

final class NoteSyncReceiptStoreTests: XCTestCase {
    func testFileStorePersistsLatestReceiptAcrossReload() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncNoteReceipt-\(UUID().uuidString)")
        let fileURL = directory.appendingPathComponent("receipt.json")
        let receipt = try NoteSyncReceipt(
            completedAtEpochMillis: 1_800_000_000_000,
            peerDeviceId: "android-primary",
            pulledBatchId: "android-batch-001",
            pushedBatchId: "mac-batch-001",
            changedCount: 2,
            conflictCount: 1
        )

        defer { try? FileManager.default.removeItem(at: directory) }
        try FileNoteSyncReceiptStore(fileURL: fileURL).save(receipt)

        XCTAssertEqual(try FileNoteSyncReceiptStore(fileURL: fileURL).load(), receipt)
    }

    func testFileStoreRejectsUnsupportedReceiptWithoutCrashing() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncNoteReceipt-\(UUID().uuidString)")
        let fileURL = directory.appendingPathComponent("receipt.json")
        let invalidReceipt = """
        {
          "schemaVersion": 99,
          "completedAtEpochMillis": 1800000000000,
          "peerDeviceId": "android-primary",
          "pulledBatchId": "android-batch-001",
          "pushedBatchId": "mac-batch-001",
          "changedCount": 2,
          "conflictCount": 1
        }
        """

        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(invalidReceipt.utf8).write(to: fileURL)

        XCTAssertThrowsError(try FileNoteSyncReceiptStore(fileURL: fileURL).load()) { error in
            XCTAssertEqual(error as? NoteSyncReceiptError, .unsupportedSchemaVersion(99))
        }
    }

    func testClearRemovesPersistedReceipt() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncNoteReceipt-\(UUID().uuidString)")
        let fileURL = directory.appendingPathComponent("receipt.json")
        let store = FileNoteSyncReceiptStore(fileURL: fileURL)
        let receipt = try NoteSyncReceipt(
            completedAtEpochMillis: 1_800_000_000_000,
            peerDeviceId: "android-primary",
            pulledBatchId: "android-batch-001",
            pushedBatchId: "mac-batch-001",
            changedCount: 0,
            conflictCount: 0
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        try store.save(receipt)
        try store.clear()

        XCTAssertNil(try FileNoteSyncReceiptStore(fileURL: fileURL).load())
        XCTAssertNoThrow(try store.clear())
    }
}
