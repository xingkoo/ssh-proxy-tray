import SwiftUI

@main
struct SSHProxyTrayApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            TrayMenuView()
                .environmentObject(model)
        } label: {
            Image(systemName: model.status == .connected ? "network.badge.shield.half.filled" : "network")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}
