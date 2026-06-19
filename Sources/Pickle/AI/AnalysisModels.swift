import Foundation

/// The typed result of a pitch analysis. Decoded directly from Claude's
/// structured-output JSON (see `AnalysisSchema`). Field names match the schema.
struct PitchAnalysis: Codable, Equatable {
    var overallScore: Int            // 0–100
    var investorInterest: Int        // 0–100 — "would I take a meeting?"
    var interestLabel: String        // e.g. "Would take a second meeting"
    var verdict: String              // one punchy sentence
    var strengths: [Highlight]
    var weaknesses: [Highlight]
    var likelyQuestions: [String]   // top 5 — folds in the investor's concerns
    var recommendations: [Recommendation]
    var roast: String                // brutally honest, witty, constructive
    var dimensions: Dimensions

    struct Highlight: Codable, Equatable, Identifiable {
        var id = UUID()
        var title: String
        var detail: String
        private enum CodingKeys: String, CodingKey { case title, detail }
    }

    struct Recommendation: Codable, Equatable, Identifiable {
        var id = UUID()
        var action: String
        var why: String
        private enum CodingKeys: String, CodingKey { case action, why }
    }

    /// The eleven judged dimensions of the pitch.
    struct Dimensions: Codable, Equatable {
        var problemClarity: Dim
        var solutionClarity: Dim
        var storytelling: Dim
        var confidence: Dim
        var delivery: Dim
        var marketOpportunity: Dim
        var differentiation: Dim
        var businessModel: Dim
        var founderCredibility: Dim
        var investorAppeal: Dim
        var timing: Dim

        /// Ordered (label, value) pairs for rendering bars.
        var ordered: [(String, Dim)] {
            [("Problem clarity", problemClarity),
             ("Solution clarity", solutionClarity),
             ("Storytelling", storytelling),
             ("Confidence", confidence),
             ("Delivery", delivery),
             ("Market", marketOpportunity),
             ("Differentiation", differentiation),
             ("Business model", businessModel),
             ("Founder credibility", founderCredibility),
             ("Investor appeal", investorAppeal),
             ("Timing", timing)]
        }
    }

    struct Dim: Codable, Equatable {
        var score: Int               // 0–100
        var note: String             // one line on why
    }
}

extension PitchAnalysis {
    /// Derived presentation-quality index (delivery + storytelling + confidence).
    var presentationQuality: Int {
        let d = dimensions
        return (d.delivery.score + d.storytelling.score + d.confidence.score) / 3
    }

    /// Derived readiness index — how close to facing a real investor.
    var readiness: Int {
        Int((Double(overallScore) * 0.6 + Double(investorInterest) * 0.4).rounded())
    }

    var confidenceScore: Int { dimensions.confidence.score }
}
