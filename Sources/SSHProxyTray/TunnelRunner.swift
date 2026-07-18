import Darwin
import Foundation
import Network
import SSHProxyCore

private final class PortProbeState: @unchecked Sendable {
    var finished = false
}

enum TunnelStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case failed(String)

    var title: String {
        switch self {
        case .disconnected:
            return SSHProxyL10n.string("status.disconnected", default: "Disconnected")
        case .connecting:
            return SSHProxyL10n.string("status.connecting", default: "Connecting")
        case .connected:
            return SSHProxyL10n.string("status.connected", default: "Connected")
        case .disconnecting:
            return SSHProxyL10n.string("status.disconnecting", default: "Disconnecting")
        case .failed:
            return SSHProxyL10n.string("status.connection_failed", default: "Connection failed")
        }
    }

    var symbolName: String {
        switch self {
        case .disconnected: return "circle"
        case .connecting: return "arrow.triangle.2.circlepath"
        case .connected: return "checkmark.circle.fill"
        case .disconnecting: return "stop.circle"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
}

@MainActor
final class TunnelRunner {
    var onUpdate: ((TunnelStatus, [String]) -> Void)?

    private var process: Process?
    private var processGuardPipe: Pipe?
    private var errorPipe: Pipe?
    private var askPassBroker: AskPassBroker?
    private var httpProxyServer: LocalHTTPProxyServer?
    private var remoteForwardInspector: RemoteForwardInspector?
    private var controlSocketPath: String?
    private var remoteForwardPort: Int?
    private var logs: [String] = []
    private var stopping = false
    private var terminalFailureMessage: String?
    private var stopCompletions: [() -> Void] = []

    func connect(profile: TunnelProfile, password: String?, askPassPath: String) throws {
        disconnect()
        stopping = false
        terminalFailureMessage = nil
        logs = []
        update(.connecting)

        var environment = ProcessInfo.processInfo.environment
        if profile.authentication == .password {
            guard let password, !password.isEmpty else {
                throw AppModelError.passwordRequired
            }
            let broker = AskPassBroker()
            let brokerEnvironment = try broker.start(password: password)
            askPassBroker = broker
            environment.merge(brokerEnvironment) { _, new in new }
            environment["SSH_ASKPASS"] = askPassPath
            environment["SSH_ASKPASS_REQUIRE"] = "force"
            environment["DISPLAY"] = environment["DISPLAY"] ?? ":0"
        }

        let socketPath = "/tmp/spt-\(UUID().uuidString.prefix(12)).sock"
        try? FileManager.default.removeItem(atPath: socketPath)
        controlSocketPath = socketPath
        remoteForwardPort = profile.mode == .remoteForward ? profile.remotePort : nil

        let process = Process()
        let pipe = Pipe()
        var arguments = SSHArgumentsBuilder.arguments(for: profile)
        arguments.insert(contentsOf: [
            "-o", "ControlMaster=yes",
            "-o", "ControlPersist=no",
            "-o", "ControlPath=\(socketPath)"
        ], at: 0)
        let processGuardPath = siblingExecutablePath(named: "SSHProcessGuard")
        let processGuardAvailable = FileManager.default.isExecutableFile(atPath: processGuardPath)
        if processGuardAvailable {
            let lifetimePipe = Pipe()
            process.executableURL = URL(fileURLWithPath: processGuardPath)
            process.arguments = ["--", "/usr/bin/ssh"] + arguments
            process.standardInput = lifetimePipe
            processGuardPipe = lifetimePipe
        } else if Bundle.main.bundleURL.pathExtension.lowercased() == "app" {
            cleanup()
            throw AppModelError.processGuardMissing
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            process.arguments = arguments
            process.standardInput = FileHandle.nullDevice
        }
        process.environment = environment
        process.standardOutput = FileHandle.nullDevice
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let text = String(decoding: data, as: UTF8.self)
            DispatchQueue.main.async {
                self?.appendLog(text)
            }
        }

        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.handleTermination(process: process, status: process.terminationStatus)
            }
        }

        self.process = process
        errorPipe = pipe
        remoteForwardInspector = RemoteForwardInspector(
            controlPath: socketPath,
            destination: sshDestination(for: profile)
        )

        do {
            try process.run()
        } catch {
            cleanup()
            update(.failed(error.localizedDescription))
            throw error
        }

        if profile.mode == .remoteForward {
            waitForRemoteForward(process: process)
        } else {
            waitForLocalPort(profile: profile, process: process, attempt: 0)
        }
    }

    func disconnect(completion: (() -> Void)? = nil) {
        if let completion { stopCompletions.append(completion) }
        stopping = true
        guard let process else {
            cleanup()
            update(.disconnected)
            finishStopping()
            return
        }
        if process.isRunning {
            update(.disconnecting)
            if let remoteForwardInspector {
                remoteForwardInspector.closeControlMaster { [weak self, weak process] in
                    guard let self, let process, self.process === process else { return }
                    if process.isRunning { process.terminate() }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self, weak process] in
                    guard let self, let process, self.process === process, process.isRunning else { return }
                    if let lifetimePipe = self.processGuardPipe {
                        lifetimePipe.fileHandleForWriting.closeFile()
                    } else {
                        process.terminate()
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self, weak process] in
                    guard let self, let process, self.process === process, process.isRunning else { return }
                    if self.processGuardPipe != nil {
                        process.terminate()
                    } else {
                        Darwin.kill(process.processIdentifier, SIGKILL)
                    }
                }
            } else {
                process.terminate()
            }
            return
        }
        cleanup(clearProcess: false)
        if !process.isRunning {
            update(.disconnected)
            finishStopping()
        }
    }

    func inspectRemoteForward(
        port: Int,
        completion: @escaping (RemoteForwardInspection) -> Void
    ) {
        guard process?.isRunning == true, let remoteForwardInspector else {
            completion(.unsupported(SSHProxyL10n.string(
                "remote_check.control_unavailable",
                default: "The active SSH control connection is unavailable."
            )))
            return
        }
        remoteForwardInspector.inspect(port: port, completion: completion)
    }

    func configureGatewayPorts(completion: @escaping (RemoteCommandResult) -> Void) {
        guard process?.isRunning == true, let remoteForwardInspector else {
            completion(RemoteCommandResult(
                status: -1,
                output: SSHProxyL10n.string(
                    "remote_check.control_unavailable",
                    default: "The active SSH control connection is unavailable."
                )
            ))
            return
        }
        remoteForwardInspector.configureGatewayPorts(completion: completion)
    }

    func refreshRemoteForward(
        profile: TunnelProfile,
        completion: @escaping (RemoteCommandResult) -> Void
    ) {
        guard process?.isRunning == true, let remoteForwardInspector else {
            completion(RemoteCommandResult(
                status: -1,
                output: SSHProxyL10n.string(
                    "remote_check.control_unavailable",
                    default: "The active SSH control connection is unavailable."
                )
            ))
            return
        }
        remoteForwardInspector.refreshRemoteForward(profile: profile, completion: completion)
    }

    private func handleTermination(process: Process, status: Int32) {
        guard self.process === process else { return }
        let wasStopping = stopping
        let terminalFailureMessage = terminalFailureMessage
        let remoteForwardPort = remoteForwardPort
        self.terminalFailureMessage = nil
        cleanup()
        if wasStopping {
            update(.disconnected)
            finishStopping()
            return
        }
        if let terminalFailureMessage {
            update(.failed(terminalFailureMessage))
            return
        }
        let detail: String
        if let remoteForwardPort,
           logs.contains(where: { $0.localizedCaseInsensitiveContains("remote port forwarding failed") }) {
            detail = SSHProxyL10n.format(
                "runner.remote_forward_failed",
                default: "The SSH server could not open remote port %d. Another SSH session may already be using it, or the server policy may have rejected the request.",
                remoteForwardPort
            )
        } else {
            detail = logs.last(where: { !$0.isEmpty }) ?? SSHProxyL10n.format(
                "runner.ssh_exited",
                default: "ssh exited with status %d.",
                status
            )
        }
        update(.failed(detail))
    }

    private func waitForLocalPort(profile: TunnelProfile, process: Process, attempt: Int) {
        guard self.process === process, process.isRunning else { return }
        probe(host: profile.localHost, port: profile.localPort) { [weak self, weak process] isOpen in
            guard let self, let process, self.process === process else { return }
            if isOpen {
                self.startHTTPProxyIfNeeded(profile: profile, process: process)
            } else if attempt < 24, process.isRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.waitForLocalPort(profile: profile, process: process, attempt: attempt + 1)
                }
            } else if process.isRunning {
                self.failAndTerminate(SSHProxyL10n.string(
                    "runner.local_port_did_not_open",
                    default: "Local proxy port did not open."
                ), process: process)
            }
        }
    }

    private func startHTTPProxyIfNeeded(profile: TunnelProfile, process: Process) {
        guard profile.mode == .socks5, let httpProxyPort = profile.httpProxyPort else {
            finishConnecting()
            return
        }

        let server = LocalHTTPProxyServer()
        httpProxyServer = server
        do {
            try server.start(
                listenHost: profile.localHost,
                listenPort: httpProxyPort,
                socksHost: profile.localHost,
                socksPort: profile.localPort,
                onReady: { [weak self, weak process] in
                    guard let self, let process,
                          self.process === process,
                          process.isRunning else { return }
                    self.finishConnecting()
                },
                onFailure: { [weak self, weak process] error in
                    guard let self, let process,
                          self.process === process else { return }
                    self.failAndTerminate(error.localizedDescription, process: process)
                }
            )
        } catch {
            failAndTerminate(error.localizedDescription, process: process)
        }
    }

    private func finishConnecting() {
        askPassBroker?.stop()
        askPassBroker = nil
        update(.connected)
    }

    private func failAndTerminate(_ message: String, process: Process) {
        terminalFailureMessage = message
        httpProxyServer?.stop()
        httpProxyServer = nil
        if process.isRunning { process.terminate() }
        update(.failed(message))
    }

    private func waitForRemoteForward(process: Process) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self, weak process] in
            guard let self, let process, self.process === process else { return }
            if process.isRunning {
                self.finishConnecting()
            }
        }
    }

    nonisolated private func probe(
        host: String,
        port: Int,
        completion: @escaping @MainActor (Bool) -> Void
    ) {
        guard let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            Task { @MainActor in completion(false) }
            return
        }
        let queue = DispatchQueue(label: "io.github.xingkoo.ssh-proxy-tray.port-probe")
        let connection = NWConnection(host: NWEndpoint.Host(host), port: endpointPort, using: .tcp)
        let state = PortProbeState()

        let finish: @Sendable (Bool) -> Void = { result in
            guard !state.finished else { return }
            state.finished = true
            connection.cancel()
            Task { @MainActor in completion(result) }
        }

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                finish(true)
            case .failed, .cancelled:
                finish(false)
            default:
                break
            }
        }
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + 0.25) { finish(false) }
    }

    private func appendLog(_ text: String) {
        let newLines = text
            .split(whereSeparator: { $0.isNewline })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        logs.append(contentsOf: newLines)
        if logs.count > 80 { logs.removeFirst(logs.count - 80) }
        onUpdate?(currentStatus, logs)
    }

    private var currentStatus: TunnelStatus = .disconnected

    private func update(_ status: TunnelStatus) {
        currentStatus = status
        onUpdate?(status, logs)
    }

    private func cleanup(clearProcess: Bool = true) {
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe = nil
        processGuardPipe?.fileHandleForWriting.closeFile()
        processGuardPipe = nil
        askPassBroker?.stop()
        askPassBroker = nil
        httpProxyServer?.stop()
        httpProxyServer = nil
        remoteForwardInspector?.stop()
        remoteForwardInspector = nil
        if let controlSocketPath {
            try? FileManager.default.removeItem(atPath: controlSocketPath)
        }
        controlSocketPath = nil
        remoteForwardPort = nil
        if clearProcess { process = nil }
    }

    private func finishStopping() {
        let completions = stopCompletions
        stopCompletions.removeAll()
        for completion in completions { completion() }
    }

    private func sshDestination(for profile: TunnelProfile) -> String {
        switch profile.authentication {
        case .sshConfig:
            return profile.sshHost
        case .keyFile, .password:
            return "\(profile.username)@\(profile.sshHost)"
        }
    }

    private func siblingExecutablePath(named name: String) -> String {
        let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent()
            ?? URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        return executableDirectory.appendingPathComponent(name).path
    }
}
