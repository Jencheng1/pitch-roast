import Foundation

/// JSON Schema for Claude structured outputs (`output_config.format`). Every
/// object sets `additionalProperties:false` and lists all keys in `required`,
/// as structured outputs require. Keys match `PitchAnalysis` exactly.
///
/// Note: structured outputs ignore numeric constraints (min/max), so scores are
/// plain integers and the prompt is what holds them to the 0–100 range.
enum AnalysisSchema {

    static let json = """
    {
      "type": "object",
      "additionalProperties": false,
      "required": ["overallScore","investorInterest","interestLabel","verdict","strengths","weaknesses","likelyQuestions","recommendations","roast","dimensions"],
      "properties": {
        "overallScore": { "type": "integer", "description": "0-100 overall quality of the pitch." },
        "investorInterest": { "type": "integer", "description": "0-100 how interested a real seed investor would be." },
        "interestLabel": { "type": "string", "description": "Short verdict on interest, e.g. 'Would take a second meeting'." },
        "verdict": { "type": "string", "description": "One punchy sentence summarizing the pitch." },
        "strengths": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": ["title","detail"],
            "properties": {
              "title": { "type": "string" },
              "detail": { "type": "string" }
            }
          }
        },
        "weaknesses": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": ["title","detail"],
            "properties": {
              "title": { "type": "string" },
              "detail": { "type": "string" }
            }
          }
        },
        "likelyQuestions": { "type": "array", "items": { "type": "string" }, "description": "The top 5 questions an investor would ask in the room, with their concerns/objections folded in as pointed questions." },
        "recommendations": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": ["action","why"],
            "properties": {
              "action": { "type": "string" },
              "why": { "type": "string" }
            }
          }
        },
        "roast": { "type": "string", "description": "Brutally honest, witty, but ultimately constructive roast of the pitch. 2-4 sentences." },
        "dimensions": {
          "type": "object",
          "additionalProperties": false,
          "required": ["problemClarity","solutionClarity","storytelling","confidence","delivery","marketOpportunity","differentiation","businessModel","founderCredibility","investorAppeal","timing"],
          "properties": {
            "problemClarity":   { "$ref": "#/$defs/dim" },
            "solutionClarity":  { "$ref": "#/$defs/dim" },
            "storytelling":     { "$ref": "#/$defs/dim" },
            "confidence":       { "$ref": "#/$defs/dim" },
            "delivery":         { "$ref": "#/$defs/dim" },
            "marketOpportunity":{ "$ref": "#/$defs/dim" },
            "differentiation":  { "$ref": "#/$defs/dim" },
            "businessModel":    { "$ref": "#/$defs/dim" },
            "founderCredibility":{ "$ref": "#/$defs/dim" },
            "investorAppeal":   { "$ref": "#/$defs/dim" },
            "timing":           { "$ref": "#/$defs/dim" }
          }
        }
      },
      "$defs": {
        "dim": {
          "type": "object",
          "additionalProperties": false,
          "required": ["score","note"],
          "properties": {
            "score": { "type": "integer", "description": "0-100" },
            "note": { "type": "string", "description": "One short line on why." }
          }
        }
      }
    }
    """

    /// Parsed form for embedding in the request body via JSONSerialization.
    static var object: Any {
        (try? JSONSerialization.jsonObject(with: Data(json.utf8))) ?? [:]
    }
}
