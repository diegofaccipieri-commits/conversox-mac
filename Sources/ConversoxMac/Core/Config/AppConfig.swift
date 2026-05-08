import Foundation

struct AppConfig {
    let serverBaseURL: URL
    let defaultAuthSource: String

    static let shared: AppConfig = {
        let env = ProcessInfo.processInfo.environment

        func requiredURL(_ key: String, fallback: String) -> URL {
            URL(string: env[key] ?? fallback)!
        }

        return AppConfig(
            serverBaseURL: requiredURL("CONVERSOX_SERVER_BASE_URL", fallback: "https://app.imigrando.com"),
            defaultAuthSource: env["CONVERSOX_AUTH_SOURCE"] ?? "imigrando"
        )
    }()
}
