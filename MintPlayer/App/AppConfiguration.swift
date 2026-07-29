import Foundation

enum AppConfiguration {
#if DEBUG
    static let displayName = "Mint Player Debug"
    static let supportDirectoryName = "MintPlayer-Debug"
    static let userDefaultsPrefix = "mintPlayer.debug"
#else
    static let displayName = "Mint Player"
    static let supportDirectoryName = "MintPlayer"
    static let userDefaultsPrefix = "mintPlayer"
#endif

    static func userDefaultsKey(_ key: String) -> String {
        "\(userDefaultsPrefix).\(key)"
    }

    static var displayVersion: String {
        let displayVersion = Bundle.main.object(forInfoDictionaryKey: "MintDisplayVersion") as? String
        let trimmedDisplayVersion = displayVersion?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedDisplayVersion, !trimmedDisplayVersion.isEmpty {
            return trimmedDisplayVersion
        }

        let bundleVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String
        let trimmedBundleVersion = bundleVersion?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedBundleVersion, !trimmedBundleVersion.isEmpty {
            return trimmedBundleVersion
        }
        return "0.0.0"
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
