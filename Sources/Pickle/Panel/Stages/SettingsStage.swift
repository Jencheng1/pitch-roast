import SwiftUI

/// Stage 6 — setup. The Anthropic API key (stored in Keychain) and a little
/// about how Pickle works. Deliberately minimal — Pickle is not enterprise software.
struct SettingsStage: View {
    @EnvironmentObject private var app: AppState
    @State private var keyInput = ""
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: "Anthropic API key", systemImage: "key.fill")
                    Text("Pickle thinks with Claude. Paste a key from console.anthropic.com — it's stored only in your macOS Keychain and never leaves your Mac except to call Claude.")
                        .font(.pickleBody(12)).foregroundStyle(.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Image(systemName: "lock.fill").foregroundStyle(.white.opacity(0.4)).font(.system(size: 11))
                        SecureField("sk-ant-…", text: $keyInput)
                            .textFieldStyle(.plain)
                            .font(.pickleBody(12))
                            .foregroundStyle(.white)
                    }
                    .padding(10)
                    .background(.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.12), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    HStack(spacing: 10) {
                        PickleButton(title: saved ? "Saved ✓" : "Save key",
                                     systemImage: saved ? "checkmark" : "tray.and.arrow.down") {
                            app.saveAPIKey(keyInput)
                            keyInput = ""
                            saved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { saved = false }
                        }
                        if app.hasAPIKey {
                            PickleButton(title: "Remove", systemImage: "trash", style: .ghost) {
                                app.clearAPIKey()
                            }
                        }
                    }

                    statusRow
                }
                .padding(14).glassCard()

                aboutCard

                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .onAppear { saved = false }
    }

    private var statusRow: some View {
        HStack(spacing: 6) {
            Circle().fill(app.hasAPIKey ? Theme.cool : Theme.warm).frame(width: 7, height: 7)
            Text(app.hasAPIKey ? "Key connected — Pickle is ready." : "No key yet — add one to start pitching.")
                .font(.pickleCaption(11)).foregroundStyle(.white.opacity(0.7))
        }
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "How Pickle works", systemImage: "info.circle")
            Label("Your voice is transcribed on-device with Apple Speech.",
                  systemImage: "mic.fill").labelStyle(InfoLabel())
            Label("Only the transcript is sent to Claude for analysis.",
                  systemImage: "brain.head.profile").labelStyle(InfoLabel())
            Label("Scores and history stay on your Mac.",
                  systemImage: "lock.shield").labelStyle(InfoLabel())
            Label("Click Pickle any time to practice one more run.",
                  systemImage: "hand.tap").labelStyle(InfoLabel())
        }
        .padding(14).glassCard()
    }
}

private struct InfoLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 8) {
            configuration.icon.foregroundStyle(Theme.brassBright).font(.system(size: 11)).frame(width: 16)
            configuration.title.font(.pickleBody(12)).foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
