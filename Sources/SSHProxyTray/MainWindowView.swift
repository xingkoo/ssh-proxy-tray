import AppKit
import SSHProxyCore
import SwiftUI

private func ui(_ key: String, _ defaultValue: String) -> String {
    SSHProxyL10n.string(key, default: defaultValue)
}

struct MainWindowView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            RuleSidebar()
                .environmentObject(model)
                .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 330)
        } detail: {
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
        .frame(minWidth: 980, minHeight: 680)
    }
}

private struct RuleSidebar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text("SSH Proxy Tray")
                        .font(.headline)
                    Text(sidebarSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    model.addProfile()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .help(ui("ui.add_rule", "Add rule"))
            }
            .padding(.horizontal, 14)
            .frame(height: 58)

            Divider()

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

            Divider()

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
                sidebarButton(
                    symbol: "trash",
                    help: ui("ui.delete_rule", "Delete rule"),
                    disabled: model.selectedProfileID == nil,
                    role: .destructive,
                    action: model.removeSelectedProfile
                )
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 42)

            Divider()

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
            .padding(.horizontal, 14)
            .frame(height: 46)
        }
        .background(.ultraThinMaterial)
    }

    private var sidebarSummary: String {
        SSHProxyL10n.format(
            "ui.sidebar_summary",
            default: "%d connected · %d rules",
            model.connectedCount,
            model.profiles.count
        )
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
        .buttonStyle(.borderless)
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
                .foregroundStyle(profile.enabled ? modeColor : .secondary)
                .frame(width: 28, height: 28)
                .background(modeColor.opacity(profile.enabled ? 0.12 : 0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(profile.name.isEmpty ? ui("ui.unnamed_rule", "Unnamed Rule") : profile.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(rowSummary)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 4)

            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .help(statusTitle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(alignment: .leading) {
            if isSelected {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor)
                    .frame(width: 3, height: 34)
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
        case .socks5: return .blue
        case .localForward: return .teal
        case .remoteForward: return .indigo
        }
    }

    private var statusTitle: String {
        profile.enabled ? status.title : ui("status.disabled", "Disabled")
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
            Divider()

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
                                Picker(ui("ui.type", "Type"), selection: $profile.mode) {
                                    ForEach(TunnelMode.allCases, id: \.self) { mode in
                                        Text(mode.displayName).tag(mode).help(modeHelp(mode))
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
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
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
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
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                    Text(profile.mode.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Circle().fill(statusColor).frame(width: 8, height: 8)
                    Text(profile.enabled ? status.title : ui("status.disabled", "Disabled"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if running {
                        Label(ui("ui.configuration_locked", "Configuration locked while connected"), systemImage: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Toggle(ui("ui.enabled", "Enabled"), isOn: enabledBinding)
                .toggleStyle(.switch)
                .controlSize(.small)

            endpointCopyControl

            if running {
                Button(role: .destructive) {
                    model.disconnect(profileID: profile.id)
                } label: {
                    Label(ui("ui.disconnect", "Disconnect"), systemImage: "stop.fill")
                }
                .disabled(status == .disconnecting)
            } else {
                Button {
                    model.connect(profile)
                } label: {
                    Label(ui("ui.connect", "Connect"), systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!profile.enabled)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 76)
        .background(Color(nsColor: .textBackgroundColor))
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
                Picker(ui("ui.remote_access_scope", "Who can access"), selection: remoteAccessBinding) {
                    Text(ui("ui.remote_access_server_only", "SSH server only")).tag(RemoteAccessScope.serverOnly)
                    Text(ui("ui.remote_access_external", "External devices")).tag(RemoteAccessScope.external)
                    Text(ui("ui.remote_access_custom", "Custom address")).tag(RemoteAccessScope.custom)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
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
            Picker(ui("ui.authentication", "Authentication"), selection: $profile.authentication) {
                ForEach(AuthenticationMethod.allCases, id: \.self) { method in
                    Text(method.displayName).tag(method)
                }
            }
            .labelsHidden()
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
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(title).font(.headline)
                if let helpTitle, let helpMessage {
                    ContextHelpButton(title: helpTitle, message: helpMessage)
                }
            }
            Divider()
            content
        }
        .padding(.vertical, 8)
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
                    Image(systemName: symbol).foregroundStyle(.secondary).frame(width: 18)
                    Text(title).font(.headline).foregroundStyle(.primary)
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
        .padding(.vertical, 8)
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
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
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

private extension View {
    func configurationLocked(_ locked: Bool) -> some View {
        disabled(locked)
            .opacity(locked ? 0.82 : 1)
    }
}
