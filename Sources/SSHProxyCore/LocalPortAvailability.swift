import Darwin
import Foundation

public enum LocalPortAvailability {
    public static func isAvailable(host: String, port: Int) -> Bool {
        guard (1...65535).contains(port) else { return false }
        let socketDescriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else { return false }
        defer { Darwin.close(socketDescriptor) }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(UInt16(port).bigEndian)
        let normalizedHost = host == "localhost" ? "127.0.0.1" : host
        guard inet_pton(AF_INET, normalizedHost, &address.sin_addr) == 1 else { return false }

        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(
                    socketDescriptor,
                    $0,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
            }
        }
        return result == 0
    }
}
