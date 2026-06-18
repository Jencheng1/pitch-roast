import Foundation

/// The pitch formats a founder can rehearse. Each maps to a target duration
/// and shapes what Pickle expects to hear, which is fed into the analysis prompt.
enum PitchLength: String, CaseIterable, Codable, Identifiable {
    case elevator      // 30s — the hallway / cold intro
    case demoDay       // 60s — demo-day rapid fire
    case standard      // 2m  — the classic pitch
    case deepDive      // 5m  — full narrative with traction

    var id: String { rawValue }

    var title: String {
        switch self {
        case .elevator:  return "Elevator"
        case .demoDay:   return "Demo Day"
        case .standard:  return "Standard"
        case .deepDive:  return "Deep Dive"
        }
    }

    var subtitle: String {
        switch self {
        case .elevator:  return "30 sec · one breath"
        case .demoDay:   return "60 sec · rapid fire"
        case .standard:  return "2 min · the classic"
        case .deepDive:  return "5 min · full story"
        }
    }

    var emoji: String {
        switch self {
        case .elevator:  return "🛗"
        case .demoDay:   return "🎤"
        case .standard:  return "⏱️"
        case .deepDive:  return "🎬"
        }
    }

    /// Target duration in seconds.
    var targetSeconds: Int {
        switch self {
        case .elevator:  return 30
        case .demoDay:   return 60
        case .standard:  return 120
        case .deepDive:  return 300
        }
    }

    /// Hard cap for the recorder, with a little grace over the target.
    var maxSeconds: Int { Int(Double(targetSeconds) * 1.5) }

    /// Guidance Pickle uses when judging pacing and completeness.
    var coachingContext: String {
        switch self {
        case .elevator:
            return "A 30-second elevator pitch. The founder must land the problem and the hook fast — there is no time for a full narrative. Reward clarity and a memorable one-liner; penalize rambling."
        case .demoDay:
            return "A 60-second demo-day pitch. Expect problem, solution, a sliver of traction, and an ask. Reward density and energy; penalize anything that wastes seconds."
        case .standard:
            return "A 2-minute standard pitch. Expect problem, solution, market, why-now, and traction. Reward a clean arc and confident delivery."
        case .deepDive:
            return "A 5-minute deep-dive pitch. Expect a full narrative: problem, insight, solution, market, business model, traction, team, and ask. Reward storytelling and depth; penalize thin sections."
        }
    }
}
