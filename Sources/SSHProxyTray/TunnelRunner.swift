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
    private var errorPipe: Pipe?
    private var askPassBroker: AskPassBroker?
    private var logs: [String] = []
    private var stopping = false

    func connect(profile: TunnelProfile, password: String?, askPassPath: String) throws {
        disconnect()
        stopping = false
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

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = SSHArgumentsBuilder.arguments(for: profile)
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
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

    func disconnect() {
        stopping = true
        guard let process else {
            cleanup()
            update(.disconnected)
            return
        }
        if process.isRunning {
            update(.disconnecting)
            process.terminate()
        }
        cleanup(clearProcess: false)
        if !process.isRunning { update(.disconnected) }
    }

    private func handleTermination(process: Process, status: Int32) {
        guard self.process === process else { return }
        let wasStopping = stopping
        cleanup()
        if wasStopping {
            update(.disconnected)
            return
        }
        let detail = logs.last(where: { !$0.isEmpty }) ?? SSHProxyL10n.format(
            "runner.ssh_exited",
            default: "ssh exited with status %d.",
            status
        )
        update(.failed(detail))
    }

    private func waitForLocalPort(profile: TunnelProfile, process: Process, attempt: Int) {
        guard self.process === process, process.isRunning else { return }
        probe(host: profile.localHost, port: profile.localPort) { [weak self, weak process] isOpen in
            guard let self, let process, self.process === process else { return }
            if isOpen {
                self.askPassBroker?.stop()
                self.askPassBroker = nil
                self.update(.connected)
            } else if attempt < 24, process.isRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.waitForLocalPort(profile: profile, process: process, attempt: attempt + 1)
                }
            } else if process.isRunning {
                process.terminate()
                self.update(.failed(SSHProxyL10n.string(
                    "runner.local_port_did_not_open",
                    default: "Local proxy port did not open."
                )))
            }
        }
    }

    private func waitForRemoteForward(process: Process) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self, weak process] in
            guard let self, let process, self.process === process else { return }
            if process.isRunning {
                self.askPassBroker?.stop()
                self.askPassBroker = nil
                self.update(.connected)
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
        askPassBroker?.stop()
        askPassBroker = nil
        if clearProcess { process = nil }
    }
}
