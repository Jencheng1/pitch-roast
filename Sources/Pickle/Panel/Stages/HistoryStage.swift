import SwiftUI

/// Stage 5 — progress over time. The core retention loop: founders watch
/// confidence, readiness, and presentation quality climb across sessions.
struct HistoryStage: View {
    @EnvironmentObject private var app: AppState
    @State private var metric: ProgressTracker.Metric = .readiness

    private var tracker: ProgressTracker { ProgressTracker(sessions: app.store.sessions) }

    var body: some View {
        if app.store.sessions.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: 14) {
                    metricPicker
                    trendCard
                    momentum
                    sessionList
                }
                .padding(16)
            }
            .safeAreaInset(edge: .bottom) { actionBar }
        }
    }

    // Sticky primary action — same "Pitch Again" affordance as the results screen.
    private var actionBar: some View {
        PickleButton(title: "Pitch Again", systemImage: "arrow.clockwise", style: .primary) {
            app.practiceAgain()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(VisualEffectBlur(material: .hudWindow).opacity(0.9))
    }

    // MARK: Metric picker

    private var metricPicker: some View {
        HStack(spacing: 6) {
            ForEach(ProgressTracker.Metric.allCases) { m in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { metric = m }
                } label: {
                    Text(m.rawValue).font(.pickleCaption(11))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)     // shrink before wrapping
                        .padding(.horizontal, 6).padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(metric == m ? Theme.brass.opacity(0.22) : .white.opacity(0.05))
                        .foregroundStyle(metric == m ? Theme.brassBright : .white.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Trend

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: metric.systemImage).foregroundStyle(Theme.brassBright)
                Text("\(tracker.current(metric))")
                    .font(.pickleScore(40)).foregroundStyle(.white)
                if let d = tracker.delta(metric) {
                    DeltaTag(delta: d)
                }
                Spacer()
                Text("\(tracker.totalSessions) runs")
                    .font(.pickleCaption(11)).foregroundStyle(.white.opacity(0.5))
            }
            Sparkline(values: tracker.series(metric), tint: Theme.brassBright)
                .frame(height: 70)
        }
        .padding(14)
        .glassCard()
    }

    private var momentum: some View {
        HStack(spacing: 10) {
            PickleMascotView(mood: .curious, size: 38).frame(width: 42, height: 42)
            Text(tracker.momentumLine)
                .font(.pickleBody(13)).foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12).glassCard()
    }

    // MARK: Session list

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Recent runs", systemImage: "list.bullet")
            ForEach(app.store.sessions) { record in
                Button {
                    app.result = record; app.isNewBest = false; app.stage = .results
                } label: {
                    HStack(spacing: 10) {
                        Text("\(record.analysis.overallScore)")
                            .font(.pickleScore(18))
                            .foregroundStyle(Theme.scoreColor(record.analysis.overallScore))
                            .frame(width: 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(record.length.title) · \(Int(record.durationSeconds))s")
                                .font(.pickleCaption(11)).foregroundStyle(.white.opacity(0.85))
                            Text(record.date, style: .relative)
                                .font(.pickleCaption(10)).foregroundStyle(.white.opacity(0.45))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.35))
                    }
                    .padding(10).glassCard()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            PickleMascotView(mood: .idle, size: 84)
            Text("No runs yet").font(.pickleTitle(18)).foregroundStyle(.white)
            Text("Record your first pitch and I'll start tracking your confidence and readiness over time.")
                .font(.pickleBody(13)).foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center).padding(.horizontal, 28)
            PickleButton(title: "Record a pitch", systemImage: "mic.fill") { app.goWelcome() }
                .padding(.horizontal, 40)
            Spacer()
        }
        .padding(16)
    }
}

private struct DeltaTag: View {
    let delta: Int
    var body: some View {
        let up = delta >= 0
        return HStack(spacing: 2) {
            Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
            Text("\(abs(delta))")
        }
        .font(.pickleCaption(10).monospacedDigit())
        .foregroundStyle(up ? Theme.cool : Theme.hot)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background((up ? Theme.cool : Theme.hot).opacity(0.16))
        .clipShape(Capsule())
    }
}

/// Hand-drawn sparkline so we ship no chart dependency.
struct Sparkline: View {
    let values: [Int]
    var tint: Color
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            ZStack {
                if pts.count > 1 {
                    // Fill under the line
                    linePath(pts, closed: true, in: geo.size)
                        .fill(LinearGradient(colors: [tint.opacity(0.25), .clear],
                                             startPoint: .top, endPoint: .bottom))
                    // Line
                    linePath(pts, closed: false, in: geo.size)
                        .trim(from: 0, to: progress)
                        .stroke(tint, style: .init(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    // Last dot
                    if let last = pts.last {
                        Circle().fill(tint).frame(width: 7, height: 7)
                            .position(last).opacity(Double(progress))
                    }
                } else {
                    Text("Two runs needed to chart a trend.")
                        .font(.pickleCaption(11)).foregroundStyle(.white.opacity(0.4))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) { progress = 1 }
            }
            .onChange(of: values) { _, _ in
                progress = 0
                withAnimation(.easeOut(duration: 0.6)) { progress = 1 }
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let maxV = max(values.max() ?? 100, 1)
        let minV = min(values.min() ?? 0, maxV)
        let span = max(maxV - minV, 1)
        let stepX = values.count > 1 ? size.width / CGFloat(values.count - 1) : 0
        return values.enumerated().map { i, v in
            let x = CGFloat(i) * stepX
            let norm = CGFloat(v - minV) / CGFloat(span)
            let y = size.height - norm * (size.height - 8) - 4
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(_ pts: [CGPoint], closed: Bool, in size: CGSize) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        if closed { p.move(to: CGPoint(x: first.x, y: size.height)); p.addLine(to: first) }
        else { p.move(to: first) }
        for pt in pts.dropFirst() { p.addLine(to: pt) }
        if closed, let last = pts.last {
            p.addLine(to: CGPoint(x: last.x, y: size.height)); p.closeSubpath()
        }
        return p
    }
}
