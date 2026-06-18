import Foundation

/// Turns the session history into the trend lines Pickle shows in the progress
/// view: confidence, readiness, presentation quality, and overall — plus deltas.
struct ProgressTracker {
    let sessions: [SessionRecord]   // newest first (as stored)

    /// Chronological (oldest → newest) for plotting.
    private var chrono: [SessionRecord] { sessions.reversed() }

    enum Metric: String, CaseIterable, Identifiable {
        case overall = "Overall"
        case readiness = "Readiness"
        case confidence = "Confidence"
        case presentation = "Presentation"
        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .overall: return "chart.line.uptrend.xyaxis"
            case .readiness: return "checkmark.seal"
            case .confidence: return "bolt.heart"
            case .presentation: return "theatermasks"
            }
        }
    }

    func value(_ m: Metric, in r: SessionRecord) -> Int {
        switch m {
        case .overall:      return r.analysis.overallScore
        case .readiness:    return r.analysis.readiness
        case .confidence:   return r.analysis.confidenceScore
        case .presentation: return r.analysis.presentationQuality
        }
    }

    /// Plot points for a metric, oldest → newest.
    func series(_ m: Metric) -> [Int] { chrono.map { value(m, in: $0) } }

    /// Change vs. the previous session for a metric (nil if < 2 sessions).
    func delta(_ m: Metric) -> Int? {
        guard chrono.count >= 2 else { return nil }
        return value(m, in: chrono[chrono.count - 1]) - value(m, in: chrono[chrono.count - 2])
    }

    func current(_ m: Metric) -> Int {
        guard let last = chrono.last else { return 0 }
        return value(m, in: last)
    }

    var totalSessions: Int { sessions.count }

    /// A warm one-liner summarizing momentum.
    var momentumLine: String {
        guard let d = delta(.readiness) else {
            return sessions.isEmpty ? "Your first run is the hardest. Let's go."
                                    : "One down. Patterns show up around run three."
        }
        switch d {
        case let x where x >= 8:  return "You're climbing fast — keep this energy."
        case 1...7:               return "Steady gains. This is how funded founders are made."
        case 0:                   return "Holding steady. Time to push one dimension higher."
        default:                  return "Off day — even great pitches wobble. Run it back."
        }
    }
}
