import Foundation
import XCTest
@testable import ShareSyncNotes

final class NoteCompatibilityTests: XCTestCase {
    func testSharedAndroidFixtureDecodesAndReencodesWithoutChangingJSONContract() throws {
        let fixture = try fixtureData("sample-note-store", extension: "json")
        let codec = NoteJSONCodec()

        let notes = try codec.decode(fixture)

        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes[0].id, "3c348be6-01af-4d16-93cf-ddb1d27de133")
        XCTAssertEqual(notes[0].markdownBody, "# Next\n\nConnect over the local network.")
        XCTAssertEqual(notes[0].revision, try NoteRevision(sequence: 2, deviceId: "android-primary"))
        XCTAssertEqual(notes[0].parentRevision, try NoteRevision(sequence: 1, deviceId: "android-primary"))

        let encoded = try codec.encode(notes)
        XCTAssertEqual(
            try JSONSerialization.jsonObject(with: encoded) as? NSDictionary,
            try JSONSerialization.jsonObject(with: fixture) as? NSDictionary
        )

        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let encodedNotes = try XCTUnwrap(object["notes"] as? [[String: Any]])
        XCTAssertTrue(encodedNotes[0].keys.contains("parentRevision"))
        XCTAssertTrue(encodedNotes[0].keys.contains("deletedAtEpochMillis"))
        XCTAssertTrue(encodedNotes[0].keys.contains("conflictOfNoteId"))
    }

    func testCodecRejectsMissingNullableContractField() throws {
        let fixture = try fixtureData("sample-note-store", extension: "json")
        var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: fixture) as? [String: Any])
        var notes = try XCTUnwrap(object["notes"] as? [[String: Any]])
        notes[0].removeValue(forKey: "conflictOfNoteId")
        object["notes"] = notes

        XCTAssertThrowsError(try NoteJSONCodec().decode(JSONSerialization.data(withJSONObject: object))) {
            XCTAssertEqual($0 as? NoteModelError, .missingRequiredField("conflictOfNoteId"))
        }
    }

    func testSharedSyncBatchFixtureRoundTripsWithoutChangingContract() throws {
        let fixture = try fixtureData("sample-note-sync-batch", extension: "json")
        let codec = NoteSyncBatchCodec()

        let batch = try codec.decode(fixture)
        let encoded = try codec.encode(batch)

        XCTAssertEqual(batch.batchId, "notes-20261004-001")
        XCTAssertEqual(batch.sourceDeviceId, "android-primary")
        XCTAssertEqual(batch.notes.count, 1)
        XCTAssertEqual(
            try JSONSerialization.jsonObject(with: encoded) as? NSDictionary,
            try JSONSerialization.jsonObject(with: fixture) as? NSDictionary
        )
    }

    func testSyncBatchRejectsDuplicateNoteIDs() throws {
        let note = try NoteSyncBatchCodec()
            .decode(fixtureData("sample-note-sync-batch", extension: "json"))
            .notes[0]

        XCTAssertThrowsError(try NoteSyncBatch(
            batchId: "duplicate",
            sourceDeviceId: "android-primary",
            generatedAtEpochMillis: 1,
            notes: [note, note]
        )) {
            XCTAssertEqual(
                $0 as? NoteSyncBatchError,
                .duplicateNoteID("3c348be6-01af-4d16-93cf-ddb1d27de133")
            )
        }
    }

    private func fixtureData(_ name: String, extension fileExtension: String) throws -> Data {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try Data(contentsOf: root
            .appendingPathComponent("shared/fixtures")
            .appendingPathComponent("\(name).\(fileExtension)"))
    }
}
