import Foundation

@MainActor
final class KeychainStore {
    static let shared = KeychainStore()
    private let directoryName = "ConversoxMac"

    private init() {}

    func set(_ value: Data, for key: String) throws {
        let url = try fileURL(for: key)
        try value.write(to: url, options: [.atomic, .completeFileProtection])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    func get(for key: String) throws -> Data? {
        let url = try fileURL(for: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func delete(for key: String) {
        guard let url = try? fileURL(for: key) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func directoryURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func fileURL(for key: String) throws -> URL {
        let dir = try directoryURL()
        let safe = key.replacingOccurrences(of: "/", with: "_")
        return dir.appendingPathComponent("\(safe).bin")
    }

}

enum KeychainError: Error {
    case unhandled(OSStatus)
}
