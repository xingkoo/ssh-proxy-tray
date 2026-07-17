import AppKit
import SSHProxyCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $model.selectedProfileID) {
                    ForEach(model.profiles) { profile in
                        Label(profile.name, systemImage: profile.mode == .socks5 ? "network" : "arrow.left.arrow.right")
                            .tag(Optional(profile.id))
                    }
                }

                Divider()

                HStack(spacing: 4) {
                    Button {
                        model.addProfile()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Add tunnel")

                    Button(role: .destructive) {
                        model.removeSelectedProfile()
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(model.selectedProfileID == nil)
                    .help("Delete tunnel")

                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 10)
                .frame(height: 34)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 250)
        } detail: {
            if let id = model.selectedProfileID,
               let index = model.profiles.firstIndex(where: { $0.id == id }) {
                ProfileEditor(profile: $model.profiles[index], password: $model.enteredPassword)
                    .environmentObject(model)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "network")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)
                    Text("No Tunnel Selected")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 760, minHeight: 540)
    }
}

private struct ProfileEditor: View {
    @EnvironmentObject private var model: AppModel
    @Binding var profile: TunnelProfile
    @Binding var password: String

    var body: some View {
        Form {
            Section("Tunnel") {
                TextField("Name", text: $profile.name)

                Picker("Mode", selection: $profile.mode) {
                    ForEach(TunnelMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Local port", value: $profile.localPort, format: .number)

                if profile.mode == .remoteProxy {
                    TextField("Remote proxy host", text: $profile.remoteHost)
                    TextField("Remote proxy port", value: $profile.remotePort, format: .number)
                }
            }

            Section("SSH") {
                Picker("Authentication", selection: $profile.authentication) {
                    ForEach(AuthenticationMethod.allCases, id: \.self) { method in
                        Text(method.displayName).tag(method)
                    }
                }

                TextField(
                    profile.authentication == .sshConfig ? "Host or alias" : "Host",
                    text: $profile.sshHost
                )

                if profile.authentication != .sshConfig {
                    TextField("Port", value: $profile.sshPort, format: .number)
                    TextField("Username", text: $profile.username)
                }

                if profile.authentication == .keyFile {
                    HStack {
                        TextField("Private key", text: $profile.identityFile)
                        Button {
                            chooseIdentityFile()
                        } label: {
                            Image(systemName: "folder")
                        }
                        .help("Choose private key")
                    }
                }

                if profile.authentication == .password {
                    SecureField("Password", text: $password)
                    Toggle("Save password in Keychain", isOn: $profile.savePassword)
                }
            }

            Section("Startup") {
                Toggle("Connect this tunnel when the app starts", isOn: $profile.autoConnect)
                Toggle(
                    "Open SSH Proxy Tray at login",
                    isOn: Binding(
                        get: { model.launchAtLoginEnabled },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
            }

            if let errorMessage = model.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(profile.name.isEmpty ? "Tunnel" : profile.name)
        .padding(.top, 6)
    }

    private func chooseIdentityFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.title = "Choose SSH Private Key"
        if panel.runModal() == .OK, let url = panel.url {
            profile.identityFile = url.path
        }
    }
}
