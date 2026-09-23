import Foundation

struct MacDeviceIdentity {
    private static let key = "sharesync.mac.target-device-id"

    static func persistentID(defaults: UserDefaults = .standard) -> String {
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            return existing
        }

        let value = "mac-\(UUID().uuidString.lowercased())"
        defaults.set(value, forKey: key)
        return value
    }
}
