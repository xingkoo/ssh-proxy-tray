import Darwin
import Foundation

public struct OrphanedTunnelProcess: Equatable, Sendable {
    public let pid: Int32
    public let parentPID: Int32
    public let controlSocketPath: String

    public init(pid: Int32, parentPID: Int32, controlSocketPath: String) {
        self.pid = pid
        self.parentPID = parentPID
        self.controlSocketPath = controlSocketPath
    }
}

public enum OrphanedTunnelReaper {
    public static func candidates(from processList: String) -> [OrphanedTunnelProcess] {
        processList.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(
                maxSplits: 2,
                omittingEmptySubsequences: true,
                whereSeparator: \.isWhitespace
            )
            guard fields.count == 3,
                  let pid = Int32(fields[0]),
                  let parentPID = Int32(fields[1]),
                  pid > 1,
                  parentPID == 1 else { return nil }

            let commandFields = fields[2].split(whereSeparator: \.isWhitespace).map(String.init)
            guard commandFields.first == "/usr/bin/ssh",
                  commandFields.contains("ControlMaster=yes"),
                  commandFields.contains("ControlPersist=no"),
                  let controlArgument = commandFields.first(where: { $0.hasPrefix("ControlPath=") }) else {
                return nil
            }

            let socketPath = String(controlArgument.dropFirst("ControlPath=".count))
            guard isManagedControlSocket(socketPath) else { return nil }
            return OrphanedTunnelProcess(
                pid: pid,
                parentPID: parentPID,
                controlSocketPath: socketPath
            )
        }
        .sorted { $0.pid < $1.pid }
    }

    @discardableResult
    public static func reap() -> [OrphanedTunnelProcess] {
        guard let output = currentProcessList() else { return [] }
        let orphanedProcesses = candidates(from: output)
        guard !orphanedProcesses.isEmpty else { return [] }

        for process in orphanedProcesses {
            Darwin.kill(process.pid, SIGTERM)
        }
        waitForExit(orphanedProcesses.map(\.pid), timeout: 1.0)

        let stillMatching = Set((currentProcessList().map(candidates) ?? []).map {
            "\($0.pid):\($0.controlSocketPath)"
        })
        for process in orphanedProcesses
        where stillMatching.contains("\(process.pid):\(process.controlSocketPath)") {
            Darwin.kill(process.pid, SIGKILL)
        }
        waitForExit(orphanedProcesses.map(\.pid), timeout: 0.5)

        for process in orphanedProcesses where !isRunning(process.pid) {
            try? FileManager.default.removeItem(atPath: process.controlSocketPath)
        }
        return orphanedProcesses
    }

    private static func currentProcessList() -> String? {
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,ppid=,command="]
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: outputData, as: UTF8.self)
    }

    private static func isManagedControlSocket(_ path: String) -> Bool {
        let prefix = "/tmp/spt-"
        let suffix = ".sock"
        guard path.hasPrefix(prefix), path.hasSuffix(suffix) else { return false }
        let identifier = path.dropFirst(prefix.count).dropLast(suffix.count)
        return identifier.count == 12 && identifier.allSatisfy {
            $0.isHexDigit || $0 == "-"
        }
    }

    private static func waitForExit(_ pids: [Int32], timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, pids.contains(where: isRunning) {
            usleep(50_000)
        }
    }

    private static func isRunning(_ pid: Int32) -> Bool {
        if Darwin.kill(pid, 0) == 0 { return true }
        return errno == EPERM
    }
}
