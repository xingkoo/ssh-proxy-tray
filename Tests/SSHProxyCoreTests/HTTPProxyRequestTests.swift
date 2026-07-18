import Foundation
import XCTest
@testable import SSHProxyCore

final class HTTPProxyRequestTests: XCTestCase {
    func testParsesConnectRequestAndPreservesEarlyTunnelBytes() throws {
        let input = Data("CONNECT example.com:443 HTTP/1.1\r\nHost: example.com:443\r\n\r\nearly".utf8)
        let request = try HTTPProxyRequestParser.parse(input)

        XCTAssertEqual(request.host, "example.com")
        XCTAssertEqual(request.port, 443)
        XCTAssertTrue(request.isConnect)
        XCTAssertEqual(request.forwardPayload, Data("early".utf8))
    }

    func testRewritesAbsoluteHTTPURLAndRemovesProxyCredentials() throws {
        let input = Data((
            "GET http://example.com:8080/path?q=1 HTTP/1.1\r\n"
                + "Host: example.com:8080\r\n"
                + "Proxy-Connection: keep-alive\r\n"
                + "Proxy-Authorization: Basic secret\r\n"
                + "Connection: keep-alive\r\n"
                + "User-Agent: Test\r\n\r\n"
        ).utf8)
        let request = try HTTPProxyRequestParser.parse(input)
        let payload = String(decoding: request.forwardPayload, as: UTF8.self)

        XCTAssertEqual(request.host, "example.com")
        XCTAssertEqual(request.port, 8080)
        XCTAssertFalse(request.isConnect)
        XCTAssertTrue(payload.hasPrefix("GET /path?q=1 HTTP/1.1\r\n"))
        XCTAssertTrue(payload.contains("Host: example.com:8080"))
        XCTAssertFalse(payload.lowercased().contains("proxy-connection"))
        XCTAssertFalse(payload.lowercased().contains("proxy-authorization"))
        XCTAssertFalse(payload.lowercased().contains("connection: keep-alive"))
        XCTAssertTrue(payload.contains("Connection: close\r\n"))
    }

    func testSupportsOriginFormAndIPv6ConnectAuthority() throws {
        let origin = try HTTPProxyRequestParser.parse(Data(
            "GET /health HTTP/1.1\r\nHost: internal.example\r\n\r\n".utf8
        ))
        XCTAssertEqual(origin.host, "internal.example")
        XCTAssertEqual(origin.port, 80)

        let ipv6 = try HTTPProxyRequestParser.parse(Data(
            "CONNECT [2001:db8::1]:8443 HTTP/1.1\r\n\r\n".utf8
        ))
        XCTAssertEqual(ipv6.host, "2001:db8::1")
        XCTAssertEqual(ipv6.port, 8443)
    }

    func testRejectsHTTPSAbsoluteFormAndInvalidPorts() {
        XCTAssertThrowsError(try HTTPProxyRequestParser.parse(Data(
            "GET https://example.com/ HTTP/1.1\r\nHost: example.com\r\n\r\n".utf8
        ))) { error in
            XCTAssertEqual(error as? HTTPProxyRequestError, .unsupportedScheme)
        }
        XCTAssertThrowsError(try HTTPProxyRequestParser.parse(Data(
            "CONNECT example.com:70000 HTTP/1.1\r\n\r\n".utf8
        ))) { error in
            XCTAssertEqual(error as? HTTPProxyRequestError, .invalidPort)
        }
    }

    func testEncodesSOCKS5DomainConnectRequest() throws {
        let request = try SOCKS5RequestEncoder.connect(host: "example.com", port: 443)
        XCTAssertEqual(Array(request.prefix(5)), [0x05, 0x01, 0x00, 0x03, 11])
        XCTAssertEqual(String(decoding: request.dropFirst(5).dropLast(2), as: UTF8.self), "example.com")
        XCTAssertEqual(Array(request.suffix(2)), [0x01, 0xBB])
    }
}
