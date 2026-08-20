import Foundation

func fixtureData(_ name: String, extension fileExtension: String) throws -> Data {
    let testFileURL = URL(fileURLWithPath: #filePath)
    let repositoryRoot = testFileURL
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let url = repositoryRoot
        .appendingPathComponent("shared")
        .appendingPathComponent("fixtures")
        .appendingPathComponent("\(name).\(fileExtension)")

    guard FileManager.default.fileExists(atPath: url.path) else {
        throw FixtureError.missing(name: "\(name).\(fileExtension)")
    }
    return try Data(contentsOf: url)
}

enum FixtureError: Error {
    case missing(name: String)
}
