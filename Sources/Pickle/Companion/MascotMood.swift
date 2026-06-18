import Foundation

/// Pickle's emotional states. Mood drives the mascot's eyes, mouth, bob, and tint.
/// Mood is derived from the app's flow stage and (after analysis) the score.
enum MascotMood: Equatable {
    case idle            // chilling above the dock, occasional blink
    case curious         // panel just opened, leaning in
    case listening       // recording — eyes wide, reacting to your voice
    case thinking        // analyzing — eyes closed, "hmm"
    case impressed       // great score — sparkle
    case skeptical       // mid score — raised brow
    case roasting        // low score — smirk, brutal but loving
    case celebrating     // new personal best

    /// One-liner Pickle "says" in the companion bubble for this mood.
    var quip: String {
        switch self {
        case .idle:        return ["One more run?", "Pitch me.", "I've got money to burn.", "Practice makes funded."].randomElement()!
        case .curious:     return "Alright, what've you got?"
        case .listening:   return "I'm listening…"
        case .thinking:    return "Hmm. Crunching the numbers…"
        case .impressed:   return "Okay, *now* we're talking."
        case .skeptical:   return "Not bad. Not term-sheet good."
        case .roasting:    return "Bless your heart. Let's fix this."
        case .celebrating: return "New personal best! Proud of you."
        }
    }
}
