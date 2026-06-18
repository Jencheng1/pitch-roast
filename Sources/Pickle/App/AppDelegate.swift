import AppKit
import SwiftUI
import Combine

/// Wires up the companion + panel windows, places Pickle above the Dock, and
/// keeps the panel's visibility in sync with `AppState`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let appState = AppState()

    private var companionWindow: FloatingPanel!
    private var panelWindow: FloatingPanel!
    private var cancellables = Set<AnyCancellable>()

    private let companionSize = NSSize(width: 150, height: 168)
    private let panelSize = NSSize(width: 372, height: 540)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // companion: no Dock icon

        buildCompanion()
        buildPanel()
        positionCompanion()
        observeState()

        companionWindow.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screenChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    // MARK: Build windows

    private func buildCompanion() {
        companionWindow = FloatingPanel(size: companionSize, movableByBackground: true)
        let root = CompanionView()
            .environmentObject(appState)
        companionWindow.contentView = NSHostingView(rootView: root)
    }

    private func buildPanel() {
        panelWindow = FloatingPanel(size: panelSize, movableByBackground: false)
        let root = PanelView()
            .environmentObject(appState)
            .frame(width: panelSize.width, height: panelSize.height)
        panelWindow.contentView = NSHostingView(rootView: root)
    }

    // MARK: Placement

    private func positionCompanion() {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame          // excludes the Dock + menu bar
        let x = vf.midX - companionSize.width / 2
        let y = vf.minY + 12                  // hover just above the Dock
        companionWindow.setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Anchor the panel just above the companion, clamped to the screen.
    private func positionPanel() {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let cFrame = companionWindow.frame
        var x = cFrame.midX - panelSize.width / 2
        x = min(max(x, vf.minX + 8), vf.maxX - panelSize.width - 8)
        let y = cFrame.maxY + 10
        panelWindow.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc private func screenChanged() {
        positionCompanion()
        if appState.panelVisible { positionPanel() }
    }

    // MARK: State sync

    private func observeState() {
        appState.$panelVisible
            .removeDuplicates()
            .sink { [weak self] visible in
                guard let self else { return }
                if visible {
                    self.positionPanel()
                    self.panelWindow.alphaValue = 0
                    self.panelWindow.orderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)   // so text fields can focus
                    NSAnimationContext.runAnimationGroup { ctx in
                        ctx.duration = 0.18
                        self.panelWindow.animator().alphaValue = 1
                    }
                } else {
                    NSAnimationContext.runAnimationGroup({ ctx in
                        ctx.duration = 0.14
                        self.panelWindow.animator().alphaValue = 0
                    }, completionHandler: {
                        self.panelWindow.orderOut(nil)
                    })
                }
            }
            .store(in: &cancellables)
    }
}
