import SwiftUI

/// Stage 1 — choose a pitch length and start recording. Also surfaces the most
/// recent score and any error from the last run.
struct WelcomeStage: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(spacing: 16) {
            if let error = app.errorMessage {
                ErrorBanner(text: error)
            }

            VStack(spacing: 4) {
                Text("Ready for one more run?")
                    .font(.pickleTitle(19)).foregroundStyle(.white)
                Text("Pick a format. I'll be brutally honest.")
                    .font(.pickleBody(12)).foregroundStyle(.white.opacity(0.6))
            }
            .multilineTextAlignment(.center)
            .padding(.top, 4)

            // Length picker grid
            LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(PitchLength.allCases) { length in
                    LengthCard(length: length, selected: app.selectedLength == length) {
                        Haptics.tap()
                        app.selectedLength = length
                    }
                }
            }

            Spacer(minLength: 0)

            if let last = app.store.latest, app.errorMessage == nil {
                LastRunStrip(record: last) { app.openRecord(last) }
            }

            PickleButton(title: "Start Pitching", systemImage: "mic.fill") {
                app.startRecording()
            }

            if !app.canAnalyze {
                Button("Add your \(app.provider.keyName) API key to begin →") { app.goSettings() }
                    .buttonStyle(.plain)
                    .font(.pickleCaption(11))
                    .foregroundStyle(Theme.brassBright)
            }
        }
        .padding(16)
    }
}

private struct LengthCard: View {
    let length: PitchLength
    let selected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(length.emoji).font(.system(size: 22))
                Text(length.title).font(.pickleHeadline(13)).foregroundStyle(.white)
                Text(length.subtitle).font(.pickleCaption(10)).foregroundStyle(.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(11)
            .background(selected ? Theme.brass.opacity(0.20) : .white.opacity(hover ? 0.09 : 0.05))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .strokeBorder(selected ? Theme.brassBright.opacity(0.7) : .white.opacity(0.10),
                                  lineWidth: selected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .scaleEffect(selected ? 1.0 : (hover ? 1.01 : 1.0))
        .animation(.easeOut(duration: 0.15), value: hover)
    }
}

private struct LastRunStrip: View {
    let record: SessionRecord
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text("\(record.analysis.overallScore)")
                    .font(.pickleScore(20))
                    .foregroundStyle(Theme.scoreColor(record.analysis.overallScore))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Last \(record.length.title.lowercased()) pitch")
                        .font(.pickleCaption(11)).foregroundStyle(.white.opacity(0.85))
                    Text(record.analysis.interestLabel)
                        .font(.pickleCaption(10)).foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(10)
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}

struct ErrorBanner: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.warm).font(.system(size: 12))
            Text(text).font(.pickleCaption(11)).foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Theme.warm.opacity(0.14))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.warm.opacity(0.3), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
