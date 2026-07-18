import AppKit
import Combine
import SSHProxyCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem?
    private var windowController: NSWindowController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        createMainWindow()
        createStatusItem()

        model.$statuses
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &cancellables)

        if CommandLine.arguments.contains("--show-window") {
            openMainWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        openMainWindow()
        return true
    }

    private func createMainWindow() {
        let content = MainWindowView().environmentObject(model)
        let hostingController = NSHostingController(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1160, height: 780),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "SSH Proxy Tray"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = NSColor(calibratedWhite: 0.95, alpha: 1)
        window.contentViewController = hostingController
        window.contentMinSize = NSSize(width: 1040, height: 720)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setFrameAutosaveName("SSHProxyTrayMainWindow")
        window.center()
        windowController = NSWindowController(window: window)
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.target = self
        item.button?.action = #selector(openMainWindow)
        item.button?.toolTip = SSHProxyL10n.string(
            "status_item.open",
            default: "Open SSH Proxy Tray"
        )
        statusItem = item
        updateStatusItem()
    }

    private func updateStatusItem() {
        let symbolName: String
        switch model.summaryStatus {
        case .disconnected: symbolName = "network"
        case .connecting: symbolName = "arrow.triangle.2.circlepath"
        case .connected: symbolName = "network.badge.shield.half.filled"
        case .disconnecting: symbolName = "stop.circle"
        case .failed: symbolName = "exclamationmark.triangle"
        }
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "SSH Proxy Tray")
        image?.isTemplate = true
        statusItem?.button?.image = image
        statusItem?.button?.toolTip = model.connectedCount > 0
            ? SSHProxyL10n.format(
                "status_item.connected_count",
                default: "Open SSH Proxy Tray - %d connected",
                model.connectedCount
            )
            : SSHProxyL10n.string("status_item.open", default: "Open SSH Proxy Tray")
    }

    @objc private func openMainWindow() {
        guard let window = windowController?.window else { return }
        windowController?.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
