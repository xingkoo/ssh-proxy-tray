import Darwin
import Foundation

@main
struct SSHProcessGuard {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.first == "--",
              arguments.count >= 2,
              arguments[1] == "/usr/bin/ssh" else {
            FileHandle.standardError.write(Data("SSHProcessGuard: invalid command\n".utf8))
            Darwin.exit(EX_USAGE)
        }

        let sshArguments = Array(arguments.dropFirst(2))
        let controlSocketPath = managedControlSocketPath(in: sshArguments)
        let ssh = Process()
        ssh.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        ssh.arguments = sshArguments
        ssh.standardInput = FileHandle.nullDevice
        ssh.standardOutput = FileHandle.standardOutput
        ssh.standardError = FileHandle.standardError

        do {
            try ssh.run()
        } catch {
            FileHandle.standardError.write(Data("SSHProcessGuard: \(error.localizedDescription)\n".utf8))
            Darwin.exit(EX_OSERR)
        }

        let signalSources = installSignalForwarders(ssh: ssh)

        DispatchQueue.global(qos: .userInitiated).async {
            waitForOwnerPipeToClose()
            stopSSH(process: ssh)
        }

        ssh.waitUntilExit()
        if let controlSocketPath {
            try? FileManager.default.removeItem(atPath: controlSocketPath)
        }
        withExtendedLifetime(signalSources) {}
        Darwin.exit(ssh.terminationStatus)
    }

    private static func installSignalForwarders(ssh: Process) -> [DispatchSourceSignal] {
        [SIGTERM, SIGINT, SIGHUP].map { signalNumber in
            Darwin.signal(signalNumber, SIG_IGN)
            let source = DispatchSource.makeSignalSource(
                signal: signalNumber,
                queue: DispatchQueue.global(qos: .userInitiated)
            )
            source.setEventHandler { stopSSH(process: ssh) }
            source.activate()
            return source
        }
    }

    private static func waitForOwnerPipeToClose() {
        var byte: UInt8 = 0
        while true {
            let result = Darwin.read(STDIN_FILENO, &byte, 1)
            if result == 0 { return }
            if result < 0 {
                if errno == EINTR { continue }
                return
            }
        }
    }

    private static func stopSSH(process: Process) {
        guard process.isRunning else { return }
        process.terminate()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.8) {
            if process.isRunning {
                Darwin.kill(process.processIdentifier, SIGKILL)
            }
        }
    }

    private static func managedControlSocketPath(in arguments: [String]) -> String? {
        guard let argument = arguments.first(where: { $0.hasPrefix("ControlPath=") }) else {
            return nil
        }
        let path = String(argument.dropFirst("ControlPath=".count))
        let prefix = "/tmp/spt-"
        let suffix = ".sock"
        guard path.hasPrefix(prefix), path.hasSuffix(suffix) else { return nil }
        let identifier = path.dropFirst(prefix.count).dropLast(suffix.count)
        guard identifier.count == 12,
              identifier.allSatisfy({ $0.isHexDigit || $0 == "-" }) else { return nil }
        return path
    }
}
