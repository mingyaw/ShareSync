import Foundation

public enum MessageAttachmentCandidateProviderError: Error, Equatable, Sendable {
    case invalidMessageRowID
    case invalidStoredPath
    case missingMIMEType
}

public final class SQLiteMessageAttachmentCandidateProvider: MessageAttachmentCandidateProviding {
    private let databaseURL: URL
    private let homeDirectory: URL

    public init(
        databaseURL: URL,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.databaseURL = databaseURL
        self.homeDirectory = homeDirectory
    }

    public func candidates(
        forMessageRowID rowID: Int64
    ) throws -> [MessageAttachmentCandidate] {
        guard rowID > 0 else {
            throw MessageAttachmentCandidateProviderError.invalidMessageRowID
        }
        let schema = try MessageDatabaseSchemaInspector().inspect(databaseURL: databaseURL)
        guard schema.supportsAttachmentPaths else {
            throw MessageBridgeError.unsupportedSchema(
                missing: schema.missingAttachmentPathRequirements
            )
        }
        let rows = try SQLiteReadOnlyDatabase(url: databaseURL).attachmentRows(messageRowID: rowID)
        return try rows.map { row in
            guard let mimeType = row.mimeType?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !mimeType.isEmpty else {
                throw MessageAttachmentCandidateProviderError.missingMIMEType
            }
            return MessageAttachmentCandidate(
                fileURL: try fileURL(forStoredPath: row.filename),
                mimeType: mimeType
            )
        }
    }

    private func fileURL(forStoredPath storedPath: String?) throws -> URL {
        guard let storedPath,
              !storedPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !storedPath.contains("\0") else {
            throw MessageAttachmentCandidateProviderError.invalidStoredPath
        }
        if storedPath.hasPrefix("~/") {
            guard homeDirectory.isFileURL else {
                throw MessageAttachmentCandidateProviderError.invalidStoredPath
            }
            return homeDirectory
                .appendingPathComponent(String(storedPath.dropFirst(2)))
                .standardizedFileURL
        }
        guard storedPath.hasPrefix("/") else {
            throw MessageAttachmentCandidateProviderError.invalidStoredPath
        }
        return URL(fileURLWithPath: storedPath).standardizedFileURL
    }
}
