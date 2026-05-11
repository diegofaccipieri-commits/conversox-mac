import AppKit
import SwiftUI

// Carregador de imagens autenticado que injeta X-API-Key + X-Conversox-Auth-Source
// nas requisições. Substitui AsyncImage para endpoints protegidos como
// avatar.php e media.php que retornam 401 sem essas headers.

@MainActor
final class AuthedImageLoader: ObservableObject {
    static let shared = AuthedImageLoader()

    private var memoryCache: [String: NSImage] = [:]
    private var inflight: [String: Task<NSImage?, Never>] = [:]
    private let diskRoot: URL
    private let session: URLSession

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.diskRoot = caches.appendingPathComponent("com.diego.conversoxmac/images", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskRoot, withIntermediateDirectories: true)

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    func cached(for key: String) -> NSImage? {
        memoryCache[key]
    }

    func load(url: URL, apiKey: String?, authSource: String?) async -> NSImage? {
        let key = cacheKey(for: url)

        if let img = memoryCache[key] {
            return img
        }

        if let inflightTask = inflight[key] {
            return await inflightTask.value
        }

        let task = Task<NSImage?, Never> { [weak self] in
            guard let self else { return nil }

            // Disk cache
            let diskURL = self.diskRoot.appendingPathComponent(key)
            if let data = try? Data(contentsOf: diskURL), let img = NSImage(data: data) {
                await MainActor.run { self.memoryCache[key] = img }
                return img
            }

            // Network with auth headers
            var req = URLRequest(url: url)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            if let apiKey, !apiKey.isEmpty {
                req.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
            }
            if let authSource, !authSource.isEmpty {
                req.setValue(authSource, forHTTPHeaderField: "X-Conversox-Auth-Source")
            }
            req.setValue("image/*", forHTTPHeaderField: "Accept")

            do {
                let (data, response) = try await self.session.data(for: req)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                      let img = NSImage(data: data) else {
                    return nil
                }
                try? data.write(to: diskURL, options: .atomic)
                await MainActor.run { self.memoryCache[key] = img }
                return img
            } catch {
                return nil
            }
        }

        inflight[key] = task
        let result = await task.value
        inflight[key] = nil
        return result
    }

    private func cacheKey(for url: URL) -> String {
        let raw = url.absoluteString
        // sha-light: simple djb2 hash p/ filename safe
        var h: UInt64 = 5381
        for b in raw.utf8 { h = (h &* 33) &+ UInt64(b) }
        return String(h, radix: 16)
    }
}

struct AuthedImage<Placeholder: View, Fallback: View>: View {
    let url: URL?
    let contentMode: ContentMode
    let placeholder: () -> Placeholder
    let fallback: () -> Fallback

    @EnvironmentObject private var sessionStore: SessionStore
    @State private var image: NSImage?
    @State private var failed = false

    init(
        url: URL?,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder fallback: @escaping () -> Fallback
    ) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder
        self.fallback = fallback
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if failed || url == nil {
                fallback()
            } else {
                placeholder()
            }
        }
        .task(id: url?.absoluteString ?? "") {
            await reload()
        }
    }

    private func reload() async {
        self.image = nil
        self.failed = false
        guard let url else { return }
        let key = url.absoluteString
        if let cached = AuthedImageLoader.shared.cached(for: cacheKeyHash(key)) {
            self.image = cached
            return
        }
        let apiKey = sessionStore.session?.apiKey
        let authSource = sessionStore.session?.authSource
        let loaded = await AuthedImageLoader.shared.load(url: url, apiKey: apiKey, authSource: authSource)
        guard !Task.isCancelled else { return }
        if let loaded {
            self.image = loaded
            self.failed = false
        } else {
            self.failed = true
        }
    }

    private func cacheKeyHash(_ s: String) -> String {
        var h: UInt64 = 5381
        for b in s.utf8 { h = (h &* 33) &+ UInt64(b) }
        return String(h, radix: 16)
    }
}

extension AuthedImage where Placeholder == AnyView, Fallback == AnyView {
    init(url: URL?, contentMode: ContentMode = .fill) {
        self.init(
            url: url,
            contentMode: contentMode,
            placeholder: { AnyView(Rectangle().fill(CXColor.surface2)) },
            fallback: { AnyView(Rectangle().fill(CXColor.surface2)) }
        )
    }
}
