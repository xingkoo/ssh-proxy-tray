import Foundation

public enum SSHConfigHostParser {
    public static func aliases(from contents: String) -> [String] {
        var result: [String] = []
        var seen = Set<String>()

        for rawLine in contents.split(whereSeparator: { $0.isNewline }) {
            let line = rawLine
                .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let fields = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard fields.count > 1, fields[0].caseInsensitiveCompare("Host") == .orderedSame else {
                continue
            }

            for alias in fields.dropFirst() {
                guard !alias.hasPrefix("!"),
                      !alias.contains("*"),
                      !alias.contains("?") else { continue }
                let key = alias.lowercased()
                if seen.insert(key).inserted { result.append(alias) }
            }
        }

        return result
    }
}
