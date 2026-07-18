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
            mode: .localForward,
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

    func testRemoteForwardArguments() {
        let profile = TunnelProfile(
            name: "Expose local service",
            sshHost: "server",
            mode: .remoteForward,
            localPort: 3000,
            remoteHost: "127.0.0.1",
            remotePort: 23000
        )

        let arguments = SSHArgumentsBuilder.arguments(for: profile)

        XCTAssertTrue(arguments.contains("-R"))
        XCTAssertTrue(arguments.contains("127.0.0.1:23000:127.0.0.1:3000"))
    }

    func testAdvancedOptionsAndCertificateArguments() {
        let profile = TunnelProfile(
            name: "Advanced",
            sshHost: "example.test",
            username: "deploy",
            authentication: .keyFile,
            identityFile: "/keys/id_ed25519",
            certificateFile: "/keys/id_ed25519-cert.pub",
            proxyJump: "bastion",
            compression: true,
            connectTimeout: 20,
            serverAliveInterval: 45,
            serverAliveCountMax: 5
        )

        let arguments = SSHArgumentsBuilder.arguments(for: profile)

        XCTAssertTrue(arguments.contains("-C"))
        XCTAssertTrue(arguments.contains("-J"))
        XCTAssertTrue(arguments.contains("bastion"))
        XCTAssertTrue(arguments.contains("ConnectTimeout=20"))
        XCTAssertTrue(arguments.contains("ServerAliveInterval=45"))
        XCTAssertTrue(arguments.contains("ServerAliveCountMax=5"))
        XCTAssertTrue(arguments.contains("CertificateFile=/keys/id_ed25519-cert.pub"))
        XCTAssertEqual(arguments.last, "deploy@example.test")
    }
}
