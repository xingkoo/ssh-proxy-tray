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
            VStack(spacing: 0) {
                List(selection: $model.selectedProfileID) {
                    ForEach(model.profiles) { profile in
                        RuleRow(
                            profile: profile,
                            status: model.status(for: profile.id)
                        )
                        .tag(Optional(profile.id))
                    }
                }

                Divider()

                HStack(spacing: 10) {
                    Button {
                        model.addProfile()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help(ui("ui.add_rule", "Add rule"))

                    Button {
                        model.duplicateSelectedProfile()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .disabled(model.selectedProfileID == nil)
                    .help(ui("ui.duplicate_rule", "Duplicate rule"))

                    Button {
                        model.importSSHConfigProfiles()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .help(ui("ui.import_ssh_config_help", "Import hosts from ~/.ssh/config"))

                    Button(role: .destructive) {
                        model.removeSelectedProfile()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(model.selectedProfileID == nil)
                    .help(ui("ui.delete_rule", "Delete rule"))

                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 12)
                .frame(height: 38)

                Divider()

                HStack {
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
                    }
                    .buttonStyle(.borderless)
                    .help(ui("ui.quit", "Quit"))
                }
                .padding(.horizontal, 12)
                .frame(height: 42)
            }
            .navigationSplitViewColumnWidth(min: 230, ideal: 260, max: 320)
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
        .frame(minWidth: 820, minHeight: 580)
    }
}

private struct RuleRow: View {
    let profile: TunnelProfile
    let status: TunnelStatus

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: modeSymbol)
                .foregroundStyle(profile.enabled ? .primary : .secondary)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name.isEmpty ? ui("ui.unnamed_rule", "Unnamed Rule") : profile.name)
                    .lineLimit(1)
                endpointRows
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 3) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusTitle)
                    .font(.caption2)
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private var endpointRows: some View {
        if profile.mode == .socks5 {
            endpointText("SOCKS  \(profile.localHost):\(profile.localPort)")
            if let httpProxyPort = profile.httpProxyPort {
                endpointText("HTTP   \(profile.localHost):\(httpProxyPort)")
            }
        } else {
            endpointText("\(profile.mode.displayName)  \(profile.endpointSummary)")
        }
    }

    private func endpointText(_ value: String) -> some View {
        Text(value)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
    }

    private var modeSymbol: String {
        switch profile.mode {
        case .socks5: return "network"
        case .localForward: return "arrow.right"
        case .remoteForward: return "arrow.left"
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

    private var status: TunnelStatus { model.status(for: profile.id) }
    private var running: Bool { model.isRunning(profileID: profile.id) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: profile.enabled ? status.symbolName : "pause.circle")
                    .foregroundStyle(statusColor)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name.isEmpty ? ui("ui.unnamed_rule", "Unnamed Rule") : profile.name)
                        .font(.headline)
                    Text(profile.enabled ? status.title : ui("status.disabled", "Disabled"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle(ui("ui.enabled", "Enabled"), isOn: enabledBinding)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                ContextHelpButton(
                    title: ui("help.rule_state.title", "Availability and connection state"),
                    message: ui(
                        "help.rule_state.body",
                        "Enabled means the rule is available to run; it does not mean the rule is connected. Use Connect and Disconnect to control the current SSH session. Disabling a running rule disconnects it."
                    )
                )

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
            .padding(.horizontal, 18)
            .frame(height: 62)

            Divider()

            Form {
                Section {
                    Group {
                        TextField(ui("ui.name", "Name"), text: $profile.name)

                        Picker(ui("ui.type", "Type"), selection: $profile.mode) {
                            ForEach(TunnelMode.allCases, id: \.self) { mode in
                                Text(mode.displayName)
                                    .tag(mode)
                                    .help(modeHelp(mode))
                            }
                        }
                        .pickerStyle(.segmented)

                        Toggle(
                            ui("ui.connect_on_start", "Connect when the app starts"),
                            isOn: $profile.autoConnect
                        )
                        .help(ui(
                            "help.auto_connect",
                            "Connects this rule when SSH Proxy Tray starts. Launch at login is a separate app-wide setting."
                        ))
                    }
                    .disabled(running)
                } header: {
                    HelpSectionHeader(
                        title: ui("ui.section.rule", "Rule"),
                        helpTitle: ui("help.rule_type.title", "Choose the direction that matches your task"),
                        helpMessage: ui(
                            "help.rule_type.body",
                            "Proxy provides a SOCKS5 endpoint and can also provide an HTTP/HTTPS endpoint through the same SSH tunnel. Local Forward opens a port on this Mac for a service reachable from the SSH server. Remote Forward opens a port on the SSH server for a service running on this Mac."
                        )
                    )
                }

                Section {
                    Group { forwardingFields }
                        .disabled(running)
                } header: {
                    HelpSectionHeader(
                        title: ui("ui.section.forwarding", "Forwarding"),
                        helpTitle: forwardingHelpTitle,
                        helpMessage: forwardingHelpMessage
                    )
                }

                Section {
                    Group {
                        Picker(ui("ui.authentication", "Authentication"), selection: $profile.authentication) {
                            ForEach(AuthenticationMethod.allCases, id: \.self) { method in
                                Text(method.displayName).tag(method)
                            }
                        }

                        TextField(
                            profile.authentication == .sshConfig
                                ? ui("ui.host_alias", "Host alias")
                                : ui("ui.host", "Host"),
                            text: $profile.sshHost
                        )

                        if profile.authentication != .sshConfig {
                            TextField(ui("ui.ssh_port", "SSH port"), value: $profile.sshPort, format: .number)
                            TextField(ui("ui.username", "Username"), text: $profile.username)
                        }

                        if profile.authentication == .keyFile {
                            fileField(
                                title: ui("ui.private_key", "Private key"),
                                value: $profile.identityFile,
                                panelTitle: ui("ui.choose_private_key", "Choose SSH Private Key")
                            )
                            fileField(
                                title: ui("ui.ssh_certificate", "SSH certificate"),
                                value: optionalStringBinding(\.certificateFile),
                                panelTitle: ui("ui.choose_ssh_certificate", "Choose SSH Certificate")
                            )
                        }

                        if profile.authentication == .password {
                            SecureField(ui("ui.password", "Password"), text: $password)
                            Toggle(
                                ui("ui.save_password_keychain", "Save password in Keychain"),
                                isOn: $profile.savePassword
                            )
                        }
                    }
                    .disabled(running)
                } header: {
                    HelpSectionHeader(
                        title: ui("ui.section.ssh_connection", "SSH Connection"),
                        helpTitle: ui("help.authentication.title", "Choose how OpenSSH authenticates"),
                        helpMessage: ui(
                            "help.authentication.body",
                            "SSH Config is best when the host, user, key, jump host, or port already exists in ~/.ssh/config. Key / Certificate uses explicit connection fields. Password prompts at connection time and is saved only when Keychain storage is enabled."
                        )
                    )
                }

                Section {
                    Group {
                        TextField("ProxyJump", text: optionalStringBinding(\.proxyJump))
                            .help(ui("help.proxy_jump", "Connect through an intermediate SSH host, equivalent to ssh -J."))
                        Toggle(
                            ui("ui.compression", "Compression"),
                            isOn: optionalBoolBinding(\.compression, default: false)
                        )
                        .help(ui("help.compression", "Enables SSH compression. It can help on slow links but may add CPU overhead."))
                        TextField(
                            ui("ui.connect_timeout", "Connect timeout (seconds)"),
                            value: optionalIntBinding(\.connectTimeout, default: 10),
                            format: .number
                        )
                        .help(ui("help.connect_timeout", "Maximum time to wait while establishing the SSH connection."))
                        TextField(
                            ui("ui.server_alive_interval", "Server alive interval (seconds)"),
                            value: optionalIntBinding(\.serverAliveInterval, default: 30),
                            format: .number
                        )
                        .help(ui("help.server_alive_interval", "How often SSH sends an encrypted keepalive message. Use 0 to disable."))
                        TextField(
                            ui("ui.server_alive_count", "Server alive count"),
                            value: optionalIntBinding(\.serverAliveCountMax, default: 3),
                            format: .number
                        )
                        .help(ui("help.server_alive_count", "Disconnect after this many unanswered keepalive messages."))
                    }
                    .disabled(running)
                } header: {
                    HelpSectionHeader(
                        title: ui("ui.section.advanced_ssh", "Advanced SSH"),
                        helpTitle: ui("help.advanced.title", "Optional OpenSSH connection controls"),
                        helpMessage: ui(
                            "help.advanced.body",
                            "ProxyJump routes through a bastion host. Compression trades CPU for less network traffic. Timeout and keepalive settings control how quickly failed or stalled connections are detected. Leave the defaults unless your SSH environment requires different values."
                        )
                    )
                }

                if let errorMessage = model.errorMessage,
                   errorMessage.hasPrefix(profile.name + ":") {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                let logs = model.logs(for: profile.id)
                if !logs.isEmpty {
                    Section(ui("ui.section.connection_log", "Connection Log")) {
                        Text(logs.suffix(8).joined(separator: "\n"))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    @ViewBuilder
    private var forwardingFields: some View {
        switch profile.mode {
        case .socks5:
            TextField(ui("ui.local_bind_address", "Local bind address"), text: $profile.localHost)
                .help(ui("help.local_bind_address", "The local interface that accepts connections. Loopback keeps the listener available only on this Mac."))
            TextField(
                ui("ui.socks_proxy_port", "SOCKS proxy port"),
                value: $profile.localPort,
                format: .number
            )
            .help(ui("help.local_proxy_port", "Configure your browser or application to use this local SOCKS5 port."))
            Toggle(
                ui("ui.provide_http_proxy", "Also provide HTTP/HTTPS proxy"),
                isOn: httpProxyEnabledBinding
            )
            .help(ui(
                "help.provide_http_proxy",
                "Adds a local HTTP proxy endpoint that uses the same SSH tunnel. HTTPS is supported through the HTTP CONNECT method."
            ))
            if profile.httpProxyPort != nil {
                TextField(
                    ui("ui.http_proxy_port", "HTTP proxy port"),
                    value: optionalIntBinding(\.httpProxyPort, default: suggestedHTTPProxyPort),
                    format: .number
                )
                .help(ui(
                    "help.http_proxy_port",
                    "Use this port in applications that accept an HTTP proxy. Both HTTP requests and HTTPS CONNECT use the same SSH tunnel as SOCKS."
                ))
            }
        case .localForward:
            TextField(ui("ui.local_bind_address", "Local bind address"), text: $profile.localHost)
                .help(ui("help.local_bind_address", "The local interface that accepts connections. Loopback keeps the listener available only on this Mac."))
            TextField(
                ui("ui.local_listen_port", "Local listen port"),
                value: $profile.localPort,
                format: .number
            )
            .help(ui("help.local_listen_port", "Connect to this port on your Mac to reach the remote destination through SSH."))
            TextField(
                ui("ui.remote_destination_host", "Remote destination host"),
                text: $profile.remoteHost
            )
            .help(ui("help.remote_destination_host", "A host that the SSH server can reach. 127.0.0.1 means the SSH server itself."))
            TextField(
                ui("ui.remote_destination_port", "Remote destination port"),
                value: $profile.remotePort,
                format: .number
            )
            .help(ui("help.remote_destination_port", "The service port reached from the SSH server side."))
        case .remoteForward:
            TextField(ui("ui.remote_bind_address", "Remote bind address"), text: $profile.remoteHost)
                .help(ui("help.remote_bind_address", "127.0.0.1 allows access only from the SSH server. 0.0.0.0 may expose the port to other machines and requires GatewayPorts."))
            TextField(
                ui("ui.remote_listen_port", "Remote listen port"),
                value: $profile.remotePort,
                format: .number
            )
            .help(ui("help.remote_listen_port", "Connect to this port on the SSH server to reach the local target."))
            TextField(ui("ui.local_target_host", "Local target host"), text: $profile.localHost)
                .help(ui("help.local_target_host", "The service host as seen from this Mac. Usually 127.0.0.1."))
            TextField(
                ui("ui.local_target_port", "Local target port"),
                value: $profile.localPort,
                format: .number
            )
            .help(ui("help.local_target_port", "The port where the target service is already running on this Mac."))
        }
    }

    private func modeHelp(_ mode: TunnelMode) -> String {
        switch mode {
        case .socks5:
            return ui("help.mode.proxy", "Local app -> SOCKS or HTTP proxy port -> one SSH tunnel -> network. Use either endpoint without opening a second SSH connection.")
        case .localForward:
            return ui("help.mode.local_forward", "This Mac local port -> SSH tunnel -> service reachable from the SSH server.")
        case .remoteForward:
            return ui("help.mode.remote_forward", "SSH server remote port -> SSH tunnel -> service running on this Mac.")
        }
    }

    private var forwardingHelpTitle: String {
        switch profile.mode {
        case .socks5:
            return ui("help.forwarding.proxy.title", "Proxy: SOCKS and HTTP endpoints share one SSH tunnel")
        case .localForward:
            return ui("help.forwarding.local.title", "Local Forward: access a remote-side service from this Mac")
        case .remoteForward:
            return ui("help.forwarding.remote.title", "Remote Forward: access a service on this Mac from the SSH server")
        }
    }

    private var forwardingHelpMessage: String {
        switch profile.mode {
        case .socks5:
            return ui(
                "help.forwarding.proxy.body",
                "SOCKS flow: app -> local SOCKS5 port -> encrypted SSH tunnel -> destination. HTTP flow: app -> local HTTP proxy port -> local protocol adapter -> the same SOCKS5 tunnel. HTTPS uses HTTP CONNECT. Two local ports are required because SOCKS and HTTP are different protocols, but only one SSH connection is opened."
            )
        case .localForward:
            return ui(
                "help.forwarding.local.body",
                "Flow: this Mac's local listen port -> encrypted SSH connection -> destination host and port reachable from the SSH server. Example: local 8080 can reach a proxy or database on the remote side."
            )
        case .remoteForward:
            return ui(
                "help.forwarding.remote.body",
                "Flow: remote listen port on the SSH server -> encrypted SSH connection -> target service on this Mac. Example: remote 23000 can reach a local development server on port 3000. Keep the remote bind address at 127.0.0.1 unless broader exposure is intentional and secured."
            )
        }
    }

    @ViewBuilder
    private var endpointCopyControl: some View {
        if profile.mode == .socks5, let httpProxyURL = profile.httpProxyURL {
            Menu {
                Button {
                    model.copyEndpoint(profile.socksProxyURL)
                } label: {
                    Label(
                        ui("ui.copy_socks_endpoint", "Copy SOCKS endpoint"),
                        systemImage: "network"
                    )
                }
                Button {
                    model.copyEndpoint(httpProxyURL)
                } label: {
                    Label(
                        ui("ui.copy_http_endpoint", "Copy HTTP endpoint"),
                        systemImage: "globe"
                    )
                }
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(ui("ui.copy_proxy_endpoint", "Copy SOCKS or HTTP endpoint"))
        } else {
            Button {
                model.copySelectedEndpoint()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .help(ui("ui.copy_endpoint", "Copy endpoint"))
        }
    }

    private var httpProxyEnabledBinding: Binding<Bool> {
        Binding(
            get: { profile.httpProxyPort != nil },
            set: { enabled in
                profile.httpProxyPort = enabled
                    ? (profile.httpProxyPort ?? suggestedHTTPProxyPort)
                    : nil
            }
        )
    }

    private var suggestedHTTPProxyPort: Int {
        profile.localPort < 65535 ? profile.localPort + 1 : 18081
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { profile.enabled },
            set: { profile.isEnabled = $0 }
        )
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

    private func optionalStringBinding(
        _ keyPath: WritableKeyPath<TunnelProfile, String?>
    ) -> Binding<String> {
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

    private func fileField(
        title: String,
        value: Binding<String>,
        panelTitle: String
    ) -> some View {
        HStack {
            TextField(title, text: value)
            Button {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.allowsMultipleSelection = false
                panel.title = panelTitle
                if panel.runModal() == .OK, let url = panel.url {
                    value.wrappedValue = url.path
                }
            } label: {
                Image(systemName: "folder")
            }
            .help(panelTitle)
        }
    }
}

private struct HelpSectionHeader: View {
    let title: String
    let helpTitle: String
    let helpMessage: String

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            ContextHelpButton(title: helpTitle, message: helpMessage)
        }
    }
}

private struct ContextHelpButton: View {
    let title: String
    let message: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .popover(isPresented: $isPresented, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(width: 360, alignment: .leading)
        }
    }
}

private struct EmptyRulesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(ui("ui.no_rules", "No Rules"))
                .font(.headline)

            HStack {
                Button {
                    model.addProfile()
                } label: {
                    Label(ui("ui.add_rule_title", "Add Rule"), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    model.importSSHConfigProfiles()
                } label: {
                    Label(
                        ui("ui.import_ssh_config", "Import SSH Config"),
                        systemImage: "square.and.arrow.down"
                    )
                }
            }

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
