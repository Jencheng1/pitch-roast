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
    private var grabOffsetX: CGFloat = 0      // cursor→window-origin offset at drag start

    private let companionSize = NSSize(width: 150, height: 150)
    private let panelSize = NSSize(width: 372, height: 540)

    /// Screen-Y of the panel's bottom, measured up from the companion window's
    /// bottom. Tuned so the panel's glass bottom lands ~4px *behind* the top of
    /// Pickle's head — Pickle renders above the panel, so the overlap reads as
    /// "he's holding up the popup" with no visible gap.
    private let panelOverlapY: CGFloat = 76

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // companion: no Dock icon

        buildCompanion()
        buildPanel()
        positionCompanion()
        observeState()
        wireCompanionDrag()

        companionWindow.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screenChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    // MARK: Build windows

    private func buildCompanion() {
        // We drive the drag ourselves (horizontal-only, clamped, with wobble),
        // so AppKit's background dragging is off.
        companionWindow = FloatingPanel(size: companionSize, movableByBackground: false)
        // Pickle sits one notch above the panel so, where they overlap, he
        // renders in front and the panel reads as connected behind him.
        companionWindow.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
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
        let y = vf.minY                        // window bottom on the Dock's top edge
        companionWindow.setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Anchor the panel just above the companion, clamped to the screen.
    private func positionPanel() {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame
        let cFrame = companionWindow.frame
        var x = cFrame.midX - panelSize.width / 2
        x = min(max(x, vf.minX + 8), vf.maxX - panelSize.width - 8)
        // Overlap Pickle's head: the panel's glass bottom tucks just behind him,
        // so the two read as one connected piece with no gap.
        let y = cFrame.minY + panelOverlapY
        panelWindow.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc private func screenChanged() {
        positionCompanion()
        if appState.panelVisible { positionPanel() }
    }

    private func screenForCompanion() -> NSScreen? {
        NSScreen.screens.first { $0.frame.intersects(companionWindow.frame) } ?? NSScreen.main
    }

    // MARK: Drag-to-reposition (horizontal, clamped, with jelly wobble)

    private func wireCompanionDrag() {
        appState.onCompanionDragBegan = { [weak self] in
            guard let self else { return }
            // Remember where on Pickle the cursor grabbed, so he follows the
            // cursor instead of snapping his origin to it.
            grabOffsetX = NSEvent.mouseLocation.x - companionWindow.frame.origin.x
        }

        appState.onCompanionDrag = { [weak self] mouseX, velocityX in
            guard let self, let screen = screenForCompanion() else { return }
            let vf = screen.visibleFrame
            var x = mouseX - grabOffsetX
            x = min(max(x, vf.minX), vf.maxX - companionSize.width)   // stay on-screen
            let y = vf.minY + 2                                        // Y locked above the Dock
            companionWindow.setFrameOrigin(NSPoint(x: x, y: y))
            if appState.panelVisible { positionPanel() }              // panel follows
            // Lean + stretch toward the drag direction; the spring in the view
            // gives it jelly. Velocity is per-event delta, so scale it down.
            appState.jelly = max(-1, min(1, velocityX / 16))
        }

        appState.onCompanionDragEnded = { [weak self] in
            self?.appState.jelly = 0     // springs back, overshooting → wobble
        }
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
