import Foundation

/// The structured synthesis Pickle produces from a freeform brain dump. Unlike a
/// pitch analysis, there's no score or roast — this is Pickle finding the signal
/// in the noise and helping the founder think.
struct BrainDumpSynthesis: Codable, Equatable {
    var headline: String            // Pickle's one-line read on the most promising thread
    var summary: String             // short synthesis of what was said
    var themes: [Theme]             // recurring threads across the dump
    var ideas: [Idea]               // extracted startup concepts, strongest first
    var bestBet: String             // which idea to chase and why (a short paragraph)
    var painPoints: [String]        // customer pains / observations worth chasing
    var openQuestions: [String]     // what to investigate next
    var nextSteps: [Step]           // concrete next actions
    var pitchAngle: String          // a pitch angle to practice when ready

    struct Theme: Codable, Equatable, Identifiable {
        var id = UUID()
        var title: String
        var detail: String
        private enum CodingKeys: String, CodingKey { case title, detail }
    }

    struct Idea: Codable, Equatable, Identifiable {
        var id = UUID()
        var name: String
        var problem: String
        var audience: String        // who it's for
        var whyNow: String
        var valueProp: String       // the promise in one line
        var conviction: Int         // 0–100, how promising Pickle thinks it is
        private enum CodingKeys: String, CodingKey {
            case name, problem, audience, whyNow, valueProp, conviction
        }
    }

    struct Step: Codable, Equatable, Identifiable {
        var id = UUID()
        var action: String
        var why: String
        private enum CodingKeys: String, CodingKey { case action, why }
    }

    /// The strongest extracted idea, if any (ideas come back strongest-first).
    var topIdea: Idea? { ideas.max(by: { $0.conviction < $1.conviction }) }
}
