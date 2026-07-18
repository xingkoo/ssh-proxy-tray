import AppKit
import SSHProxyCore
import SwiftUI

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
                    .help("Add rule")

                    Button {
                        model.duplicateSelectedProfile()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .disabled(model.selectedProfileID == nil)
                    .help("Duplicate rule")

                    Button {
                        model.importSSHConfigProfiles()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .help("Import hosts from ~/.ssh/config")

                    Button(role: .destructive) {
                        model.removeSelectedProfile()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(model.selectedProfileID == nil)
                    .help("Delete rule")

                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 12)
                .frame(height: 38)

                Divider()

                HStack {
                    Toggle(
                        "Launch at login",
                        isOn: Binding(
                            get: { model.launchAtLoginEnabled },
                            set: { model.setLaunchAtLogin($0) }
                        )
                    )
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    Spacer()

                    Button {
                        NSApp.terminate(nil)
                    } label: {
                        Image(systemName: "power")
                    }
                    .buttonStyle(.borderless)
                    .help("Quit")
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
                Text(profile.name.isEmpty ? "Unnamed Rule" : profile.name)
                    .lineLimit(1)
                Text("\(profile.mode.displayName)  \(profile.endpointSummary)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
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

    private var modeSymbol: String {
        switch profile.mode {
        case .socks5: return "network"
        case .localForward: return "arrow.right"
        case .remoteForward: return "arrow.left"
        }
    }

    private var statusTitle: String {
        profile.enabled ? status.title : "Disabled"
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
                    Text(profile.name.isEmpty ? "Unnamed Rule" : profile.name)
                        .font(.headline)
                    Text(profile.enabled ? status.title : "Disabled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("Enabled", isOn: enabledBinding)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Button {
                    model.copySelectedEndpoint()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help("Copy endpoint")

                if running {
                    Button(role: .destructive) {
                        model.disconnect(profileID: profile.id)
                    } label: {
                        Label("Disconnect", systemImage: "stop.fill")
                    }
                    .disabled(status == .disconnecting)
                } else {
                    Button {
                        model.connect(profile)
                    } label: {
                        Label("Connect", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!profile.enabled)
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 62)

            Divider()

            Form {
                Section("Rule") {
                    TextField("Name", text: $profile.name)

                    Picker("Type", selection: $profile.mode) {
                        ForEach(TunnelMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Connect when the app starts", isOn: $profile.autoConnect)
                }

                Section("Forwarding") {
                    forwardingFields
                }

                Section("SSH Connection") {
                    Picker("Authentication", selection: $profile.authentication) {
                        ForEach(AuthenticationMethod.allCases, id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }

                    TextField(
                        profile.authentication == .sshConfig ? "Host alias" : "Host",
                        text: $profile.sshHost
                    )

                    if profile.authentication != .sshConfig {
                        TextField("SSH port", value: $profile.sshPort, format: .number)
                        TextField("Username", text: $profile.username)
                    }

                    if profile.authentication == .keyFile {
                        fileField(
                            title: "Private key",
                            value: $profile.identityFile,
                            panelTitle: "Choose SSH Private Key"
                        )
                        fileField(
                            title: "SSH certificate",
                            value: optionalStringBinding(\.certificateFile),
                            panelTitle: "Choose SSH Certificate"
                        )
                    }

                    if profile.authentication == .password {
                        SecureField("Password", text: $password)
                        Toggle("Save password in Keychain", isOn: $profile.savePassword)
                    }
                }

                Section("Advanced SSH") {
                    TextField("ProxyJump", text: optionalStringBinding(\.proxyJump))
                    Toggle("Compression", isOn: optionalBoolBinding(\.compression, default: false))
                    TextField(
                        "Connect timeout (seconds)",
                        value: optionalIntBinding(\.connectTimeout, default: 10),
                        format: .number
                    )
                    TextField(
                        "Server alive interval (seconds)",
                        value: optionalIntBinding(\.serverAliveInterval, default: 30),
                        format: .number
                    )
                    TextField(
                        "Server alive count",
                        value: optionalIntBinding(\.serverAliveCountMax, default: 3),
                        format: .number
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
                    Section("Connection Log") {
                        Text(logs.suffix(8).joined(separator: "\n"))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .formStyle(.grouped)
            .disabled(running)
        }
    }

    @ViewBuilder
    private var forwardingFields: some View {
        switch profile.mode {
        case .socks5:
            TextField("Local bind address", text: $profile.localHost)
            TextField("Local proxy port", value: $profile.localPort, format: .number)
        case .localForward:
            TextField("Local bind address", text: $profile.localHost)
            TextField("Local listen port", value: $profile.localPort, format: .number)
            TextField("Remote destination host", text: $profile.remoteHost)
            TextField("Remote destination port", value: $profile.remotePort, format: .number)
        case .remoteForward:
            TextField("Remote bind address", text: $profile.remoteHost)
            TextField("Remote listen port", value: $profile.remotePort, format: .number)
            TextField("Local target host", text: $profile.localHost)
            TextField("Local target port", value: $profile.localPort, format: .number)
        }
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

private struct EmptyRulesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("No Rules")
                .font(.headline)

            HStack {
                Button {
                    model.addProfile()
                } label: {
                    Label("Add Rule", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    model.importSSHConfigProfiles()
                } label: {
                    Label("Import SSH Config", systemImage: "square.and.arrow.down")
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
