import Foundation

public enum RemoteListenerScope: Equatable, Sendable {
    case missing
    case loopbackOnly
    case external
}

public enum RemoteListenerInspectionParser {
    public static func scope(from listenerOutput: String, port: Int) -> RemoteListenerScope {
        guard (1...65535).contains(port) else { return .missing }

        var foundLoopback = false
        for line in listenerOutput.split(whereSeparator: { $0.isNewline }) {
            for rawToken in line.split(whereSeparator: { $0.isWhitespace }) {
                guard let host = hostIfTokenMatchesPort(String(rawToken), port: port) else { continue }
                if isLoopback(host) {
                    foundLoopback = true
                } else {
                    return .external
                }
            }
        }
        return foundLoopback ? .loopbackOnly : .missing
    }

    private static func hostIfTokenMatchesPort(_ rawToken: String, port: Int) -> String? {
        let token = rawToken.trimmingCharacters(in: CharacterSet(charactersIn: ","))
        let colonSuffix = ":\(port)"
        let dotSuffix = ".\(port)"

        if token.hasSuffix(colonSuffix) {
            return String(token.dropLast(colonSuffix.count)).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        }
        if token.hasSuffix(dotSuffix) {
            return String(token.dropLast(dotSuffix.count)).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        }
        return nil
    }

    private static func isLoopback(_ host: String) -> Bool {
        host == "127.0.0.1" || host == "::1" || host == "localhost"
    }
}
