import Foundation

enum AppConfiguration {
#if DEBUG
    static let displayName = "Mint Player Debug"
    static let buildFlavor = "Debug"
    static let supportDirectoryName = "MintPlayer-Debug"
    static let userDefaultsPrefix = "mintPlayer.debug"
#else
    static let displayName = "Mint Player"
    static let buildFlavor = "Release"
    static let supportDirectoryName = "MintPlayer"
    static let userDefaultsPrefix = "mintPlayer"
#endif

    static func userDefaultsKey(_ key: String) -> String {
        "\(userDefaultsPrefix).\(key)"
    }

    static var versionTag: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let trimmedVersion = version?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedVersion, !trimmedVersion.isEmpty else {
            return "v0.0.0"
        }
        let tagVersion = trimmedVersion.hasPrefix("v") ? trimmedVersion : "v\(trimmedVersion)"
        return "\(tagVersion)-\(buildFlavor)"
    }

    static func applicationSupportDirectory() throws -> URL {
        let supportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = supportURL.appendingPathComponent(supportDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
