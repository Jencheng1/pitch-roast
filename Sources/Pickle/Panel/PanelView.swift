import SwiftUI

/// The floating glass panel. A slim header for navigation, then the current
/// stage. Voice-first: the welcome and recording stages dominate the flow.
struct PanelView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(.white.opacity(0.08))
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.pickleDeep.opacity(0.55))   // tints the vibrancy briny
        .glassPanel()
        .padding(10)                                  // room for the shadow
        .frame(width: 372, height: 540)
        .preferredColorScheme(.dark)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            PickleMascotView(mood: app.mood, audioLevel: app.recorder.level, size: 34)
                .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 0) {
                Text("Pickle").font(.pickleHeadline(14)).foregroundStyle(.white)
                Text(subtitle).font(.pickleCaption(10)).foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            navButton("clock.arrow.circlepath", active: app.stage == .history) { app.goHistory() }
            navButton("gearshape", active: app.stage == .settings) { app.goSettings() }
            navButton("xmark") { app.hidePanel() }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private var subtitle: String {
        switch app.stage {
        case .welcome:   return "your tiny investor"
        case .recording: return "listening…"
        case .analyzing: return "thinking…"
        case .results:   return "the verdict"
        case .history:   return "your progress"
        case .settings:  return "setup"
        }
    }

    private func navButton(_ icon: String, active: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(active ? Theme.brassBright : .white.opacity(0.6))
                .frame(width: 26, height: 26)
                .background(active ? Theme.brass.opacity(0.18) : .white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Body router

    @ViewBuilder private var content: some View {
        ZStack {
            switch app.stage {
            case .welcome:   WelcomeStage()
            case .recording: RecordingStage()
            case .analyzing: AnalyzingStage()
            case .results:   ResultsStage()
            case .history:   HistoryStage()
            case .settings:  SettingsStage()
            }
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)),
            removal: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: app.stage)
    }
}
