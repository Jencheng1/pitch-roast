import SwiftUI

/// Stage 6 — setup. OpenAI powers the whole voice-first experience out of the
/// box (transcription, voice, analysis) from a single key. Claude is an optional
/// analysis engine. Deliberately minimal — Pickle is not enterprise software.
struct SettingsStage: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                providerCard
                openAICard
                if app.provider == .claude { claudeCard }
                voiceCard
                aboutCard
                Spacer(minLength: 0)
            }
            .padding(16)
        }
    }

    // MARK: Provider

    private var providerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Analysis engine", systemImage: "cpu")
            Text("OpenAI is the default and needs the least setup. Prefer Claude for the analysis? Switch here.")
                .font(.pickleBody(12)).foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ForEach(AnalysisProviderKind.allCases) { kind in
                    ProviderChip(kind: kind, selected: app.provider == kind) {
                        Haptics.tap(); app.setProvider(kind)
                    }
                }
            }
        }
        .padding(14).glassCard()
    }

    // MARK: OpenAI key (primary)

    private var openAICard: some View {
        KeyField(
            title: "OpenAI API key",
            blurb: "Powers transcription, Pickle's voice, and (by default) the analysis — one key for the whole experience. Get one at platform.openai.com.",
            placeholder: "sk-…",
            present: app.openAIKeyPresent,
            connectedText: "OpenAI connected — Pickle can hear, think, and speak.",
            emptyText: "No key yet. With Apple's on-device speech you can still record, but analysis needs a key.",
            onSave: app.saveOpenAIKey,
            onClear: app.clearOpenAIKey
        )
    }

    // MARK: Claude key (optional)

    private var claudeCard: some View {
        KeyField(
            title: "Anthropic API key",
            blurb: "Used only because you chose Claude for analysis. Stored in your Keychain; from console.anthropic.com.",
            placeholder: "sk-ant-…",
            present: app.claudeKeyPresent,
            connectedText: "Claude connected — it will analyze your pitches.",
            emptyText: "Add a key, or switch the engine back to OpenAI above.",
            onSave: app.saveClaudeKey,
            onClear: app.clearClaudeKey
        )
    }

    // MARK: Voice

    private var voiceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { app.speakFeedback }, set: { app.setSpeakFeedback($0) })) {
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2.fill").foregroundStyle(Theme.brassBright)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Speak feedback aloud").font(.pickleHeadline(13)).foregroundStyle(.white)
                        Text("Pickle reads the roast in his investor voice.")
                            .font(.pickleCaption(10)).foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
            .toggleStyle(.switch)
            .tint(Theme.pickle)
        }
        .padding(14).glassCard()
    }

    // MARK: About

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "How Pickle works", systemImage: "info.circle")
            Label("With an OpenAI key, your audio is sent to OpenAI (Whisper) to transcribe.",
                  systemImage: "waveform").labelStyle(InfoLabel())
            Label("Without one, transcription stays on-device via Apple Speech.",
                  systemImage: "mic.fill").labelStyle(InfoLabel())
            Label("Your transcript is analyzed by the engine you picked above.",
                  systemImage: "cpu").labelStyle(InfoLabel())
            Label("Scores, history, and your keys stay on your Mac.",
                  systemImage: "lock.shield").labelStyle(InfoLabel())
        }
        .padding(14).glassCard()
    }
}

// MARK: - Reusable key field

private struct KeyField: View {
    let title: String
    let blurb: String
    let placeholder: String
    let present: Bool
    let connectedText: String
    let emptyText: String
    let onSave: (String) -> Void
    let onClear: () -> Void

    @State private var input = ""
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: title, systemImage: "key.fill")
            Text(blurb)
                .font(.pickleBody(12)).foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Image(systemName: "lock.fill").foregroundStyle(.white.opacity(0.4)).font(.system(size: 11))
                SecureField(placeholder, text: $input)
                    .textFieldStyle(.plain).font(.pickleBody(12)).foregroundStyle(.white)
            }
            .padding(10)
            .background(.white.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 10) {
                PickleButton(title: saved ? "Saved ✓" : "Save key",
                             systemImage: saved ? "checkmark" : "tray.and.arrow.down") {
                    onSave(input); input = ""; saved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { saved = false }
                }
                if present {
                    PickleButton(title: "Remove", systemImage: "trash", style: .ghost) { onClear() }
                }
            }

            HStack(spacing: 6) {
                Circle().fill(present ? Theme.cool : Theme.warm).frame(width: 7, height: 7)
                Text(present ? connectedText : emptyText)
                    .font(.pickleCaption(11)).foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14).glassCard()
    }
}

private struct ProviderChip: View {
    let kind: AnalysisProviderKind
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title).font(.pickleHeadline(13)).foregroundStyle(.white)
                Text(kind.subtitle).font(.pickleCaption(10)).foregroundStyle(.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(selected ? Theme.brass.opacity(0.20) : .white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(selected ? Theme.brassBright.opacity(0.7) : .white.opacity(0.10),
                                  lineWidth: selected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
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
