import XCTest
@testable import SSHProxyCore

final class SSHConfigHostParserTests: XCTestCase {
    func testParsesConcreteAliasesAndIgnoresPatterns() {
        let contents = """
        Host qiniu production
          HostName example.test

        Host *.internal !blocked.internal
          User deploy

        host Bastion # comment
          HostName bastion.example.test
        """

        XCTAssertEqual(
            SSHConfigHostParser.aliases(from: contents),
            ["qiniu", "production", "Bastion"]
        )
    }

    func testDeduplicatesAliasesCaseInsensitively() {
        let contents = "Host qiniu\nHost QINIU backup\n"
        XCTAssertEqual(SSHConfigHostParser.aliases(from: contents), ["qiniu", "backup"])
    }
}
