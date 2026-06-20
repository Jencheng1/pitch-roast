import SwiftUI
import AppKit

/// The always-present companion: Pickle hovering above the Dock with a speech
/// bubble. Click him to open the panel; drag him horizontally to reposition him
/// anywhere above the Dock — he wobbles like jelly toward the drag. While
/// recording he reacts to your voice; while analyzing he's lost in thought.
struct CompanionView: View {
    @EnvironmentObject private var app: AppState
    @State private var showBubble = false
    @State private var bubbleText = ""

    // Drag tracking — distinguishes a click (toggle) from a drag (reposition).
    @State private var dragGrabbed = false
    @State private var dragMoved: CGFloat = 0
    @State private var lastMouseX: CGFloat = 0

    var body: some View {
        VStack(spacing: 4) {
            bubble
                .opacity(showBubble ? 1 : 0)
                .scaleEffect(showBubble ? 1 : 0.85, anchor: .bottom)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showBubble)

            PickleMascotView(
                mood: app.mood,
                audioLevel: app.recorder.level,
                size: 80
            )
            .overlay(alignment: .bottom) { statusPip }
            // Idle-hop: stretch/squash, lean, and lift, planted at the base.
            .scaleEffect(x: 1 - app.hopStretch * 0.12,
                         y: 1 + app.hopStretch * 0.18, anchor: .bottom)
            .rotationEffect(.degrees(Double(app.hopLean) * 10), anchor: .bottom)
            .offset(y: app.hopLift)
            // Jelly: lean + stretch toward the drag, planted at the base.
            .rotationEffect(.degrees(Double(app.jelly) * 15), anchor: .bottom)
            .scaleEffect(x: 1 + abs(app.jelly) * 0.16,
                         y: 1 - abs(app.jelly) * 0.10, anchor: .bottom)
            .offset(x: app.jelly * 6)
            .animation(.interactiveSpring(response: 0.26, dampingFraction: 0.4), value: app.jelly)
            .padding(.bottom, -12)         // plant his base on the Dock's top edge
            .contentShape(Rectangle())
            .gesture(dragGesture)
        }
        .frame(width: 150, height: 150, alignment: .bottom)
        .onHover { hovering in
            if hovering { flashBubble(app.mood.quip) }
            else if app.stage != .recording { showBubble = false }
        }
        .onChange(of: app.mood) { _, newMood in
            // Pickle pipes up when his mood changes (e.g. results land).
            flashBubble(newMood.quip)
        }
        .onChange(of: app.toast) { _, t in
            // If the panel's closed, nudge via the bubble so the scan isn't missed.
            if t != nil, !app.panelVisible { flashBubble("Competitor scan's ready 👀") }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                flashBubble("Pitch me.")
            }
        }
    }

    // MARK: Bubble

    private var bubble: some View {
        Text(bubbleText.isEmpty ? app.mood.quip : bubbleText)
            .font(.pickleCaption(11))
            .foregroundStyle(Theme.pickleDeep)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .frame(maxWidth: 140)
            .background(Theme.cream)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .bottom) {
                Triangle().fill(Theme.cream)
                    .frame(width: 12, height: 7).offset(y: 6)
            }
            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }

    // MARK: Status pip (recording timer / analyzing spinner)

    @ViewBuilder private var statusPip: some View {
        switch app.stage {
        case .recording:
            Text(timeString(app.recorder.elapsed))
                .font(.pickleCaption(10).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Theme.hot)
                .clipShape(Capsule())
                .offset(y: -4)         // sit at his base, above the Dock (not clipped)
        case .analyzing:
            ProgressView().controlSize(.small).offset(y: -4)
        default:
            EmptyView()
        }
    }

    // MARK: Actions

    /// One gesture handles both: a short press toggles the panel; a horizontal
    /// drag repositions Pickle. We use the cursor's absolute screen position
    /// (via `NSEvent.mouseLocation`) so moving the window never feeds back into
    /// the gesture's own translation.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { _ in
                let mx = NSEvent.mouseLocation.x
                if !dragGrabbed {
                    dragGrabbed = true
                    dragMoved = 0
                    lastMouseX = mx
                    app.onCompanionDragBegan?()
                } else {
                    let dx = mx - lastMouseX
                    dragMoved += abs(dx)
                    if dragMoved > 4 { app.onCompanionDrag?(mx, dx) }   // it's a drag
                    lastMouseX = mx
                }
            }
            .onEnded { _ in
                dragGrabbed = false
                if dragMoved <= 4 { tap() }                  // barely moved → it was a click
                else { app.onCompanionDragEnded?() }         // release → jelly springs back
            }
    }

    private func tap() {
        Haptics.tap()
        app.togglePanel()
    }

    private func flashBubble(_ text: String) {
        bubbleText = text
        showBubble = true
        guard app.stage != .recording else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            if app.stage != .recording { showBubble = false }
        }
    }

    private func timeString(_ t: TimeInterval) -> String {
        String(format: "%01d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

/// Little speech-bubble tail.
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
