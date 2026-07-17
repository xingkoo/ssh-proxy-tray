import AppKit
import SSHProxyCore
import SwiftUI

struct TrayMenuView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: model.status.symbolName)
                    .foregroundStyle(statusColor)
                    .frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text("SSH Proxy Tray")
                        .font(.headline)
                    Text(model.status.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if !model.profiles.isEmpty {
                Picker("Profile", selection: $model.selectedProfileID) {
                    ForEach(model.profiles) { profile in
                        Text(profile.name).tag(Optional(profile.id))
                    }
                }
                .disabled(model.activeProfileID != nil)

                if let profile = model.selectedProfile {
                    HStack {
                        Text(profile.proxyURL)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button {
                            model.copyProxyURL()
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy proxy URL")
                    }
                }

                if model.activeProfileID == nil {
                    Button {
                        model.connectSelected()
                    } label: {
                        Label("Connect", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.status == .connecting)
                } else {
                    Button(role: .destructive) {
                        model.disconnect()
                    } label: {
                        Label("Disconnect", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Button {
                    model.addProfile()
                    model.openSettings()
                } label: {
                    Label("Add Tunnel", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                Button {
                    model.openSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(.borderless)

                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.borderless)
                .help("Quit")
            }
        }
        .padding(14)
        .frame(width: 310)
    }

    private var statusColor: Color {
        switch model.status {
        case .disconnected: return .secondary
        case .connecting: return .orange
        case .connected: return .green
        case .failed: return .red
        }
    }
}
