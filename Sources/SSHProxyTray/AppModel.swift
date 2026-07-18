import AppKit
import Foundation
import ServiceManagement
import SSHProxyCore

enum AppModelError: LocalizedError {
    case passwordRequired
    case askPassHelperMissing
    case localPortInUse(Int)
    case ruleDisabled
    case sshConfigMissing
    case noImportableSSHConfigHosts

    var errorDescription: String? {
        switch self {
        case .passwordRequired:
            return SSHProxyL10n.string("app_error.password_required", default: "Enter the SSH password.")
        case .askPassHelperMissing:
            return SSHProxyL10n.string("app_error.askpass_missing", default: "The password helper is missing from the app bundle.")
        case .localPortInUse(let port):
            return SSHProxyL10n.format(
                "app_error.local_port_in_use",
                default: "Local port %d is already in use. Choose another port.",
                port
            )
        case .ruleDisabled:
            return SSHProxyL10n.string("app_error.rule_disabled", default: "Enable this rule before connecting.")
        case .sshConfigMissing:
            return SSHProxyL10n.string("app_error.ssh_config_missing", default: "~/.ssh/config does not exist or cannot be read.")
        case .noImportableSSHConfigHosts:
            return SSHProxyL10n.string("app_error.no_importable_hosts", default: "No new concrete Host aliases were found in ~/.ssh/config.")
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var profiles: [TunnelProfile] = [] {
        didSet {
            for profile in profiles {
                if !profile.savePassword,
                   oldValue.first(where: { $0.id == profile.id })?.savePassword == true {
                    try? keychain.deletePassword(profileID: profile.id)
                }
                if !profile.enabled,
                   oldValue.first(where: { $0.id == profile.id })?.enabled != false {
                    disconnect(profileID: profile.id)
                }
            }
            persistConfiguration()
        }
    }
    @Published var selectedProfileID: UUID? {
        didSet {
            if oldValue != selectedProfileID { enteredPassword = "" }
            persistConfiguration()
        }
    }
    @Published var enteredPassword = ""
    @Published private(set) var statuses: [UUID: TunnelStatus] = [:]
    @Published private(set) var logsByProfile: [UUID: [String]] = [:]
    @Published private(set) var remoteForwardInspections: [UUID: RemoteForwardInspection] = [:]
    @Published private(set) var launchAtLoginEnabled = false
    @Published var errorMessage: String?

    private let configurationStore = ConfigurationStore()
    private let keychain = KeychainStore()
    private var runners: [UUID: TunnelRunner] = [:]
    private var isLoading = true

    init() {
        do {
            let configuration = try configurationStore.load()
            profiles = configuration.profiles
            selectedProfileID = configuration.selectedProfileID ?? profiles.first?.id
        } catch {
            errorMessage = error.localizedDescription
        }
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        isLoading = false

        if CommandLine.arguments.contains("--enable-launch-at-login") {
            setLaunchAtLogin(true)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.connectAutomaticProfiles()
        }
    }

    var selectedProfile: TunnelProfile? {
        guard let selectedProfileID else { return nil }
        return profiles.first(where: { $0.id == selectedProfileID })
    }

    var summaryStatus: TunnelStatus {
        let values = Array(statuses.values)
        if values.contains(.connected) { return .connected }
        if values.contains(.connecting) { return .connecting }
        if values.contains(.disconnecting) { return .disconnecting }
        if let failed = values.first(where: {
            if case .failed = $0 { return true }
            return false
        }) { return failed }
        return .disconnected
    }

    var connectedCount: Int {
        statuses.values.filter { $0 == .connected }.count
    }

    func status(for profileID: UUID) -> TunnelStatus {
        statuses[profileID] ?? .disconnected
    }

    func logs(for profileID: UUID) -> [String] {
        logsByProfile[profileID] ?? []
    }

    func remoteForwardInspection(for profileID: UUID) -> RemoteForwardInspection {
        remoteForwardInspections[profileID] ?? .notChecked
    }

    func isRunning(profileID: UUID) -> Bool {
        switch status(for: profileID) {
        case .connecting, .connected, .disconnecting: return true
        case .disconnected, .failed: return false
        }
    }

    func addProfile() {
        var usedPorts = configuredLocalPorts
        let port = nextAvailableLocalPort(excluding: usedPorts)
        usedPorts.insert(port)
        let httpPort = nextAvailableLocalPort(excluding: usedPorts)
        let profile = TunnelProfile(
            isEnabled: true,
            name: SSHProxyL10n.string("profile.new_tunnel", default: "New Tunnel"),
            localPort: port,
            httpProxyPort: httpPort
        )
        profiles.append(profile)
        selectedProfileID = profile.id
    }

    func duplicateSelectedProfile() {
        guard var profile = selectedProfile else { return }
        profile.id = UUID()
        profile.name += SSHProxyL10n.string("profile.copy_suffix", default: " Copy")
        profile.autoConnect = false
        profile.isEnabled = true
        if profile.mode == .remoteForward {
            profile.remotePort = min(profile.remotePort + 1, 65535)
        } else {
            var usedPorts = configuredLocalPorts
            profile.localPort = nextAvailableLocalPort(excluding: usedPorts)
            usedPorts.insert(profile.localPort)
            if profile.mode == .socks5, profile.httpProxyPort != nil {
                profile.httpProxyPort = nextAvailableLocalPort(excluding: usedPorts)
            }
        }
        profiles.append(profile)
        selectedProfileID = profile.id
    }

    func removeSelectedProfile() {
        guard let selectedProfileID,
              let index = profiles.firstIndex(where: { $0.id == selectedProfileID }) else { return }
        disconnect(profileID: selectedProfileID)
        try? keychain.deletePassword(profileID: selectedProfileID)
        profiles.remove(at: index)
        logsByProfile.removeValue(forKey: selectedProfileID)
        statuses.removeValue(forKey: selectedProfileID)
        remoteForwardInspections.removeValue(forKey: selectedProfileID)
        self.selectedProfileID = profiles.first?.id
        enteredPassword = ""
    }

    func importSSHConfigProfiles() {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh/config")
        guard let contents = try? String(contentsOf: configURL, encoding: .utf8) else {
            errorMessage = AppModelError.sshConfigMissing.localizedDescription
            return
        }

        let existing = Set(profiles.filter { $0.authentication == .sshConfig }.map { $0.sshHost.lowercased() })
        let aliases = SSHConfigHostParser.aliases(from: contents)
            .filter { !existing.contains($0.lowercased()) }
        guard !aliases.isEmpty else {
            errorMessage = AppModelError.noImportableSSHConfigHosts.localizedDescription
            return
        }

        var usedPorts = configuredLocalPorts
        var imported: [TunnelProfile] = []
        for alias in aliases {
            let port = nextAvailableLocalPort(excluding: usedPorts)
            usedPorts.insert(port)
            let httpPort = nextAvailableLocalPort(excluding: usedPorts)
            usedPorts.insert(httpPort)
            imported.append(TunnelProfile(
                isEnabled: true,
                name: alias,
                sshHost: alias,
                authentication: .sshConfig,
                localPort: port,
                httpProxyPort: httpPort
            ))
        }
        profiles.append(contentsOf: imported)
        selectedProfileID = imported.first?.id
        errorMessage = nil
    }

    func connectSelected() {
        guard let profile = selectedProfile else { return }
        connect(profile)
    }

    func connect(_ profile: TunnelProfile) {
        do {
            guard profile.enabled else { throw AppModelError.ruleDisabled }
            guard !isRunning(profileID: profile.id) else { return }
            try ProfileValidator.validate(profile)
            if profile.mode != .remoteForward,
               !LocalPortAvailability.isAvailable(host: profile.localHost, port: profile.localPort) {
                throw AppModelError.localPortInUse(profile.localPort)
            }
            if profile.mode == .socks5,
               let httpProxyPort = profile.httpProxyPort,
               !LocalPortAvailability.isAvailable(host: profile.localHost, port: httpProxyPort) {
                throw AppModelError.localPortInUse(httpProxyPort)
            }

            var password: String?
            if profile.authentication == .password {
                password = enteredPassword.isEmpty ? try keychain.password(profileID: profile.id) : enteredPassword
                guard let password, !password.isEmpty else { throw AppModelError.passwordRequired }
                if profile.savePassword {
                    try keychain.savePassword(password, profileID: profile.id)
                } else {
                    try keychain.deletePassword(profileID: profile.id)
                }
            }

            let helper = askPassHelperPath()
            if profile.authentication == .password,
               !FileManager.default.isExecutableFile(atPath: helper) {
                throw AppModelError.askPassHelperMissing
            }

            let runner = runners[profile.id] ?? TunnelRunner()
            runners[profile.id] = runner
            runner.onUpdate = { [weak self] status, logs in
                guard let self else { return }
                let previousStatus = self.statuses[profile.id]
                self.statuses[profile.id] = status
                self.logsByProfile[profile.id] = logs
                if status == .connected, self.selectedProfileID == profile.id {
                    self.enteredPassword = ""
                }
                if case .failed(let message) = status {
                    self.errorMessage = "\(profile.name): \(message)"
                }
                if status == .disconnected,
                   !self.profiles.contains(where: { $0.id == profile.id }) {
                    self.runners.removeValue(forKey: profile.id)
                    self.statuses.removeValue(forKey: profile.id)
                    self.logsByProfile.removeValue(forKey: profile.id)
                }
                if status == .connected,
                   previousStatus != .connected,
                   profile.mode == .remoteForward {
                    self.inspectRemoteForward(profileID: profile.id)
                } else if status == .disconnected {
                    self.remoteForwardInspections[profile.id] = .notChecked
                }
            }

            errorMessage = nil
            try runner.connect(profile: profile, password: password, askPassPath: helper)
        } catch {
            statuses[profile.id] = .failed(error.localizedDescription)
            errorMessage = "\(profile.name): \(error.localizedDescription)"
        }
    }

    func disconnect(profileID: UUID) {
        runners[profileID]?.disconnect()
        if runners[profileID] == nil { statuses[profileID] = .disconnected }
    }

    func inspectRemoteForward(profileID: UUID) {
        guard let profile = profiles.first(where: { $0.id == profileID }),
              profile.mode == .remoteForward,
              status(for: profileID) == .connected,
              let runner = runners[profileID] else {
            remoteForwardInspections[profileID] = .notChecked
            return
        }
        remoteForwardInspections[profileID] = .checking
        runner.inspectRemoteForward(port: profile.remotePort) { [weak self] result in
            guard let self, self.status(for: profileID) == .connected else { return }
            self.remoteForwardInspections[profileID] = result
        }
    }

    func configureRemoteServer(profileID: UUID) {
        guard let profile = profiles.first(where: { $0.id == profileID }),
              profile.mode == .remoteForward,
              profile.remoteHost == "0.0.0.0",
              status(for: profileID) == .connected,
              let runner = runners[profileID] else { return }

        remoteForwardInspections[profileID] = .configuring
        runner.configureGatewayPorts { [weak self, weak runner] result in
            guard let self, let runner else { return }
            guard self.status(for: profileID) == .connected else { return }
            guard result.status == 0,
                  result.output.contains("SSH_PROXY_TRAY_CONFIGURED") else {
                let message = self.remoteConfigurationFailureMessage(result)
                self.remoteForwardInspections[profileID] = .unsupported(message)
                self.errorMessage = "\(profile.name): \(message)"
                return
            }

            runner.refreshRemoteForward(profile: profile) { [weak self] refreshResult in
                guard let self else { return }
                guard self.status(for: profileID) == .connected else { return }
                guard refreshResult.status == 0 else {
                    let message = SSHProxyL10n.string(
                        "remote_check.refresh_failed",
                        default: "The server was configured, but the remote forward could not be refreshed. Disconnect and reconnect this rule."
                    )
                    self.remoteForwardInspections[profileID] = .unsupported(message)
                    self.errorMessage = "\(profile.name): \(message)"
                    return
                }
                self.errorMessage = nil
                self.remoteForwardInspections[profileID] = .checking
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.inspectRemoteForward(profileID: profileID)
                }
            }
        }
    }

    func disconnectAll(completion: (() -> Void)? = nil) {
        let activeRunners = Array(runners.values)
        guard !activeRunners.isEmpty else {
            completion?()
            return
        }

        var remaining = activeRunners.count
        for runner in activeRunners {
            runner.disconnect {
                remaining -= 1
                if remaining == 0 { completion?() }
            }
        }
    }

    func copySelectedEndpoint() {
        guard let profile = selectedProfile else { return }
        copyEndpoint(profile.proxyURL)
    }

    func copyEndpoint(_ endpoint: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(endpoint, forType: .string)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            errorMessage = nil
        } catch {
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            errorMessage = error.localizedDescription
        }
    }

    private func connectAutomaticProfiles() {
        for (offset, profile) in profiles.filter({ $0.enabled && $0.autoConnect }).enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(offset) * 0.2) { [weak self] in
                self?.connect(profile)
            }
        }
    }

    private func nextAvailableLocalPort(excluding usedPorts: Set<Int>) -> Int {
        (18080...18179).first {
            !usedPorts.contains($0) && LocalPortAvailability.isAvailable(host: "127.0.0.1", port: $0)
        } ?? 18080
    }

    private var configuredLocalPorts: Set<Int> {
        Set(profiles.flatMap { profile in
            var ports = [profile.localPort]
            if profile.mode == .socks5, let httpProxyPort = profile.httpProxyPort {
                ports.append(httpProxyPort)
            }
            return ports
        })
    }

    private func persistConfiguration() {
        guard !isLoading else { return }
        do {
            try configurationStore.save(
                AppConfiguration(selectedProfileID: selectedProfileID, profiles: profiles)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func askPassHelperPath() -> String {
        let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent()
            ?? URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        return executableDirectory.appendingPathComponent("SSHAskPass").path
    }

    private func remoteConfigurationFailureMessage(_ result: RemoteCommandResult) -> String {
        if result.output.contains("SSH_PROXY_TRAY_SUDO_REQUIRED") {
            return SSHProxyL10n.string(
                "remote_check.sudo_required",
                default: "Passwordless sudo is not available. Configure GatewayPorts in a terminal, then reconnect."
            )
        }
        if result.output.contains("SSH_PROXY_TRAY_DROPIN_NOT_INCLUDED") {
            return SSHProxyL10n.string(
                "remote_check.dropin_unavailable",
                default: "This SSH server does not load sshd_config.d drop-in files. Configure GatewayPorts manually."
            )
        }
        if result.output.contains("SSH_PROXY_TRAY_UNSUPPORTED_SERVER")
            || result.output.contains("SSH_PROXY_TRAY_SSH_SERVICE_NOT_FOUND") {
            return SSHProxyL10n.string(
                "remote_check.server_unsupported",
                default: "Automatic configuration is not supported on this server. Configure GatewayPorts manually."
            )
        }
        if result.output.contains("SSH_PROXY_TRAY_VALIDATION_FAILED") {
            return SSHProxyL10n.string(
                "remote_check.validation_failed",
                default: "The SSH configuration failed validation and was rolled back."
            )
        }
        if result.output.contains("SSH_PROXY_TRAY_RELOAD_FAILED") {
            return SSHProxyL10n.string(
                "remote_check.reload_failed",
                default: "The SSH service could not be reloaded. The previous configuration was restored."
            )
        }
        return SSHProxyL10n.string(
            "remote_check.configuration_failed",
            default: "The SSH server could not be configured automatically."
        )
    }
}
