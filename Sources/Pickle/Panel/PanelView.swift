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
        .overlay(alignment: .top) {
            if let t = app.toast {
                ToastBanner(toast: t, onTap: { app.tapToast() }, onClose: { app.dismissToast() })
                    .padding(.horizontal, 14).padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: app.toast)
        .background(Theme.pickleDeep.opacity(0.55))   // tints the vibrancy briny
        .glassPanel()
        // Shadow room on top/sides; almost none at the bottom so the glass
        // reaches down to meet Pickle, who overlaps it there anyway.
        .padding(.top, 10).padding(.horizontal, 10).padding(.bottom, 2)
        .frame(width: 372)                         // fixed width (preserved on expand)
        .frame(maxHeight: .infinity)               // height follows the window
        .preferredColorScheme(.dark)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            if app.canGoBack {
                navButton("chevron.left") { app.goBack() }
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
            PickleMascotView(mood: app.mood, audioLevel: app.recorder.level, size: 34)
                .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 0) {
                Text("Pickle").font(.pickleHeadline(14)).foregroundStyle(.white)
                Text(subtitle).font(.pickleCaption(10)).foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            navButton("clock.arrow.circlepath", active: app.stage == .history) { app.goHistory() }
            navButton("gearshape", active: app.stage == .settings) { app.goSettings() }
            navButton(app.expanded ? "arrow.down.right.and.arrow.up.left"
                                   : "arrow.up.left.and.arrow.down.right",
                      active: app.expanded) { app.toggleExpand() }
            navButton("xmark") { app.hidePanel() }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: app.canGoBack)
    }

    private var subtitle: String {
        switch app.stage {
        case .welcome:   return app.mode == .brainDump ? "think out loud" : "your tiny investor"
        case .recording: return app.mode == .brainDump ? "all ears…" : "listening…"
        case .analyzing: return app.mode == .brainDump ? "connecting dots…" : "thinking…"
        case .results:   return "the verdict"
        case .brainDumpResults: return "your ideas"
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

    // MARK: Toast banner

    private struct ToastBanner: View {
        let toast: PickleToast
        let onTap: () -> Void
        let onClose: () -> Void

        var body: some View {
            HStack(spacing: 9) {
                Image(systemName: toast.icon)
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.cool)
                Text(toast.message)
                    .font(.pickleCaption(11)).foregroundStyle(.white)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(VisualEffectBlur(material: .hudWindow))
            .background(Theme.cool.opacity(0.20))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.cool.opacity(0.45), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 12, y: 5)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
        }
    }

    // MARK: Body router

    @ViewBuilder private var content: some View {
        ZStack {
            switch app.stage {
            case .welcome:   WelcomeStage()
            case .recording: RecordingStage()
            case .analyzing: AnalyzingStage()
            case .results:   ResultsStage()
            case .brainDumpResults: BrainDumpResultsStage()
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
