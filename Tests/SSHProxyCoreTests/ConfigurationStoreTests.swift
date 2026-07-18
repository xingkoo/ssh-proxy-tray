import XCTest
@testable import SSHProxyCore

final class ConfigurationStoreTests: XCTestCase {
    func testRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ConfigurationStore(baseDirectory: directory)
        let profile = TunnelProfile(name: "Qiniu", sshHost: "qiniu", localPort: 17890)
        let expected = AppConfiguration(selectedProfileID: profile.id, profiles: [profile])

        try store.save(expected)
        let actual = try store.load()

        XCTAssertEqual(actual, expected)
        let attributes = try FileManager.default.attributesOfItem(atPath: store.configurationURL.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    func testDecodesLegacyRemoteProxyMode() throws {
        let data = Data("\"remoteProxy\"".utf8)
        XCTAssertEqual(try JSONDecoder().decode(TunnelMode.self, from: data), .localForward)
    }
}
