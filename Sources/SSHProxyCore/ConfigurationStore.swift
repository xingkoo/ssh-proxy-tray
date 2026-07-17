import Foundation

public final class ConfigurationStore {
    public static let directoryName = "SSH Proxy Tray"
    public static let fileName = "profiles.json"

    public let configurationURL: URL

    public init(baseDirectory: URL? = nil) {
        let directory: URL
        if let baseDirectory {
            directory = baseDirectory
        } else {
            let applicationSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            directory = applicationSupport.appendingPathComponent(Self.directoryName, isDirectory: true)
        }
        configurationURL = directory.appendingPathComponent(Self.fileName)
    }

    public func load() throws -> AppConfiguration {
        guard FileManager.default.fileExists(atPath: configurationURL.path) else {
            return AppConfiguration()
        }
        let data = try Data(contentsOf: configurationURL)
        return try JSONDecoder().decode(AppConfiguration.self, from: data)
    }

    public func save(_ configuration: AppConfiguration) throws {
        let directory = configurationURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(configuration)
        try data.write(to: configurationURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: configurationURL.path
        )
    }
}
