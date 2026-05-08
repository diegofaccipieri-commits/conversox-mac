import Foundation

struct HTTPClient {
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.jsonDecoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.jsonEncoder = encoder
    }

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        session authSession: PersistedSession?,
        body: Encodable? = nil
    ) async throws -> T {
        var request = URLRequest(url: try makeURL(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authSession {
            request.setValue(authSession.apiKey, forHTTPHeaderField: "X-API-Key")
            request.setValue(authSession.authSource, forHTTPHeaderField: "X-Conversox-Auth-Source")
        }
        if let body {
            request.httpBody = try jsonEncoder.encode(AnyEncodable(body))
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpStatus(http.statusCode, body: String(data: data, encoding: .utf8))
        }
        return try jsonDecoder.decode(T.self, from: data)
    }

    func requestNoContent(
        _ path: String,
        method: String,
        session authSession: PersistedSession?,
        body: Encodable? = nil
    ) async throws {
        var request = URLRequest(url: try makeURL(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authSession {
            request.setValue(authSession.apiKey, forHTTPHeaderField: "X-API-Key")
            request.setValue(authSession.authSource, forHTTPHeaderField: "X-Conversox-Auth-Source")
        }
        if let body {
            request.httpBody = try jsonEncoder.encode(AnyEncodable(body))
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpStatus(http.statusCode, body: String(data: data, encoding: .utf8))
        }
    }

    private func makeURL(_ path: String) throws -> URL {
        if let url = URL(string: path), url.scheme != nil {
            return url
        }

        guard let url = URL(string: path, relativeTo: AppConfig.shared.serverBaseURL)?.absoluteURL else {
            throw APIError.invalidURL(path)
        }
        return url
    }
}

enum APIError: Error {
    case invalidURL(String)
    case invalidResponse
    case httpStatus(Int, body: String?)
}

struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        self._encode = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
