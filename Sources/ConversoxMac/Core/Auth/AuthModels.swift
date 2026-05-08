import Foundation

struct UserProfile: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let tenant: String?
    let role: String?
    let connections: [String]
}

struct PersistedSession: Codable {
    let apiKey: String
    let authSource: String
    let user: UserProfile
}

struct MeResponse: Decodable {
    let ok: Bool
    let user: MeUser
    let conversox: MeConversox?

    func asUserProfile(authSource: String) -> UserProfile {
        UserProfile(
            id: user.id.value,
            name: user.name ?? user.email ?? "Conversox",
            email: user.email ?? "api@system",
            tenant: user.authSource ?? authSource,
            role: user.role,
            connections: conversox?.connections ?? []
        )
    }
}

struct MeUser: Decodable {
    let id: FlexibleString
    let email: String?
    let name: String?
    let role: String?
    let authSource: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case role
        case authSource = "auth_source"
    }
}

struct MeConversox: Decodable {
    let connections: [String]
}

struct FlexibleString: Codable {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = String(int)
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected string or int")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
