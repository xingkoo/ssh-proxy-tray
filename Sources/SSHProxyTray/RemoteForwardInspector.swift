import Foundation
import SSHProxyCore

enum RemoteForwardInspection: Equatable {
    case notChecked
    case checking
    case serverOnly
    case external
    case missing
    case unsupported(String)
    case configuring
}

struct RemoteCommandResult {
    let status: Int32
    let output: String
}

@MainActor
final class RemoteForwardInspector {
    private let controlPath: String
    private let destination: String
    private var commands: [Process] = []

    init(controlPath: String, destination: String) {
        self.controlPath = controlPath
        self.destination = destination
    }

    func inspect(port: Int, completion: @escaping (RemoteForwardInspection) -> Void) {
        let command = """
        if command -v ss >/dev/null 2>&1; then
          ss -ltnH
        elif command -v netstat >/dev/null 2>&1; then
          netstat -lnt
        else
          echo SSH_PROXY_TRAY_LISTENER_TOOL_MISSING
          exit 23
        fi
        """
        runRemoteShell(command) { result in
            guard result.status == 0 else {
                completion(.unsupported(Self.lastUsefulLine(in: result.output)))
                return
            }
            switch RemoteListenerInspectionParser.scope(from: result.output, port: port) {
            case .missing:
                completion(.missing)
            case .loopbackOnly:
                completion(.serverOnly)
            case .external:
                completion(.external)
            }
        }
    }

    func configureGatewayPorts(completion: @escaping (RemoteCommandResult) -> Void) {
        let command = """
        set -eu
        target=/etc/ssh/sshd_config.d/90-ssh-proxy-tray-gatewayports.conf
        backup="${target}.backup-$(date +%Y%m%d%H%M%S)"
        had_existing=0

        if ! command -v sudo >/dev/null 2>&1 || ! sudo -n true 2>/dev/null; then
          echo SSH_PROXY_TRAY_SUDO_REQUIRED
          exit 21
        fi
        if ! command -v systemctl >/dev/null 2>&1 || ! test -x /usr/sbin/sshd; then
          echo SSH_PROXY_TRAY_UNSUPPORTED_SERVER
          exit 22
        fi
        if ! grep -Eq '^[[:space:]]*Include[[:space:]].*sshd_config\\.d/\\*\\.conf' /etc/ssh/sshd_config; then
          echo SSH_PROXY_TRAY_DROPIN_NOT_INCLUDED
          exit 23
        fi

        if sudo test -e "$target"; then
          sudo cp -a "$target" "$backup"
          had_existing=1
        fi
        restore_previous() {
          if test "$had_existing" -eq 1; then
            sudo cp -a "$backup" "$target"
          else
            sudo rm -f "$target"
          fi
        }

        printf '%s\n' \
          '# Managed by SSH Proxy Tray after explicit user approval.' \
          'GatewayPorts clientspecified' \
          | sudo tee "$target" >/dev/null
        sudo chmod 0644 "$target"

        if ! sudo /usr/sbin/sshd -t; then
          restore_previous
          echo SSH_PROXY_TRAY_VALIDATION_FAILED
          exit 24
        fi

        if systemctl is-active --quiet sshd; then
          service=sshd
        elif systemctl is-active --quiet ssh; then
          service=ssh
        else
          restore_previous
          echo SSH_PROXY_TRAY_SSH_SERVICE_NOT_FOUND
          exit 25
        fi

        if ! sudo systemctl reload "$service"; then
          restore_previous
          sudo /usr/sbin/sshd -t || true
          sudo systemctl reload "$service" || true
          echo SSH_PROXY_TRAY_RELOAD_FAILED
          exit 26
        fi

        echo SSH_PROXY_TRAY_CONFIGURED
        """
        runRemoteShell(command, timeout: 30, completion: completion)
    }

    func refreshRemoteForward(
        profile: TunnelProfile,
        completion: @escaping (RemoteCommandResult) -> Void
    ) {
        let specification = "\(profile.remoteHost):\(profile.remotePort):\(profile.localHost):\(profile.localPort)"
        runSSH(arguments: [
            "-S", controlPath,
            "-O", "cancel",
            "-R", specification,
            destination
        ]) { [weak self] cancelResult in
            guard let self else { return }
            guard cancelResult.status == 0 else {
                completion(cancelResult)
                return
            }
            runSSH(arguments: [
                "-S", controlPath,
                "-O", "forward",
                "-R", specification,
                destination
            ], completion: completion)
        }
    }

    func stop() {
        let active = commands
        commands.removeAll()
        for process in active where process.isRunning { process.terminate() }
    }

    private func runRemoteShell(
        _ command: String,
        timeout: TimeInterval = 15,
        completion: @escaping (RemoteCommandResult) -> Void
    ) {
        runSSH(arguments: [
            "-S", controlPath,
            "-o", "BatchMode=yes",
            destination,
            command
        ], timeout: timeout, completion: completion)
    }

    private func runSSH(
        arguments: [String],
        timeout: TimeInterval = 15,
        completion: @escaping (RemoteCommandResult) -> Void
    ) {
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        commands.append(process)

        process.terminationHandler = { [weak self, weak process] terminated in
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self)
            DispatchQueue.main.async {
                guard let self, let process else { return }
                self.commands.removeAll { $0 === process }
                completion(RemoteCommandResult(status: terminated.terminationStatus, output: output))
            }
        }

        do {
            try process.run()
        } catch {
            commands.removeAll { $0 === process }
            completion(RemoteCommandResult(status: -1, output: error.localizedDescription))
            return
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak process] in
            guard let process, process.isRunning else { return }
            process.terminate()
        }
    }

    private static func lastUsefulLine(in output: String) -> String {
        output
            .split(whereSeparator: { $0.isNewline })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .last(where: { !$0.isEmpty }) ?? ""
    }
}
