import Foundation

public protocol MessageAttributedBodyDecoding: Sendable {
    func decodeText(from data: Data) -> String?
}

public struct SecureKeyedAttributedBodyDecoder: MessageAttributedBodyDecoding {
    public init() {}

    public func decodeText(from data: Data) -> String? {
        guard let attributed = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: NSAttributedString.self,
            from: data
        ) else {
            return nil
        }
        return attributed.string.isEmpty ? nil : attributed.string
    }
}
