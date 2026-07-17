import XCTest
@testable import SSHProxyCore

final class SSHArgumentsBuilderTests: XCTestCase {
    func testSSHConfigSOCKSArguments() {
        let profile = TunnelProfile(
            name: "Qiniu",
            sshHost: "qiniu",
            authentication: .sshConfig,
            mode: .socks5,
            localPort: 17890
        )

        let arguments = SSHArgumentsBuilder.arguments(for: profile)

        XCTAssertTrue(arguments.contains("127.0.0.1:17890"))
        XCTAssertTrue(arguments.contains("BatchMode=yes"))
        XCTAssertEqual(arguments.last, "qiniu")
        XCTAssertFalse(arguments.contains("-L"))
    }

    func testKeyFileRemoteProxyArguments() {
        let profile = TunnelProfile(
            name: "Forwarded proxy",
            sshHost: "example.test",
            sshPort: 2202,
            username: "deploy",
            authentication: .keyFile,
            identityFile: "~/.ssh/id_ed25519",
            mode: .remoteProxy,
            localPort: 8080,
            remoteHost: "127.0.0.1",
            remotePort: 3128
        )

        let arguments = SSHArgumentsBuilder.arguments(for: profile)

        XCTAssertTrue(arguments.contains("127.0.0.1:8080:127.0.0.1:3128"))
        XCTAssertTrue(arguments.contains("IdentitiesOnly=yes"))
        XCTAssertTrue(arguments.contains(NSString(string: "~/.ssh/id_ed25519").expandingTildeInPath))
        XCTAssertEqual(arguments.suffix(3), ["-p", "2202", "deploy@example.test"])
    }

    func testPasswordIsNeverAnArgument() {
        let profile = TunnelProfile(
            name: "Password server",
            sshHost: "example.test",
            username: "user",
            authentication: .password,
            mode: .socks5
        )

        let arguments = SSHArgumentsBuilder.arguments(for: profile)

        XCTAssertTrue(arguments.contains("PubkeyAuthentication=no"))
        XCTAssertEqual(arguments.last, "user@example.test")
        XCTAssertFalse(arguments.joined(separator: " ").contains("password="))
    }
}
