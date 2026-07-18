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
    @Published private(set) var launchAtLoginEnabled = false
    @Published var errorMessage: String?

    private let configurationStore = ConfigurationStore()
    private let keychain = KeychainStore()
    private var runners: [UUID: TunnelRunner] = [:]
    private var isLoading = true
    private var terminationObserver: NSObjectProtocol?

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

        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.disconnectAll() }
        }

        if CommandLine.arguments.contains("--enable-launch-at-login") {
            setLaunchAtLogin(true)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.connectAutomaticProfiles()
        }
    }

    deinit {
        if let terminationObserver { NotificationCenter.default.removeObserver(terminationObserver) }
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

    func isRunning(profileID: UUID) -> Bool {
        switch status(for: profileID) {
        case .connecting, .connected, .disconnecting: return true
        case .disconnected, .failed: return false
        }
    }

    func addProfile() {
        let port = nextAvailableLocalPort(excluding: Set(profiles.map(\.localPort)))
        let profile = TunnelProfile(
            isEnabled: true,
            name: SSHProxyL10n.string("profile.new_tunnel", default: "New Tunnel"),
            localPort: port
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
            profile.localPort = nextAvailableLocalPort(excluding: Set(profiles.map(\.localPort)))
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

        var usedPorts = Set(profiles.map(\.localPort))
        var imported: [TunnelProfile] = []
        for alias in aliases {
            let port = nextAvailableLocalPort(excluding: usedPorts)
            usedPorts.insert(port)
            imported.append(TunnelProfile(
                isEnabled: true,
                name: alias,
                sshHost: alias,
                authentication: .sshConfig,
                localPort: port
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

    func disconnectAll() {
        for runner in runners.values { runner.disconnect() }
    }

    func copySelectedEndpoint() {
        guard let profile = selectedProfile else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(profile.proxyURL, forType: .string)
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
}
