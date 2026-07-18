import Darwin
import Foundation

public struct LocalPortProcess: Equatable, Identifiable, Sendable {
    public let pid: Int32
    public let name: String

    public var id: Int32 { pid }

    public init(pid: Int32, name: String) {
        self.pid = pid
        self.name = name
    }
}

public struct LocalPortInspection: Equatable, Identifiable, Sendable {
    public let port: Int
    public let processes: [LocalPortProcess]

    public var id: Int { port }

    public init(port: Int, processes: [LocalPortProcess]) {
        self.port = port
        self.processes = processes
    }
}

public enum LocalPortInspector {
    public static func inspect(port: Int) async -> LocalPortInspection {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: inspectSynchronously(port: port))
            }
        }
    }

    public static func parse(output: String, port: Int) -> LocalPortInspection {
        var processes: [Int32: String] = [:]
        var currentPID: Int32?

        for line in output.split(whereSeparator: \.isNewline) {
            let value = String(line)
            guard let field = value.first else { continue }
            let payload = String(value.dropFirst())
            switch field {
            case "p":
                currentPID = Int32(payload)
            case "c":
                if let currentPID, !payload.isEmpty {
                    processes[currentPID] = payload
                }
            default:
                continue
            }
        }

        return LocalPortInspection(
            port: port,
            processes: processes
                .map { LocalPortProcess(pid: $0.key, name: $0.value) }
                .sorted { $0.pid < $1.pid }
        )
    }

    @discardableResult
    public static func terminate(pid: Int32) -> Bool {
        guard pid > 1, pid != Int32(getpid()) else { return false }
        return Darwin.kill(pid, SIGTERM) == 0
    }

    private static func inspectSynchronously(port: Int) -> LocalPortInspection {
        guard (1...65535).contains(port) else {
            return LocalPortInspection(port: port, processes: [])
        }

        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = [
            "-nP",
            "-a",
            "-iTCP:\(port)",
            "-sTCP:LISTEN",
            "-F",
            "pc"
        ]
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return LocalPortInspection(port: port, processes: [])
        }

        let output = String(
            decoding: outputPipe.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
        return parse(output: output, port: port)
    }
}
