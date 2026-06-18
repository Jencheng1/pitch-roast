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
    private let panelWidth: CGFloat = 372
    private let panelCollapsedHeight: CGFloat = 540
    private let panelExpandedHeight: CGFloat = 760   // clamped to the screen

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
        panelWindow = FloatingPanel(
            size: NSSize(width: panelWidth, height: panelCollapsedHeight),
            movableByBackground: false)
        // The hosting view fills the window so the panel's content reflows as the
        // window grows/shrinks on expand — width fixed, height flexible.
        let host = NSHostingView(rootView: PanelView().environmentObject(appState))
        host.autoresizingMask = [.width, .height]
        panelWindow.contentView = host
    }

    // MARK: Placement

    private func positionCompanion() {
        guard let screen = NSScreen.main else { return }
        let vf = screen.visibleFrame          // excludes the Dock + menu bar
        let x = vf.midX - companionSize.width / 2
        let y = vf.minY                        // window bottom on the Dock's top edge
        companionWindow.setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// The panel frame: bottom tucked behind Pickle's head, width fixed, height
    /// from the collapsed/expanded state (clamped to the screen). Growing keeps
    /// the bottom anchored, so the panel opens *upward* like a workspace.
    private func panelFrame() -> NSRect {
        let screen = screenForCompanion() ?? NSScreen.main
        let vf = screen?.visibleFrame ?? companionWindow.frame
        let cFrame = companionWindow.frame
        let bottom = cFrame.minY + panelOverlapY
        let available = vf.maxY - bottom - 8
        let target = appState.expanded ? panelExpandedHeight : panelCollapsedHeight
        let height = max(panelCollapsedHeight - 1, min(target, available))
        var x = cFrame.midX - panelWidth / 2
        x = min(max(x, vf.minX + 8), vf.maxX - panelWidth - 8)
        return NSRect(x: x, y: bottom, width: panelWidth, height: height)
    }

    /// Apply the panel frame, optionally animated (used for expand/collapse).
    private func layoutPanel(animated: Bool) {
        let frame = panelFrame()
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.34
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panelWindow.animator().setFrame(frame, display: true)
            }
        } else {
            panelWindow.setFrame(frame, display: true)
        }
    }

    @objc private func screenChanged() {
        positionCompanion()
        if appState.panelVisible { layoutPanel(animated: false) }
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
            let y = vf.minY                                           // Y locked on the Dock
            companionWindow.setFrameOrigin(NSPoint(x: x, y: y))
            if appState.panelVisible { layoutPanel(animated: false) } // panel follows
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
                    self.layoutPanel(animated: false)
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

        // Expand / collapse — animate the window taller/shorter, bottom anchored.
        appState.$expanded
            .removeDuplicates()
            .dropFirst()                       // ignore the initial value
            .sink { [weak self] _ in
                guard let self, self.appState.panelVisible else { return }
                self.layoutPanel(animated: true)
            }
            .store(in: &cancellables)
    }
}
