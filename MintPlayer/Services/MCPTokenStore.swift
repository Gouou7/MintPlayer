import Foundation
import Security

enum MCPTokenStore {
    private static let directoryName = "MCP"
    private static let fileName = "access-token"

    static func loadOrCreate() throws -> String {
        let url = try tokenURL()
        if FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            guard let token = String(data: data, encoding: .utf8), isValid(token) else {
                throw TokenError.invalid
            }
            return token
        }
        let token = try generate()
        try save(token, to: url)
        return token
    }

    static func rotate() throws -> String {
        let url = try tokenURL()
        let token = try generate()
        try save(token, to: url)
        return token
    }

    private static func tokenURL() throws -> URL {
        let directory = try AppConfiguration.applicationSupportDirectory()
            .appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        return directory.appendingPathComponent(fileName)
    }

    private static func save(_ token: String, to url: URL) throws {
        try Data(token.utf8).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private static func isValid(_ token: String) -> Bool {
        let characters = token.utf8
        return characters.count == 43 && characters.allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0)
                || $0 == 45 || $0 == 95
        }
    }

    private static func generate() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecAllocate))
        }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private enum TokenError: LocalizedError {
        case invalid

        var errorDescription: String? { L10n.current(.mcpTokenInvalid) }
    }
}
