import AppKit
import SSHProxyCore
import SwiftUI

private func ui(_ key: String, _ defaultValue: String) -> String {
    SSHProxyL10n.string(key, default: defaultValue)
}

private enum AppTheme {
    static let canvas = Color(red: 0.965, green: 0.97, blue: 0.98)
    static let panel = Color.white
    static let sidebar = Color(red: 0.94, green: 0.95, blue: 0.965)
    static let sidebarRaised = Color.white
    static let sidebarPrimary = Color(red: 0.12, green: 0.14, blue: 0.19)
    static let sidebarSecondary = Color(red: 0.43, green: 0.47, blue: 0.54)
    static let ink = Color(red: 0.10, green: 0.12, blue: 0.16)
    static let muted = Color(red: 0.42, green: 0.46, blue: 0.53)
    static let accent = Color(red: 0.15, green: 0.66, blue: 0.48)
    static let purple = Color(red: 0.42, green: 0.34, blue: 0.84)
    static let teal = Color(red: 0.08, green: 0.57, blue: 0.52)
    static let amber = Color(red: 0.83, green: 0.50, blue: 0.15)
    static let danger = Color(red: 0.78, green: 0.22, blue: 0.25)
    static let border = Color.black.opacity(0.08)
}

struct MainWindowView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage(SSHProxyL10n.languageDefaultsKey) private var language = "system"

    var body: some View {
        HStack(spacing: 0) {
            RuleSidebar(language: $language)
                .environmentObject(model)
                .frame(width: 264)

            Rectangle()
                .fill(AppTheme.border)
                .frame(width: 1)

            Group {
                if let id = model.selectedProfileID,
                   let index = model.profiles.firstIndex(where: { $0.id == id }) {
                    RuleDetailView(
                        profile: $model.profiles[index],
                        password: $model.enteredPassword
                    )
                    .environmentObject(model)
                } else {
                    EmptyRulesView()
                        .environmentObject(model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .tint(AppTheme.accent)
        .background(AppTheme.canvas)
        .frame(minWidth: 1060, minHeight: 720)
        .id(language)
    }
}

private struct RuleSidebar: View {
    @EnvironmentObject private var model: AppModel
    @Binding var language: String
    @State private var showingLanguagePicker = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .shadow(color: AppTheme.accent.opacity(0.22), radius: 8, y: 4)

                VStack(alignment: .leading, spacing: 1) {
                    Text("SSH Proxy Tray")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.sidebarPrimary)
                    Text(sidebarSummary)
                        .font(.caption)
                        .foregroundStyle(AppTheme.sidebarSecondary)
                }

                Spacer()

                Button {
                    model.addProfile()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.sidebarPrimary)
                .background(AppTheme.sidebarRaised)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .shadow(color: Color.black.opacity(0.05), radius: 6, y: 2)
                .help(ui("ui.add_rule", "Add rule"))
            }
            .padding(.horizontal, 18)
            .frame(height: 86)

            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(model.profiles) { profile in
                        Button {
                            model.selectedProfileID = profile.id
                        } label: {
                            RuleRow(
                                profile: profile,
                                status: model.status(for: profile.id),
                                isSelected: model.selectedProfileID == profile.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
            }

            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)

            HStack(spacing: 14) {
                sidebarButton(
                    symbol: "doc.on.doc",
                    help: ui("ui.duplicate_rule", "Duplicate rule"),
                    disabled: model.selectedProfileID == nil,
                    action: model.duplicateSelectedProfile
                )
                sidebarButton(
                    symbol: "square.and.arrow.down",
                    help: ui("ui.import_ssh_config_help", "Import hosts from ~/.ssh/config"),
                    action: model.importSSHConfigProfiles
                )
                languageMenu
                sidebarButton(
                    symbol: "trash",
                    help: ui("ui.delete_rule", "Delete rule"),
                    disabled: model.selectedProfileID == nil,
                    role: .destructive,
                    action: model.removeSelectedProfile
                )
                Spacer()
            }
            .padding(.horizontal, 18)
            .frame(height: 48)

            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)

            HStack(spacing: 10) {
                Toggle(
                    ui("ui.launch_at_login", "Launch at login"),
                    isOn: Binding(
                        get: { model.launchAtLoginEnabled },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.small)
                .foregroundStyle(AppTheme.sidebarPrimary)
                .help(ui(
                    "help.launch_at_login",
                    "Starts the app after login. Only rules with auto-connect enabled will connect automatically."
                ))

                Spacer()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .help(ui("ui.quit", "Quit"))
            }
            .padding(.horizontal, 18)
            .frame(height: 56)
        }
        .foregroundStyle(AppTheme.sidebarPrimary)
        .background(AppTheme.sidebar)
    }

    private var sidebarSummary: String {
        SSHProxyL10n.format(
            "ui.sidebar_summary",
            default: "%d connected · %d rules",
            model.connectedCount,
            model.profiles.count
        )
    }

    private var languageMenu: some View {
        Button {
            showingLanguagePicker.toggle()
        } label: {
            Image(systemName: "globe")
                .frame(width: 20, height: 20)
                .padding(7)
                .background(AppTheme.sidebarRaised.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.sidebarSecondary)
        .help(ui("ui.language", "Language"))
        .popover(isPresented: $showingLanguagePicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(ui("ui.language", "Language"))
                    .font(.headline)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
                languageOption("system", title: ui("language.system", "Follow System"))
                languageOption("zh-Hans", title: ui("language.simplified_chinese", "Simplified Chinese"))
                languageOption("en", title: ui("language.english", "English"))
            }
            .padding(10)
            .frame(width: 210)
        }
    }

    private func languageOption(_ value: String, title: String) -> some View {
        Button {
            language = value
            showingLanguagePicker = false
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                if language == value {
                    Image(systemName: "checkmark")
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sidebarButton(
        symbol: String,
        help: String,
        disabled: Bool = false,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: symbol)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.sidebarSecondary)
        .padding(7)
        .background(AppTheme.sidebarRaised.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .disabled(disabled)
        .help(help)
    }
}

private struct RuleRow: View {
    let profile: TunnelProfile
    let status: TunnelStatus
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: modeSymbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(profile.enabled ? modeColor : AppTheme.sidebarSecondary)
                .frame(width: 28, height: 28)
                .background(modeColor.opacity(profile.enabled ? 0.18 : 0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(profile.name.isEmpty ? ui("ui.unnamed_rule", "Unnamed Rule") : profile.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.sidebarPrimary)
                    .lineLimit(1)
                Text(rowSummary)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.sidebarSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 4)

            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                .help(statusTitle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .background(isSelected ? AppTheme.sidebarRaised : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.accent.opacity(0.7), lineWidth: 1)
            }
        }
    }

    private var rowSummary: String {
        switch profile.mode {
        case .socks5:
            if let httpPort = profile.httpProxyPort {
                return "SOCKS :\(profile.localPort)  HTTP :\(httpPort)"
            }
            return "SOCKS :\(profile.localPort)"
        case .localForward:
            return ":\(profile.localPort) -> \(profile.remoteHost):\(profile.remotePort)"
        case .remoteForward:
            return "\(profile.remoteHost):\(profile.remotePort) -> :\(profile.localPort)"
        }
    }

    private var modeSymbol: String {
        switch profile.mode {
        case .socks5: return "network"
        case .localForward: return "arrow.right"
        case .remoteForward: return "arrow.left"
        }
    }

    private var modeColor: Color {
        switch profile.mode {
        case .socks5: return Color(red: 0.35, green: 0.62, blue: 0.95)
        case .localForward: return AppTheme.teal
        case .remoteForward: return Color(red: 0.62, green: 0.48, blue: 0.95)
        }
    }

    private var statusTitle: String {
        profile.enabled ? status.title : ui("status.disabled", "Disabled")
    }

    private var statusColor: Color {
        guard profile.enabled else { return AppTheme.sidebarSecondary }
        switch status {
        case .disconnected: return AppTheme.sidebarSecondary
        case .connecting, .disconnecting: return AppTheme.amber
        case .connected: return Color(red: 0.25, green: 0.82, blue: 0.56)
        case .failed: return Color(red: 0.98, green: 0.38, blue: 0.38)
        }
    }
}

private struct RuleDetailView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var profile: TunnelProfile
    @Binding var password: String
    @State private var showAdvanced = false
    @State private var showLogs = false
    @State private var confirmServerConfiguration = false

    private var status: TunnelStatus { model.status(for: profile.id) }
    private var running: Bool { model.isRunning(profileID: profile.id) }
    private var inspection: RemoteForwardInspection {
        model.remoteForwardInspection(for: profile.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            detailHeader
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)

            RouteOverview(profile: profile)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    SettingsSection(
                        title: ui("ui.section.rule", "Rule"),
                        symbol: "slider.horizontal.3",
                        helpTitle: ui("help.rule_type.title", "Choose the direction that matches your task"),
                        helpMessage: ui(
                            "help.rule_type.body",
                            "Proxy provides SOCKS5 and optional HTTP/HTTPS. Local Forward lets this Mac reach a remote-side service. Remote Forward lets the SSH server reach a service on this Mac."
                        )
                    ) {
                        SettingsGrid {
                            SettingRow(title: ui("ui.name", "Name")) {
                                TextField(ui("ui.name", "Name"), text: $profile.name)
                            }
                            SettingRow(title: ui("ui.type", "Type")) {
                                ModeSelector(selection: $profile.mode, help: modeHelp)
                            }
                            SettingRow(title: ui("ui.automation", "Automation")) {
                                Toggle(
                                    ui("ui.connect_on_start", "Connect when the app starts"),
                                    isOn: $profile.autoConnect
                                )
                                .toggleStyle(.switch)
                                .help(ui(
                                    "help.auto_connect",
                                    "Connects this rule when SSH Proxy Tray starts. Launch at login is a separate app-wide setting."
                                ))
                            }
                        }
                        .configurationLocked(running)
                    }

                    SettingsSection(
                        title: ui("ui.section.forwarding", "Forwarding"),
                        symbol: "arrow.left.arrow.right",
                        helpTitle: forwardingHelpTitle,
                        helpMessage: forwardingHelpMessage
                    ) {
                        SettingsGrid { forwardingFields }
                            .configurationLocked(running)

                        if profile.mode == .remoteForward {
                            Divider().padding(.vertical, 2)
                            RemoteListenerStatusView(
                                profile: profile,
                                inspection: inspection,
                                connected: status == .connected,
                                onCheck: { model.inspectRemoteForward(profileID: profile.id) },
                                onConfigure: { confirmServerConfiguration = true }
                            )
                        }
                    }

                    SettingsSection(
                        title: ui("ui.section.ssh_connection", "SSH Connection"),
                        symbol: "terminal",
                        helpTitle: ui("help.authentication.title", "Choose how OpenSSH authenticates"),
                        helpMessage: ui(
                            "help.authentication.body",
                            "SSH Config uses an existing alias. Key / Certificate uses explicit fields. Password is saved only when Keychain storage is enabled."
                        )
                    ) {
                        SettingsGrid { sshConnectionFields }
                            .configurationLocked(running)
                    }

                    DisclosureSection(
                        title: ui("ui.section.advanced_ssh", "Advanced SSH"),
                        symbol: "gearshape",
                        isExpanded: $showAdvanced
                    ) {
                        SettingsGrid { advancedFields }
                            .configurationLocked(running)
                    }

                    if let errorMessage = model.errorMessage,
                       errorMessage.hasPrefix(profile.name + ":") {
                        MessageBanner(
                            symbol: "exclamationmark.triangle.fill",
                            color: .red,
                            text: errorMessage
                        )
                    }

                    let logs = model.logs(for: profile.id)
                    if !logs.isEmpty {
                        DisclosureSection(
                            title: ui("ui.section.connection_log", "Connection Log"),
                            symbol: "text.alignleft",
                            isExpanded: $showLogs
                        ) {
                            Text(logs.suffix(12).joined(separator: "\n"))
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .frame(maxWidth: 860)
                .frame(maxWidth: .infinity)
                .textFieldStyle(SoftTextFieldStyle())
            }
            .background(AppTheme.canvas)
        }
        .background(AppTheme.canvas)
        .alert(
            ui("remote_check.configure_title", "Configure SSH Server?"),
            isPresented: $confirmServerConfiguration
        ) {
            Button(ui("ui.cancel", "Cancel"), role: .cancel) {}
            Button(ui("remote_check.configure_action", "Configure Server"), role: .destructive) {
                model.configureRemoteServer(profileID: profile.id)
            }
        } message: {
            Text(ui(
                "remote_check.configure_confirmation",
                "The app will use passwordless sudo to back up the SSH configuration, enable GatewayPorts clientspecified, validate it, reload SSH, and refresh only this remote forward. This server-wide policy can affect other SSH users."
            ))
        }
    }

    private var detailHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(profile.name.isEmpty ? ui("ui.unnamed_rule", "Unnamed Rule") : profile.name)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(1)
                    Text(profile.mode.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(modeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(modeColor.opacity(0.11))
                        .clipShape(Capsule())
                }
                HStack(spacing: 6) {
                    Circle().fill(statusColor).frame(width: 8, height: 8)
                    Text(profile.enabled ? status.title : ui("status.disabled", "Disabled"))
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                    if running {
                        Label(ui("ui.configuration_locked", "Configuration locked while connected"), systemImage: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.muted)
                    }
                }
            }

            Spacer()

            Toggle(ui("ui.enabled", "Enabled"), isOn: enabledBinding)
                .toggleStyle(.switch)
                .controlSize(.small)
                .foregroundStyle(AppTheme.muted)

            endpointCopyControl

            if running {
                Button(role: .destructive) {
                    model.disconnect(profileID: profile.id)
                } label: {
                    Label(ui("ui.disconnect", "Disconnect"), systemImage: "stop.fill")
                }
                .buttonStyle(ActionButtonStyle(tint: AppTheme.danger))
                .disabled(status == .disconnecting)
            } else {
                Button {
                    model.connect(profile)
                } label: {
                    Label(ui("ui.connect", "Connect"), systemImage: "play.fill")
                }
                .buttonStyle(ActionButtonStyle(tint: AppTheme.accent))
                .disabled(!profile.enabled)
            }
        }
        .padding(.horizontal, 26)
        .frame(height: 88)
        .background(AppTheme.panel)
    }

    private var modeColor: Color {
        switch profile.mode {
        case .socks5: return Color(red: 0.28, green: 0.45, blue: 0.86)
        case .localForward: return AppTheme.teal
        case .remoteForward: return Color(red: 0.53, green: 0.38, blue: 0.80)
        }
    }

    @ViewBuilder
    private var forwardingFields: some View {
        switch profile.mode {
        case .socks5:
            SettingRow(title: ui("ui.local_bind_address", "Local bind address")) {
                TextField(ui("ui.local_bind_address", "Local bind address"), text: $profile.localHost)
                    .help(ui("help.local_bind_address", "Loopback keeps the listener available only on this Mac."))
            }
            SettingRow(title: ui("ui.socks_proxy_port", "SOCKS proxy port")) {
                TextField("", value: $profile.localPort, format: .number).labelsHidden()
            }
            SettingRow(title: ui("ui.http_https_proxy", "HTTP/HTTPS proxy")) {
                Toggle(ui("ui.provide_http_proxy", "Also provide HTTP/HTTPS proxy"), isOn: httpProxyEnabledBinding)
                    .toggleStyle(.switch)
            }
            if profile.httpProxyPort != nil {
                SettingRow(title: ui("ui.http_proxy_port", "HTTP proxy port")) {
                    TextField("", value: optionalIntBinding(\.httpProxyPort, default: suggestedHTTPProxyPort), format: .number)
                        .labelsHidden()
                }
            }
        case .localForward:
            SettingRow(title: ui("ui.local_listener", "On this Mac")) {
                HostPortFields(host: $profile.localHost, port: $profile.localPort)
            }
            SettingRow(title: ui("ui.remote_destination", "Remote destination")) {
                HostPortFields(host: $profile.remoteHost, port: $profile.remotePort)
            }
        case .remoteForward:
            SettingRow(title: ui("ui.remote_access_scope", "Who can access")) {
                AccessScopeSelector(selection: remoteAccessBinding)
            }
            if remoteAccessBinding.wrappedValue == .custom {
                SettingRow(title: ui("ui.remote_bind_address", "Remote bind address")) {
                    TextField(ui("ui.remote_bind_address", "Remote bind address"), text: $profile.remoteHost)
                }
            }
            SettingRow(title: ui("ui.remote_listener", "On SSH server")) {
                HStack(spacing: 8) {
                    Text(remoteListenerHostLabel)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TextField("", value: $profile.remotePort, format: .number)
                        .labelsHidden()
                        .frame(width: 110)
                }
            }
            SettingRow(title: ui("ui.local_target", "Service on this Mac")) {
                HostPortFields(host: $profile.localHost, port: $profile.localPort)
            }
        }
    }

    @ViewBuilder
    private var sshConnectionFields: some View {
        SettingRow(title: ui("ui.authentication", "Authentication")) {
            AuthenticationSelector(selection: $profile.authentication)
        }
        SettingRow(title: profile.authentication == .sshConfig ? ui("ui.host_alias", "Host alias") : ui("ui.host", "Host")) {
            TextField("", text: $profile.sshHost).labelsHidden()
        }
        if profile.authentication != .sshConfig {
            SettingRow(title: ui("ui.username_and_port", "Username and SSH port")) {
                HStack(spacing: 8) {
                    TextField(ui("ui.username", "Username"), text: $profile.username)
                    TextField(ui("ui.ssh_port", "SSH port"), value: $profile.sshPort, format: .number)
                        .frame(width: 110)
                }
            }
        }
        if profile.authentication == .keyFile {
            SettingRow(title: ui("ui.private_key", "Private key")) {
                fileField(
                    value: $profile.identityFile,
                    panelTitle: ui("ui.choose_private_key", "Choose SSH Private Key")
                )
            }
            SettingRow(title: ui("ui.ssh_certificate", "SSH certificate")) {
                fileField(
                    value: optionalStringBinding(\.certificateFile),
                    panelTitle: ui("ui.choose_ssh_certificate", "Choose SSH Certificate")
                )
            }
        }
        if profile.authentication == .password {
            SettingRow(title: ui("ui.password", "Password")) {
                SecureField(ui("ui.password", "Password"), text: $password)
            }
            SettingRow(title: ui("ui.credential_storage", "Credential storage")) {
                Toggle(ui("ui.save_password_keychain", "Save password in Keychain"), isOn: $profile.savePassword)
                    .toggleStyle(.switch)
            }
        }
    }

    @ViewBuilder
    private var advancedFields: some View {
        SettingRow(title: "ProxyJump") {
            TextField("ProxyJump", text: optionalStringBinding(\.proxyJump))
        }
        SettingRow(title: ui("ui.compression", "Compression")) {
            Toggle(ui("ui.compression", "Compression"), isOn: optionalBoolBinding(\.compression, default: false))
                .toggleStyle(.switch)
        }
        SettingRow(title: ui("ui.connect_timeout", "Connect timeout (seconds)")) {
            TextField("", value: optionalIntBinding(\.connectTimeout, default: 10), format: .number)
                .labelsHidden()
        }
        SettingRow(title: ui("ui.server_alive_interval", "Server alive interval (seconds)")) {
            TextField("", value: optionalIntBinding(\.serverAliveInterval, default: 30), format: .number)
                .labelsHidden()
        }
        SettingRow(title: ui("ui.server_alive_count", "Server alive count")) {
            TextField("", value: optionalIntBinding(\.serverAliveCountMax, default: 3), format: .number)
                .labelsHidden()
        }
    }

    private func modeHelp(_ mode: TunnelMode) -> String {
        switch mode {
        case .socks5:
            return ui("help.mode.proxy", "Local app -> proxy port -> SSH tunnel -> network.")
        case .localForward:
            return ui("help.mode.local_forward", "This Mac -> SSH tunnel -> remote-side service.")
        case .remoteForward:
            return ui("help.mode.remote_forward", "SSH server -> SSH tunnel -> service on this Mac.")
        }
    }

    private var forwardingHelpTitle: String {
        switch profile.mode {
        case .socks5: return ui("help.forwarding.proxy.title", "Proxy endpoints share one SSH tunnel")
        case .localForward: return ui("help.forwarding.local.title", "Access a remote-side service from this Mac")
        case .remoteForward: return ui("help.forwarding.remote.title", "Access a service on this Mac from the SSH server")
        }
    }

    private var forwardingHelpMessage: String {
        switch profile.mode {
        case .socks5:
            return ui("help.forwarding.proxy.body", "SOCKS and HTTP use separate local ports but share one SSH connection.")
        case .localForward:
            return ui("help.forwarding.local.body", "This Mac's local port forwards to a destination reachable from the SSH server.")
        case .remoteForward:
            return ui("help.forwarding.remote.body", "A port on the SSH server forwards to a service on this Mac. External access requires GatewayPorts and firewall permission.")
        }
    }

    @ViewBuilder
    private var endpointCopyControl: some View {
        if profile.mode == .socks5, let httpProxyURL = profile.httpProxyURL {
            Menu {
                Button { model.copyEndpoint(profile.socksProxyURL) } label: {
                    Label(ui("ui.copy_socks_endpoint", "Copy SOCKS endpoint"), systemImage: "network")
                }
                Button { model.copyEndpoint(httpProxyURL) } label: {
                    Label(ui("ui.copy_http_endpoint", "Copy HTTP endpoint"), systemImage: "globe")
                }
            } label: {
                Image(systemName: "doc.on.doc")
                    .frame(width: 20, height: 20)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(ui("ui.copy_proxy_endpoint", "Copy SOCKS or HTTP endpoint"))
        } else {
            Button { model.copySelectedEndpoint() } label: {
                Image(systemName: "doc.on.doc")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless)
            .help(ui("ui.copy_endpoint", "Copy endpoint"))
        }
    }

    private var remoteListenerHostLabel: String {
        switch remoteAccessBinding.wrappedValue {
        case .serverOnly: return "127.0.0.1"
        case .external: return "0.0.0.0"
        case .custom: return profile.remoteHost
        }
    }

    private var remoteAccessBinding: Binding<RemoteAccessScope> {
        Binding(
            get: {
                if ["127.0.0.1", "localhost"].contains(profile.remoteHost) { return .serverOnly }
                if ["0.0.0.0", "::"].contains(profile.remoteHost) { return .external }
                return .custom
            },
            set: { scope in
                switch scope {
                case .serverOnly: profile.remoteHost = "127.0.0.1"
                case .external: profile.remoteHost = "0.0.0.0"
                case .custom:
                    if ["127.0.0.1", "localhost", "0.0.0.0", "::"].contains(profile.remoteHost) {
                        profile.remoteHost = ""
                    }
                }
            }
        )
    }

    private var httpProxyEnabledBinding: Binding<Bool> {
        Binding(
            get: { profile.httpProxyPort != nil },
            set: { profile.httpProxyPort = $0 ? (profile.httpProxyPort ?? suggestedHTTPProxyPort) : nil }
        )
    }

    private var suggestedHTTPProxyPort: Int {
        profile.localPort < 65535 ? profile.localPort + 1 : 18081
    }

    private var enabledBinding: Binding<Bool> {
        Binding(get: { profile.enabled }, set: { profile.isEnabled = $0 })
    }

    private var statusColor: Color {
        guard profile.enabled else { return .secondary }
        switch status {
        case .disconnected: return .secondary
        case .connecting, .disconnecting: return .orange
        case .connected: return .green
        case .failed: return .red
        }
    }

    private func optionalStringBinding(_ keyPath: WritableKeyPath<TunnelProfile, String?>) -> Binding<String> {
        Binding(
            get: { profile[keyPath: keyPath] ?? "" },
            set: { profile[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private func optionalBoolBinding(
        _ keyPath: WritableKeyPath<TunnelProfile, Bool?>,
        default defaultValue: Bool
    ) -> Binding<Bool> {
        Binding(
            get: { profile[keyPath: keyPath] ?? defaultValue },
            set: { profile[keyPath: keyPath] = $0 }
        )
    }

    private func optionalIntBinding(
        _ keyPath: WritableKeyPath<TunnelProfile, Int?>,
        default defaultValue: Int
    ) -> Binding<Int> {
        Binding(
            get: { profile[keyPath: keyPath] ?? defaultValue },
            set: { profile[keyPath: keyPath] = $0 }
        )
    }

    private func fileField(value: Binding<String>, panelTitle: String) -> some View {
        HStack(spacing: 8) {
            TextField("", text: value).labelsHidden()
            Button {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.allowsMultipleSelection = false
                panel.title = panelTitle
                if panel.runModal() == .OK, let url = panel.url { value.wrappedValue = url.path }
            } label: {
                Image(systemName: "folder")
            }
            .help(panelTitle)
        }
    }
}

private enum RemoteAccessScope: Hashable {
    case serverOnly
    case external
    case custom
}

private struct ModeSelector: View {
    @Binding var selection: TunnelMode
    let help: (TunnelMode) -> String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TunnelMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeOut(duration: 0.16)) { selection = mode }
                } label: {
                    Label(mode.displayName, systemImage: symbol(for: mode))
                        .font(.system(size: 12, weight: selection == mode ? .semibold : .medium))
                        .foregroundStyle(selection == mode ? AppTheme.ink : AppTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selection == mode ? AppTheme.panel : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(
                            color: selection == mode ? Color.black.opacity(0.07) : .clear,
                            radius: 5,
                            y: 2
                        )
                }
                .buttonStyle(.plain)
                .help(help(mode))
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func symbol(for mode: TunnelMode) -> String {
        switch mode {
        case .socks5: return "network"
        case .localForward: return "arrow.right"
        case .remoteForward: return "arrow.left"
        }
    }
}

private struct AccessScopeSelector: View {
    @Binding var selection: RemoteAccessScope

    var body: some View {
        HStack(spacing: 4) {
            option(.serverOnly, ui("ui.remote_access_server_only", "SSH server only"))
            option(.external, ui("ui.remote_access_external", "External devices"))
            option(.custom, ui("ui.remote_access_custom", "Custom address"))
        }
        .padding(4)
        .background(Color.black.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func option(_ scope: RemoteAccessScope, _ title: String) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) { selection = scope }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: selection == scope ? .semibold : .medium))
                .foregroundStyle(selection == scope ? AppTheme.ink : AppTheme.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selection == scope ? AppTheme.panel : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(
                    color: selection == scope ? Color.black.opacity(0.07) : .clear,
                    radius: 5,
                    y: 2
                )
        }
        .buttonStyle(.plain)
    }
}

private struct AuthenticationSelector: View {
    @Binding var selection: AuthenticationMethod

    var body: some View {
        Menu {
            ForEach(AuthenticationMethod.allCases, id: \.self) { method in
                Button {
                    selection = method
                } label: {
                    if selection == method {
                        Label(method.displayName, systemImage: "checkmark")
                    } else {
                        Text(method.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: authenticationSymbol)
                    .foregroundStyle(AppTheme.accent)
                Text(selection.displayName)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
            }
            .padding(.horizontal, 11)
            .frame(height: 36)
            .background(Color.black.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var authenticationSymbol: String {
        switch selection {
        case .sshConfig: return "terminal"
        case .keyFile: return "key"
        case .password: return "lock"
        }
    }
}

private struct RouteOverview: View {
    let profile: TunnelProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(ui("ui.route", "Connection path"))
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(profile.mode.displayName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }

            HStack(spacing: 10) {
                RouteNode(symbol: sourceSymbol, title: sourceTitle, detail: sourceDetail)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.white.opacity(0.28))
                RouteNode(
                    symbol: "lock.shield",
                    title: ui("ui.ssh_tunnel", "SSH tunnel"),
                    detail: profile.sshHost.isEmpty ? ui("ui.ssh_server", "SSH server") : profile.sshHost
                )
                Image(systemName: "arrow.right")
                    .foregroundStyle(.white.opacity(0.28))
                RouteNode(symbol: targetSymbol, title: targetTitle, detail: targetDetail)
            }
        }
        .padding(16)
        .background(Color(red: 0.095, green: 0.105, blue: 0.125))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var sourceSymbol: String {
        switch profile.mode {
        case .socks5: return "laptopcomputer"
        case .localForward: return "laptopcomputer"
        case .remoteForward: return "server.rack"
        }
    }

    private var sourceTitle: String {
        switch profile.mode {
        case .socks5: return ui("ui.local_apps", "Local apps")
        case .localForward: return ui("ui.this_mac", "This Mac")
        case .remoteForward: return ui("ui.ssh_server_listener", "SSH server listener")
        }
    }

    private var sourceDetail: String {
        switch profile.mode {
        case .socks5:
            return profile.httpProxyPort == nil ? "SOCKS :\(profile.localPort)" : "SOCKS :\(profile.localPort) · HTTP :\(profile.httpProxyPort!)"
        case .localForward:
            return "\(profile.localHost):\(profile.localPort)"
        case .remoteForward:
            return "\(profile.remoteHost):\(profile.remotePort)"
        }
    }

    private var targetSymbol: String {
        profile.mode == .socks5 ? "globe" : "shippingbox"
    }

    private var targetTitle: String {
        switch profile.mode {
        case .socks5: return ui("ui.target_network", "Target network")
        case .localForward: return ui("ui.remote_service", "Remote-side service")
        case .remoteForward: return ui("ui.local_service", "Service on this Mac")
        }
    }

    private var targetDetail: String {
        switch profile.mode {
        case .socks5: return ui("ui.via_ssh_exit", "Through the SSH exit")
        case .localForward: return "\(profile.remoteHost):\(profile.remotePort)"
        case .remoteForward: return "\(profile.localHost):\(profile.localPort)"
        }
    }
}

private struct RouteNode: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .foregroundStyle(Color(red: 0.34, green: 0.82, blue: 0.78))
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let symbol: String
    let helpTitle: String?
    let helpMessage: String?
    @ViewBuilder let content: Content

    init(
        title: String,
        symbol: String,
        helpTitle: String? = nil,
        helpMessage: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.symbol = symbol
        self.helpTitle = helpTitle
        self.helpMessage = helpMessage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                if let helpTitle, let helpMessage {
                    ContextHelpButton(title: helpTitle, message: helpMessage)
                }
            }
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
            content
        }
        .padding(18)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 12, y: 4)
    }
}

private struct DisclosureSection<Content: View>: View {
    let title: String
    let symbol: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: Content

    init(
        title: String,
        symbol: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.symbol = symbol
        _isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 14 : 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: symbol).foregroundStyle(AppTheme.accent).frame(width: 18)
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                content
            }
        }
        .padding(18)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 12, y: 4)
    }
}

private struct SettingRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct SettingsGrid<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 18, alignment: .top),
                GridItem(.flexible(), spacing: 18, alignment: .top)
            ],
            alignment: .leading,
            spacing: 14
        ) {
            content
        }
    }
}

private struct HostPortFields: View {
    @Binding var host: String
    @Binding var port: Int

    var body: some View {
        HStack(spacing: 8) {
            TextField(ui("ui.host", "Host"), text: $host)
            TextField(ui("ui.port", "Port"), value: $port, format: .number)
                .frame(width: 110)
        }
    }
}

private struct RemoteListenerStatusView: View {
    let profile: TunnelProfile
    let inspection: RemoteForwardInspection
    let connected: Bool
    let onCheck: () -> Void
    let onConfigure: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.callout.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if connected && inspection != .checking && inspection != .configuring {
                Button(action: onCheck) {
                    Image(systemName: "arrow.clockwise")
                }
                .help(ui("remote_check.check_again", "Check again"))
            }

            if connected && requestedExternal && inspection == .serverOnly {
                Button(action: onConfigure) {
                    Label(ui("remote_check.configure_action", "Configure Server"), systemImage: "wrench.and.screwdriver")
                }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var requestedExternal: Bool {
        ["0.0.0.0", "::"].contains(profile.remoteHost)
    }

    private var symbol: String {
        switch inspection {
        case .notChecked: return "dot.radiowaves.left.and.right"
        case .checking, .configuring: return "arrow.triangle.2.circlepath"
        case .serverOnly: return requestedExternal ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
        case .external: return "checkmark.circle.fill"
        case .missing: return "xmark.circle.fill"
        case .unsupported: return "questionmark.circle.fill"
        }
    }

    private var color: Color {
        switch inspection {
        case .notChecked, .checking, .configuring, .unsupported: return .secondary
        case .serverOnly: return requestedExternal ? .orange : .green
        case .external: return .green
        case .missing: return .red
        }
    }

    private var title: String {
        guard connected else { return ui("remote_check.disconnected", "Connect to verify the remote listener") }
        switch inspection {
        case .notChecked: return ui("remote_check.not_checked", "Remote listener not checked")
        case .checking: return ui("remote_check.checking", "Checking the actual remote listener…")
        case .configuring: return ui("remote_check.configuring", "Configuring and refreshing the remote forward…")
        case .serverOnly:
            return requestedExternal
                ? ui("remote_check.gatewayports_blocked", "Server policy limited this port to loopback")
                : ui("remote_check.server_only_confirmed", "Server-only listener confirmed")
        case .external: return ui("remote_check.external_confirmed", "External listener confirmed")
        case .missing: return ui("remote_check.listener_missing", "Remote listener was not found")
        case .unsupported: return ui("remote_check.unavailable", "Remote listener check unavailable")
        }
    }

    private var detail: String {
        guard connected else {
            return ui("remote_check.disconnected_detail", "The app checks the real bind address after the SSH connection is established.")
        }
        switch inspection {
        case .notChecked:
            return ui("remote_check.not_checked_detail", "Run a check to compare the requested and actual bind addresses.")
        case .checking:
            return ui("remote_check.checking_detail", "Using the active authenticated SSH connection; no second login is required.")
        case .configuring:
            return ui("remote_check.configuring_detail", "The existing SSH session remains active while the server policy is validated and reloaded.")
        case .serverOnly:
            return requestedExternal
                ? ui("remote_check.gatewayports_blocked_detail", "The rule requested 0.0.0.0, but sshd only opened 127.0.0.1. Enable GatewayPorts clientspecified to allow external access.")
                : ui("remote_check.server_only_detail", "Only programs running on the SSH server can access this forwarded port.")
        case .external:
            return ui("remote_check.external_detail", "sshd is listening beyond loopback. Cloud and system firewalls may still restrict who can connect.")
        case .missing:
            return ui("remote_check.listener_missing_detail", "The SSH process is connected, but the requested port is not listening on the server.")
        case .unsupported(let message):
            return message.isEmpty
                ? ui("remote_check.unavailable_detail", "The server does not provide a supported listener inspection command.")
                : message
        }
    }
}

private struct ContextHelpButton: View {
    let title: String
    let message: String
    @State private var isPresented = false

    var body: some View {
        Button { isPresented.toggle() } label: {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .popover(isPresented: $isPresented, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(width: 360, alignment: .leading)
        }
    }
}

private struct MessageBanner: View {
    let symbol: String
    let color: Color
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.callout)
            .foregroundStyle(color)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct EmptyRulesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.secondary)
            VStack(spacing: 5) {
                Text(ui("ui.no_rules", "No Rules")).font(.title3.weight(.semibold))
                Text(ui("ui.no_rules_detail", "Add a proxy or forwarding rule to get started."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Button {
                    model.addProfile()
                } label: {
                    Label(ui("ui.add_rule_title", "Add Rule"), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    model.importSSHConfigProfiles()
                } label: {
                    Label(ui("ui.import_ssh_config", "Import SSH Config"), systemImage: "square.and.arrow.down")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct SoftTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppTheme.ink)
            .padding(.horizontal, 11)
            .frame(height: 36)
            .background(Color.black.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            }
    }
}

private struct ActionButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(tint.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(Capsule())
            .shadow(color: tint.opacity(0.22), radius: 7, y: 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private extension View {
    func configurationLocked(_ locked: Bool) -> some View {
        allowsHitTesting(!locked)
            .opacity(locked ? 0.94 : 1)
    }
}
