import Foundation
import CryptoKit

actor MediaCache {
    static let shared = MediaCache()

    private let root: URL
    private var inflight: [String: Task<URL?, Never>] = [:]
    private let session: URLSession

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.root = caches.appendingPathComponent("com.diego.conversoxmac/media", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 180
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpMaximumConnectionsPerHost = 6
        self.session = URLSession(configuration: config)
    }

    /// Returns local file URL for a remote authed URL. Caches on disk.
    /// `ttl` em segundos: nil = nunca expira. Para avatares use 24*3600.
    func localFile(
        for url: URL,
        apiKey: String?,
        authSource: String?,
        ttl: TimeInterval? = nil
    ) async -> URL? {
        let key = Self.cacheKey(for: url)
        let localURL = root.appendingPathComponent(key)

        if FileManager.default.fileExists(atPath: localURL.path) {
            if let ttl {
                if let attrs = try? FileManager.default.attributesOfItem(atPath: localURL.path),
                   let modDate = attrs[.modificationDate] as? Date,
                   Date().timeIntervalSince(modDate) < ttl {
                    return localURL
                }
            } else {
                return localURL
            }
        }

        if let existing = inflight[key] {
            return await existing.value
        }

        let task = Task<URL?, Never> { [session, root] in
            var req = URLRequest(url: url)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            if let apiKey, !apiKey.isEmpty {
                req.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
            }
            if let authSource, !authSource.isEmpty {
                req.setValue(authSource, forHTTPHeaderField: "X-Conversox-Auth-Source")
            }
            do {
                let (data, response) = try await session.data(for: req)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    return nil
                }
                let target = root.appendingPathComponent(key)
                try data.write(to: target, options: .atomic)
                return target
            } catch {
                return nil
            }
        }

        inflight[key] = task
        let result = await task.value
        inflight[key] = nil
        return result
    }

    func evictAll() {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func diskUsageBytes() -> Int64 {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        return items.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + Int64(size)
        }
    }

    static func cacheKey(for url: URL) -> String {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8))
        let hex = hash.compactMap { String(format: "%02x", $0) }.joined()
        let ext = url.pathExtension
        return ext.isEmpty ? hex : "\(hex).\(ext)"
    }
}
