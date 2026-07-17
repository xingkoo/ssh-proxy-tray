import AppKit
import Foundation
import ServiceManagement
import SSHProxyCore

enum AppModelError: LocalizedError {
    case passwordRequired
    case askPassHelperMissing

    var errorDescription: String? {
        switch self {
        case .passwordRequired: return "Enter the SSH password."
        case .askPassHelperMissing: return "The password helper is missing from the app bundle."
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var profiles: [TunnelProfile] = [] {
        didSet {
            for profile in profiles where !profile.savePassword {
                if oldValue.first(where: { $0.id == profile.id })?.savePassword == true {
                    try? keychain.deletePassword(profileID: profile.id)
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
    @Published private(set) var status: TunnelStatus = .disconnected
    @Published private(set) var logs: [String] = []
    @Published private(set) var activeProfileID: UUID?
    @Published private(set) var launchAtLoginEnabled = false
    @Published var errorMessage: String?

    private let configurationStore = ConfigurationStore()
    private let keychain = KeychainStore()
    private let runner = TunnelRunner()
    private var isLoading = true
    private var terminationObserver: NSObjectProtocol?

    init() {
        runner.onUpdate = { [weak self] status, logs in
            self?.status = status
            self?.logs = logs
            if case .disconnected = status { self?.activeProfileID = nil }
            if case .failed(let message) = status {
                self?.activeProfileID = nil
                self?.errorMessage = message
            }
        }

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
            MainActor.assumeIsolated { self?.runner.disconnect() }
        }

        if CommandLine.arguments.contains("--enable-launch-at-login") {
            setLaunchAtLogin(true)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.connectFirstAutomaticProfile()
        }
    }

    deinit {
        if let terminationObserver { NotificationCenter.default.removeObserver(terminationObserver) }
    }

    var selectedProfile: TunnelProfile? {
        guard let selectedProfileID else { return nil }
        return profiles.first(where: { $0.id == selectedProfileID })
    }

    func addProfile() {
        let usedPorts = Set(profiles.map(\.localPort))
        var port = 1080
        while usedPorts.contains(port) { port += 1 }
        let profile = TunnelProfile(localPort: port)
        profiles.append(profile)
        selectedProfileID = profile.id
    }

    func removeSelectedProfile() {
        guard let selectedProfileID,
              let index = profiles.firstIndex(where: { $0.id == selectedProfileID }) else { return }
        if activeProfileID == selectedProfileID { disconnect() }
        try? keychain.deletePassword(profileID: selectedProfileID)
        profiles.remove(at: index)
        self.selectedProfileID = profiles.first?.id
        enteredPassword = ""
    }

    func connectSelected() {
        guard let profile = selectedProfile else { return }
        connect(profile)
    }

    func connect(_ profile: TunnelProfile) {
        do {
            try ProfileValidator.validate(profile)
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
            errorMessage = nil
            activeProfileID = profile.id
            try runner.connect(profile: profile, password: password, askPassPath: helper)
        } catch {
            activeProfileID = nil
            errorMessage = error.localizedDescription
            status = .failed(error.localizedDescription)
        }
    }

    func disconnect() {
        runner.disconnect()
        activeProfileID = nil
    }

    func copyProxyURL() {
        guard let profile = activeProfileID.flatMap({ id in profiles.first(where: { $0.id == id }) })
                ?? selectedProfile else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(profile.proxyURL, forType: .string)
    }

    func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
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

    private func connectFirstAutomaticProfile() {
        guard activeProfileID == nil,
              let profile = profiles.first(where: \.autoConnect) else { return }
        selectedProfileID = profile.id
        connect(profile)
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
