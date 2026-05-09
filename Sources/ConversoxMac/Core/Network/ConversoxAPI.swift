import Foundation

struct ConversoxError: Error, Sendable {
    enum Kind {
        case invalidURL
        case invalidResponse
        case transport
        case backend
    }

    let kind: Kind
    let httpStatus: Int?
    let backendError: String?
    let rawBody: String?
    let userMessage: String
    let recommendedAction: String

    static func invalidURL(_ path: String) -> ConversoxError {
        ConversoxError(
            kind: .invalidURL,
            httpStatus: nil,
            backendError: nil,
            rawBody: path,
            userMessage: "URL invalida para a API do Conversox.",
            recommendedAction: "Verifique a configuracao de base URL e tenant."
        )
    }

    static func invalidResponse() -> ConversoxError {
        ConversoxError(
            kind: .invalidResponse,
            httpStatus: nil,
            backendError: nil,
            rawBody: nil,
            userMessage: "Resposta invalida do servidor.",
            recommendedAction: "Tente novamente. Se persistir, verificar logs do backend."
        )
    }

    static func transport(_ error: Error) -> ConversoxError {
        ConversoxError(
            kind: .transport,
            httpStatus: nil,
            backendError: nil,
            rawBody: String(describing: error),
            userMessage: "Falha de conexao com o servidor.",
            recommendedAction: "Verifique rede, VPN e disponibilidade do servidor."
        )
    }

    static func backend(httpStatus: Int, backendError: String?, rawBody: String?) -> ConversoxError {
        let mapping = mappedMessage(for: backendError, status: httpStatus)
        return ConversoxError(
            kind: .backend,
            httpStatus: httpStatus,
            backendError: backendError,
            rawBody: rawBody,
            userMessage: mapping.userMessage,
            recommendedAction: mapping.recommendedAction
        )
    }

    private static func mappedMessage(for backendError: String?, status: Int) -> (userMessage: String, recommendedAction: String) {
        switch backendError {
        case "not_authenticated":
            return ("Sessao ou chave de API invalida.", "Refaca login com uma chave valida.")
        case "not_authorized":
            return ("Usuario sem permissao para acessar o Conversox.", "Solicite permissao para seu usuario.")
        case "access_denied_connection", "forbidden_connection":
            return ("Sem permissao para acessar esta conexao.", "Atualize ACL do usuario ou use outra conexao.")
        case "forbidden_not_assigned":
            return ("Conversa nao atribuida para este usuario restrito.", "Atribua a conversa ao usuario antes de abrir/enviar.")
        case "csrf_token_invalid":
            return ("Token CSRF invalido para envio por sessao.", "Renove a sessao e tente novamente.")
        case "file_too_large", "file_too_large_for_php":
            return ("Arquivo acima do limite permitido.", "Envie um arquivo menor que 16 MB.")
        case "media_expired_not_cached":
            return ("Midia expirada e sem cache disponivel.", "Solicite reenvio da midia ao contato.")
        case "send_failed":
            return ("Falha no envio da mensagem.", "Tente novamente em alguns segundos.")
        case "ai_service_unreachable":
            return ("Servico de IA indisponivel no momento.", "Tente novamente mais tarde.")
        default:
            if status == 401 {
                return ("Nao autenticado na API.", "Refaca login.")
            }
            if status == 403 {
                return ("Acesso negado pela API.", "Verifique ACL/role do usuario.")
            }
            if status == 413 {
                return ("Payload acima do limite.", "Reduza o tamanho do arquivo.")
            }
            if status >= 500 {
                return ("Erro interno do backend Conversox.", "Tente novamente e confira logs do servidor.")
            }
            return ("Requisicao rejeitada pela API.", "Revise payload e tente novamente.")
        }
    }
}

struct ConversoxHTTPResponse<T: Sendable>: Sendable {
    let value: T
    let statusCode: Int
    let headers: [String: String]
}

struct ConversoxBinaryResponse: Sendable {
    let data: Data
    let mimeType: String?
    let statusCode: Int
    let headers: [String: String]
}

struct MultipartFilePart: Sendable {
    let fieldName: String
    let fileName: String
    let mimeType: String
    let data: Data
}

actor ConversoxAPI {
    enum Route {
        case me
        case chats
        case messages
        case send
        case actions
        case poll
        case customPrefixed(String)
        case absolutePath(String)
    }

    private struct APIErrorEnvelope: Decodable {
        let error: String?
        let detail: String?
        let message: String?
    }

    private let urlSession: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.jsonDecoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.jsonEncoder = encoder
    }

    func getJSON<T: Decodable & Sendable>(
        _ route: Route,
        queryItems: [URLQueryItem] = [],
        session authSession: PersistedSession?,
        timeout: TimeInterval = 15
    ) async throws -> ConversoxHTTPResponse<T> {
        var request = try makeRequest(
            route: route,
            queryItems: queryItems,
            method: "GET",
            authSession: authSession,
            timeout: timeout
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let payload = try await execute(request)
        let value = try decode(T.self, from: payload.data)
        return ConversoxHTTPResponse(value: value, statusCode: payload.response.statusCode, headers: normalizedHeaders(payload.response))
    }

    func postJSON<T: Decodable & Sendable, Body: Encodable & Sendable>(
        _ route: Route,
        body: Body,
        queryItems: [URLQueryItem] = [],
        session authSession: PersistedSession?,
        timeout: TimeInterval = 30
    ) async throws -> ConversoxHTTPResponse<T> {
        var request = try makeRequest(
            route: route,
            queryItems: queryItems,
            method: "POST",
            authSession: authSession,
            timeout: timeout
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try jsonEncoder.encode(AnyEncodable(body))
        let payload = try await execute(request)
        let value = try decode(T.self, from: payload.data)
        return ConversoxHTTPResponse(value: value, statusCode: payload.response.statusCode, headers: normalizedHeaders(payload.response))
    }

    func postJSONNoContent<Body: Encodable & Sendable>(
        _ route: Route,
        body: Body,
        queryItems: [URLQueryItem] = [],
        session authSession: PersistedSession?,
        timeout: TimeInterval = 30
    ) async throws -> ConversoxHTTPResponse<Data> {
        var request = try makeRequest(
            route: route,
            queryItems: queryItems,
            method: "POST",
            authSession: authSession,
            timeout: timeout
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try jsonEncoder.encode(AnyEncodable(body))
        let payload = try await execute(request)
        return ConversoxHTTPResponse(value: payload.data, statusCode: payload.response.statusCode, headers: normalizedHeaders(payload.response))
    }

    func postMultipart<T: Decodable & Sendable>(
        _ route: Route,
        fields: [String: String],
        files: [MultipartFilePart],
        queryItems: [URLQueryItem] = [],
        session authSession: PersistedSession?,
        timeout: TimeInterval = 60
    ) async throws -> ConversoxHTTPResponse<T> {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = try makeRequest(
            route: route,
            queryItems: queryItems,
            method: "POST",
            authSession: authSession,
            timeout: timeout
        )
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = buildMultipartBody(fields: fields, files: files, boundary: boundary)
        let payload = try await execute(request)
        let value = try decode(T.self, from: payload.data)
        return ConversoxHTTPResponse(value: value, statusCode: payload.response.statusCode, headers: normalizedHeaders(payload.response))
    }

    func getBinary(
        _ route: Route,
        queryItems: [URLQueryItem] = [],
        session authSession: PersistedSession?,
        timeout: TimeInterval = 60
    ) async throws -> ConversoxBinaryResponse {
        var request = try makeRequest(
            route: route,
            queryItems: queryItems,
            method: "GET",
            authSession: authSession,
            timeout: timeout
        )
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        let payload = try await execute(request)
        return ConversoxBinaryResponse(
            data: payload.data,
            mimeType: payload.response.mimeType,
            statusCode: payload.response.statusCode,
            headers: normalizedHeaders(payload.response)
        )
    }

    private func execute(_ request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw ConversoxError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ConversoxError.invalidResponse()
        }

        guard (200..<300).contains(http.statusCode) else {
            let rawBody = String(data: data, encoding: .utf8)
            let envelope = try? decode(APIErrorEnvelope.self, from: data)
            throw ConversoxError.backend(httpStatus: http.statusCode, backendError: envelope?.error, rawBody: rawBody)
        }
        return (data, http)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try jsonDecoder.decode(type, from: data)
        } catch {
            throw ConversoxError.backend(httpStatus: 200, backendError: "decode_failed", rawBody: String(data: data, encoding: .utf8))
        }
    }

    private func makeRequest(
        route: Route,
        queryItems: [URLQueryItem],
        method: String,
        authSession: PersistedSession?,
        timeout: TimeInterval
    ) throws -> URLRequest {
        let path = Self.resolvePath(route, tenant: authSession?.authSource ?? AppConfig.shared.defaultAuthSource)
        let url = try makeURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        if let authSession {
            request.setValue(authSession.apiKey, forHTTPHeaderField: "X-API-Key")
            request.setValue(authSession.authSource, forHTTPHeaderField: "X-Conversox-Auth-Source")
        }
        return request
    }

    private func makeURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        if let absolute = URL(string: path), absolute.scheme != nil {
            return absolute
        }
        guard var components = URLComponents(url: AppConfig.shared.serverBaseURL, resolvingAgainstBaseURL: false) else {
            throw ConversoxError.invalidURL(path)
        }
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let finalURL = components.url else {
            throw ConversoxError.invalidURL(path)
        }
        return finalURL
    }

    nonisolated func resolvedPath(for route: Route, tenant: String) -> String {
        Self.resolvePath(route, tenant: tenant)
    }

    private static func resolvePath(_ route: Route, tenant: String) -> String {
        let normalizedTenant = tenant.lowercased() == "welcome" ? "welcome" : "imigrando"
        let prefix = normalizedTenant == "welcome" ? "/Welcome/Conversox/api" : "/Conversox/api"

        switch route {
        case .me:
            return "/api/me.php"
        case .chats:
            return "\(prefix)/chats.php"
        case .messages:
            return "\(prefix)/messages.php"
        case .send:
            return "\(prefix)/send.php"
        case .actions:
            return "\(prefix)/actions.php"
        case .poll:
            return "\(prefix)/poll.php"
        case .customPrefixed(let relative):
            let clean = relative.hasPrefix("/") ? relative : "/\(relative)"
            return "\(prefix)\(clean)"
        case .absolutePath(let path):
            return path.hasPrefix("/") ? path : "/\(path)"
        }
    }

    private func buildMultipartBody(fields: [String: String], files: [MultipartFilePart], boundary: String) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        for (key, value) in fields {
            body.append("--\(boundary)\(lineBreak)")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\(lineBreak)\(lineBreak)")
            body.append("\(value)\(lineBreak)")
        }

        for file in files {
            body.append("--\(boundary)\(lineBreak)")
            body.append("Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(file.fileName)\"\(lineBreak)")
            body.append("Content-Type: \(file.mimeType)\(lineBreak)\(lineBreak)")
            body.append(file.data)
            body.append(lineBreak)
        }

        body.append("--\(boundary)--\(lineBreak)")
        return body
    }

    private func normalizedHeaders(_ response: HTTPURLResponse) -> [String: String] {
        var output: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            let headerKey = String(describing: key)
            let headerValue = String(describing: value)
            output[headerKey] = headerValue
        }
        return output
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
