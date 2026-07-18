import Foundation
import XCTest

final class LocalizationTests: XCTestCase {
    func testEnglishAndChineseLocalizationsHaveMatchingKeysAndFormats() throws {
        let english = try localization(named: "en")
        let chinese = try localization(named: "zh-Hans")

        XCTAssertEqual(Set(english.keys), Set(chinese.keys))
        XCTAssertFalse(english.isEmpty)

        for key in english.keys {
            XCTAssertFalse(english[key, default: ""].isEmpty, "Missing English value for \(key)")
            XCTAssertFalse(chinese[key, default: ""].isEmpty, "Missing Chinese value for \(key)")
            XCTAssertEqual(
                formatSpecifiers(in: english[key, default: ""]),
                formatSpecifiers(in: chinese[key, default: ""]),
                "Format arguments differ for \(key)"
            )
        }
    }

    func testEverySourceLocalizationKeyExistsInBothLanguages() throws {
        let englishKeys = Set(try localization(named: "en").keys)
        let chineseKeys = Set(try localization(named: "zh-Hans").keys)
        let expression = try NSRegularExpression(
            pattern: #"(?:SSHProxyL10n\.(?:string|format)|ui)\(\s*\"([^\"]+)\""#
        )
        var sourceKeys = Set<String>()
        let sourceDirectory = repositoryRoot.appendingPathComponent("Sources")
        let enumerator = try XCTUnwrap(
            FileManager.default.enumerator(
                at: sourceDirectory,
                includingPropertiesForKeys: [.isRegularFileKey]
            )
        )

        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let source = try String(contentsOf: url, encoding: .utf8)
            let range = NSRange(source.startIndex..<source.endIndex, in: source)
            for match in expression.matches(in: source, range: range) {
                guard let keyRange = Range(match.range(at: 1), in: source) else { continue }
                sourceKeys.insert(String(source[keyRange]))
            }
        }

        XCTAssertFalse(sourceKeys.isEmpty)
        XCTAssertEqual(sourceKeys.subtracting(englishKeys), [])
        XCTAssertEqual(sourceKeys.subtracting(chineseKeys), [])
        XCTAssertEqual(englishKeys.subtracting(sourceKeys), [])
    }

    private func localization(named language: String) throws -> [String: String] {
        let url = repositoryRoot
            .appendingPathComponent("Resources")
            .appendingPathComponent("\(language).lproj")
            .appendingPathComponent("Localizable.strings")
        let data = try Data(contentsOf: url)
        let propertyList = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(propertyList as? [String: String])
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func formatSpecifiers(in value: String) -> [String] {
        let pattern = #"%(?:\d+\$)?[-+#0 ]*(?:\d+|\*)?(?:\.\d+|\.\*)?[hlLzjtq]*[@a-zA-Z]"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.matches(in: value, range: range).compactMap { match in
            guard let range = Range(match.range, in: value) else { return nil }
            return String(value[range])
        }
    }
}
