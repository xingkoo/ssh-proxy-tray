import Darwin
import XCTest
@testable import SSHProxyCore

final class LocalPortInspectorTests: XCTestCase {
    func testParsesStructuredLsofOutput() {
        let output = """
        p123
        cssh
        f4
        n127.0.0.1:17890
        p456
        cSSHProxyT
        f9
        n127.0.0.1:17891
        """

        XCTAssertEqual(
            LocalPortInspector.parse(output: output, port: 17890).processes,
            [
                LocalPortProcess(pid: 123, name: "ssh"),
                LocalPortProcess(pid: 456, name: "SSHProxyT")
            ]
        )
    }

    func testRejectsUnsafeProcessIDs() {
        XCTAssertFalse(LocalPortInspector.terminate(pid: 1))
        XCTAssertFalse(LocalPortInspector.terminate(pid: Int32(getpid())))
    }

    func testTerminatesOwnedTestProcess() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["30"]
        try process.run()

        XCTAssertTrue(LocalPortInspector.terminate(pid: process.processIdentifier))
        process.waitUntilExit()
        XCTAssertFalse(process.isRunning)
    }
}
