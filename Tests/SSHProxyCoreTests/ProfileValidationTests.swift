import XCTest
@testable import SSHProxyCore

final class ProfileValidationTests: XCTestCase {
    func testDefaultPortAvoidsCommonProxyPorts() {
        XCTAssertEqual(TunnelProfile().localPort, 18080)
        XCTAssertNil(TunnelProfile().httpProxyPort)
    }

    func testValidatesOptionalHTTPProxyPort() throws {
        var profile = TunnelProfile(
            name: "Dual proxy",
            sshHost: "example.test",
            localPort: 18080,
            httpProxyPort: 18081
        )
        XCTAssertNoThrow(try ProfileValidator.validate(profile))

        profile.httpProxyPort = 18080
        XCTAssertThrowsError(try ProfileValidator.validate(profile)) { error in
            XCTAssertEqual(error as? ProfileValidationError, .proxyPortsMustDiffer)
        }

        profile.httpProxyPort = 0
        XCTAssertThrowsError(try ProfileValidator.validate(profile)) { error in
            XCTAssertEqual(error as? ProfileValidationError, .invalidHTTPProxyPort)
        }
    }

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
            mode: .localForward,
            remotePort: 0
        )
        XCTAssertThrowsError(try ProfileValidator.validate(profile)) { error in
            XCTAssertEqual(error as? ProfileValidationError, .invalidRemotePort)
        }
    }

    func testRejectsInvalidAdvancedOptions() {
        var profile = TunnelProfile(name: "Advanced", sshHost: "example.test")
        profile.connectTimeout = 0
        XCTAssertThrowsError(try ProfileValidator.validate(profile)) { error in
            XCTAssertEqual(error as? ProfileValidationError, .invalidConnectTimeout)
        }
    }
}
