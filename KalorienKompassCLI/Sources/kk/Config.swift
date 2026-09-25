import Foundation

enum Config {
    /// API-Key aus Umgebungsvariable CLAUDE_API_KEY oder ~/.config/kk/config.json
    static func resolveAPIKey() -> String? {
        if let key = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"], !key.isEmpty {
            return key
        }
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/kk/config.json")
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let key = json["apiKey"], !key.isEmpty else {
            return nil
        }
        return key
    }
}
