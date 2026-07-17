import XCTest
@testable import SSHProxyCore

final class ProfileValidationTests: XCTestCase {
    func testValidSSHConfigProfile() throws {
        let profile = TunnelProfile(name: "Qiniu", sshHost: "qiniu", localPort: 17890)
        XCTAssertNoThrow(try ProfileValidator.validate(profile))
    }

    func testDirectAuthenticationRequiresUsername() {
        let profile = TunnelProfile(
            name: "Missing user",
            sshHost: "example.test",
            authentication: .password
        )
        XCTAssertThrowsError(try ProfileValidator.validate(profile)) { error in
            XCTAssertEqual(error as? ProfileValidationError, .missingUsername)
        }
    }

    func testKeyMustExist() {
        let profile = TunnelProfile(
            name: "Key",
            sshHost: "example.test",
            username: "user",
            authentication: .keyFile,
            identityFile: "/missing/key"
        )
        XCTAssertThrowsError(try ProfileValidator.validate(profile, fileExists: { _ in false })) { error in
            XCTAssertEqual(error as? ProfileValidationError, .identityFileNotFound)
        }
    }

    func testRejectsPublicBindAddress() {
        var profile = TunnelProfile(name: "Unsafe bind", sshHost: "example.test")
        profile.localHost = "0.0.0.0"
        XCTAssertThrowsError(try ProfileValidator.validate(profile)) { error in
            XCTAssertEqual(error as? ProfileValidationError, .invalidLocalHost)
        }
    }

    func testRemoteProxyRequiresRemotePort() {
        let profile = TunnelProfile(
            name: "Remote proxy",
            sshHost: "example.test",
            mode: .remoteProxy,
            remotePort: 0
        )
        XCTAssertThrowsError(try ProfileValidator.validate(profile)) { error in
            XCTAssertEqual(error as? ProfileValidationError, .invalidRemotePort)
        }
    }
}
