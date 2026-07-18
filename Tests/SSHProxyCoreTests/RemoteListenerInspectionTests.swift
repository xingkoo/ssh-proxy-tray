import XCTest
@testable import SSHProxyCore

final class RemoteListenerInspectionTests: XCTestCase {
    func testDetectsWildcardListenerFromSSOutput() {
        let output = "LISTEN 0 128 0.0.0.0:20080 0.0.0.0:*"
        XCTAssertEqual(
            RemoteListenerInspectionParser.scope(from: output, port: 20080),
            .external
        )
    }

    func testDetectsLoopbackOnlyListenerFromDualStackOutput() {
        let output = """
        LISTEN 0 128 127.0.0.1:20080 0.0.0.0:*
        LISTEN 0 128 [::1]:20080 [::]:*
        """
        XCTAssertEqual(
            RemoteListenerInspectionParser.scope(from: output, port: 20080),
            .loopbackOnly
        )
    }

    func testDetectsSpecificInterfaceAndNetstatFormats() {
        XCTAssertEqual(
            RemoteListenerInspectionParser.scope(
                from: "tcp 0 0 10.0.0.4:23000 0.0.0.0:* LISTEN",
                port: 23000
            ),
            .external
        )
        XCTAssertEqual(
            RemoteListenerInspectionParser.scope(
                from: "tcp4 0 0 127.0.0.1.23000 *.* LISTEN",
                port: 23000
            ),
            .loopbackOnly
        )
    }

    func testIgnoresOtherPortsAndPeerAddresses() {
        let output = "LISTEN 0 128 0.0.0.0:8080 0.0.0.0:*"
        XCTAssertEqual(
            RemoteListenerInspectionParser.scope(from: output, port: 20080),
            .missing
        )
    }
}
