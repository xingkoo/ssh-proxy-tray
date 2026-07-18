import Darwin
import XCTest
@testable import SSHProxyCore

final class LocalPortAvailabilityTests: XCTestCase {
    func testDetectsOccupiedAndReleasedPort() throws {
        let socketDescriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(socketDescriptor, 0)

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(socketDescriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        XCTAssertEqual(bindResult, 0)
        XCTAssertEqual(Darwin.listen(socketDescriptor, 1), 0)

        var boundAddress = sockaddr_in()
        var boundLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.getsockname(socketDescriptor, $0, &boundLength)
            }
        }
        XCTAssertEqual(nameResult, 0)
        let port = Int(UInt16(bigEndian: boundAddress.sin_port))

        XCTAssertFalse(LocalPortAvailability.isAvailable(host: "127.0.0.1", port: port))
        Darwin.close(socketDescriptor)
        XCTAssertTrue(LocalPortAvailability.isAvailable(host: "127.0.0.1", port: port))
    }
}
