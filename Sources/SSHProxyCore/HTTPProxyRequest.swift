import Foundation

public enum HTTPProxyRequestError: Error, Equatable {
    case incompleteHeaders
    case invalidRequestLine
    case invalidTarget
    case invalidHost
    case invalidPort
    case unsupportedScheme
}

public struct HTTPProxyRequest: Equatable, Sendable {
    public let host: String
    public let port: Int
    public let isConnect: Bool
    public let forwardPayload: Data

    public init(host: String, port: Int, isConnect: Bool, forwardPayload: Data) {
        self.host = host
        self.port = port
        self.isConnect = isConnect
        self.forwardPayload = forwardPayload
    }
}

public enum HTTPProxyRequestParser {
    public static let maximumHeaderBytes = 64 * 1024

    public static func parse(_ data: Data) throws -> HTTPProxyRequest {
        guard let headerRange = data.range(of: Data([13, 10, 13, 10])) else {
            throw HTTPProxyRequestError.incompleteHeaders
        }

        let headerData = data[..<headerRange.upperBound]
        let remainder = data[headerRange.upperBound...]
        guard let headerText = String(data: headerData, encoding: .isoLatin1) else {
            throw HTTPProxyRequestError.invalidRequestLine
        }
        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            throw HTTPProxyRequestError.invalidRequestLine
        }
        let parts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count == 3,
              parts[2].hasPrefix("HTTP/1.") else {
            throw HTTPProxyRequestError.invalidRequestLine
        }

        let method = String(parts[0]).uppercased()
        let target = String(parts[1])
        let version = String(parts[2])
        guard isValidHTTPToken(method) else {
            throw HTTPProxyRequestError.invalidRequestLine
        }

        if method == "CONNECT" {
            let authority = try parseAuthority(target, defaultPort: nil)
            return HTTPProxyRequest(
                host: authority.host,
                port: authority.port,
                isConnect: true,
                forwardPayload: Data(remainder)
            )
        }

        let headers = lines.dropFirst().filter { !$0.isEmpty }
        let destination: (host: String, port: Int)
        let originTarget: String

        if let components = URLComponents(string: target),
           let scheme = components.scheme?.lowercased() {
            guard scheme == "http" else { throw HTTPProxyRequestError.unsupportedScheme }
            guard components.user == nil, components.password == nil,
                  let host = components.host else {
                throw HTTPProxyRequestError.invalidTarget
            }
            destination = try validated(host: host, port: components.port ?? 80)
            let path = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
            originTarget = components.percentEncodedQuery.map { "\(path)?\($0)" } ?? path
        } else {
            guard target == "*" || target.hasPrefix("/") else {
                throw HTTPProxyRequestError.invalidTarget
            }
            guard let hostHeader = headers.first(where: {
                $0.lowercased().hasPrefix("host:")
            }), let separator = hostHeader.firstIndex(of: ":") else {
                throw HTTPProxyRequestError.invalidHost
            }
            let value = hostHeader[hostHeader.index(after: separator)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            destination = try parseAuthority(value, defaultPort: 80)
            originTarget = target
        }

        let forwardedHeaders = headers.filter { line in
            guard let separator = line.firstIndex(of: ":") else { return true }
            let name = line[..<separator].trimmingCharacters(in: .whitespaces).lowercased()
            return name != "connection"
                && name != "proxy-connection"
                && name != "proxy-authorization"
        }
        let rewrittenHeader = (
            ["\(method) \(originTarget) \(version)"]
                + forwardedHeaders
                + ["Connection: close"]
        ).joined(separator: "\r\n") + "\r\n\r\n"

        var payload = Data(rewrittenHeader.utf8)
        payload.append(contentsOf: remainder)
        return HTTPProxyRequest(
            host: destination.host,
            port: destination.port,
            isConnect: false,
            forwardPayload: payload
        )
    }

    private static func parseAuthority(
        _ rawValue: some StringProtocol,
        defaultPort: Int?
    ) throws -> (host: String, port: Int) {
        let value = String(rawValue).trimmingCharacters(in: .whitespacesAndNewlines)
        let host: String
        let port: Int

        if value.hasPrefix("[") {
            guard let closingBracket = value.firstIndex(of: "]") else {
                throw HTTPProxyRequestError.invalidHost
            }
            host = String(value[value.index(after: value.startIndex)..<closingBracket])
            let remainder = value[value.index(after: closingBracket)...]
            if remainder.isEmpty, let defaultPort {
                port = defaultPort
            } else {
                guard remainder.hasPrefix(":"),
                      let parsedPort = Int(remainder.dropFirst()) else {
                    throw HTTPProxyRequestError.invalidPort
                }
                port = parsedPort
            }
        } else if let separator = value.lastIndex(of: ":"),
                  !value[..<separator].contains(":") {
            host = String(value[..<separator])
            guard let parsedPort = Int(value[value.index(after: separator)...]) else {
                throw HTTPProxyRequestError.invalidPort
            }
            port = parsedPort
        } else {
            guard let defaultPort else { throw HTTPProxyRequestError.invalidPort }
            host = value
            port = defaultPort
        }

        return try validated(host: host, port: port)
    }

    private static func validated(host: String, port: Int) throws -> (host: String, port: Int) {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty,
              !host.contains(where: { $0.isWhitespace || $0.isNewline || $0.isASCII && $0.asciiValue! < 0x20 }) else {
            throw HTTPProxyRequestError.invalidHost
        }
        guard (1...65535).contains(port) else { throw HTTPProxyRequestError.invalidPort }
        return (host, port)
    }

    private static func isValidHTTPToken(_ value: String) -> Bool {
        let separators = CharacterSet(charactersIn: "()<>@,;:\\\"/[]?={} \t")
        return !value.isEmpty && value.unicodeScalars.allSatisfy {
            $0.value > 0x20 && $0.value < 0x7F && !separators.contains($0)
        }
    }
}

public enum SOCKS5RequestEncoder {
    public static func connect(host: String, port: Int) throws -> Data {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let bytes = Array(host.utf8)
        guard !bytes.isEmpty, bytes.count <= 255 else { throw HTTPProxyRequestError.invalidHost }
        guard (1...65535).contains(port) else { throw HTTPProxyRequestError.invalidPort }

        return Data(
            [0x05, 0x01, 0x00, 0x03, UInt8(bytes.count)]
                + bytes
                + [UInt8((port >> 8) & 0xFF), UInt8(port & 0xFF)]
        )
    }
}
