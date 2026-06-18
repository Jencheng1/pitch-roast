import AppKit

/// A borderless, non-activating, always-floating panel — the shell for both the
/// companion and the pitch panel. Non-activating means clicking Pickle never
/// steals focus from the app you're rehearsing against.
final class FloatingPanel: NSPanel {
    init(size: NSSize, movableByBackground: Bool) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false                         // SwiftUI draws the glass shadow
        isMovableByWindowBackground = movableByBackground
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }      // text fields in Settings need key
    override var canBecomeMain: Bool { false }
}
