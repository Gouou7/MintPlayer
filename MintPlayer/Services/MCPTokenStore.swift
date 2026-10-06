import Foundation
import Security

@MainActor
enum MCPTokenStore {
    private static let configurationKey = "mcp.accessToken"
    private static var persistenceStore: LibraryPersistenceStore?
    private static let directoryName = "MCP"
    private static let fileName = "access-token"

    static func loadOrCreate() throws -> String {
        let store = try database()
        if let token = try store.configurationValue(for: configurationKey) {
            guard isValid(token) else { throw TokenError.invalid }
            removeLegacyToken()
            return token
        }
        let token = try loadLegacyToken() ?? generate()
        try store.setConfigurationValue(token, for: configurationKey)
        removeLegacyToken()
        return token
    }

    static func rotate() throws -> String {
        let store = try database()
        let token = try generate()
        try store.setConfigurationValue(token, for: configurationKey)
        removeLegacyToken()
        return token
    }

    private static func database() throws -> LibraryPersistenceStore {
        if let persistenceStore { return persistenceStore }
        let store = try LibraryPersistenceStore()
        persistenceStore = store
        return store
    }

    private static func legacyTokenURL() throws -> URL {
        try AppConfiguration.applicationSupportDirectory()
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName)
    }

    private static func loadLegacyToken() throws -> String? {
        let url = try legacyTokenURL()
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        guard try fileManager.attributesOfItem(atPath: url.deletingLastPathComponent().path)[.type] as? FileAttributeType == .typeDirectory,
              try fileManager.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType == .typeRegular else {
            throw TokenError.invalid
        }
        let data = try Data(contentsOf: url)
        guard let token = String(data: data, encoding: .utf8), isValid(token) else { throw TokenError.invalid }
        return token
    }

    private static func removeLegacyToken() {
        // The database write must commit first; cleanup failure is retried on the next access.
        guard let url = try? legacyTokenURL() else { return }
        let fileManager = FileManager.default
        let directory = url.deletingLastPathComponent()
        guard (try? fileManager.attributesOfItem(atPath: directory.path)[.type] as? FileAttributeType) == .typeDirectory else { return }
        do {
            if (try? fileManager.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType) == .typeRegular {
                try fileManager.removeItem(at: url)
            }
            if try fileManager.contentsOfDirectory(atPath: directory.path).isEmpty {
                try fileManager.removeItem(at: directory)
            }
        } catch {
            print("Could not remove the legacy MCP token file.")
        }
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
