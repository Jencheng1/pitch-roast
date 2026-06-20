import Foundation

/// Strict JSON Schema for the brain-dump synthesis (shared by both providers).
/// Every object is `additionalProperties:false` with all keys required; keys
/// match `BrainDumpSynthesis` exactly.
enum BrainDumpSchema {

    static let json = """
    {
      "type": "object",
      "additionalProperties": false,
      "required": ["headline","summary","themes","ideas","bestBet","painPoints","openQuestions","nextSteps","pitchAngle"],
      "properties": {
        "headline": { "type": "string", "description": "One punchy line: Pickle's read on the most promising thread." },
        "summary": { "type": "string", "description": "A short synthesis of what the founder talked through." },
        "themes": { "type": "array", "items": { "$ref": "#/$defs/theme" } },
        "ideas": { "type": "array", "items": { "$ref": "#/$defs/idea" }, "description": "Startup concepts pulled from the dump, strongest first." },
        "bestBet": { "type": "string", "description": "Which idea is strongest and why — one short paragraph." },
        "painPoints": { "type": "array", "items": { "type": "string" }, "description": "Customer pains / observations worth chasing." },
        "openQuestions": { "type": "array", "items": { "type": "string" }, "description": "What to investigate next." },
        "nextSteps": { "type": "array", "items": { "$ref": "#/$defs/step" } },
        "pitchAngle": { "type": "string", "description": "A concrete pitch angle the founder could practice next." }
      },
      "$defs": {
        "theme": {
          "type": "object",
          "additionalProperties": false,
          "required": ["title","detail"],
          "properties": {
            "title": { "type": "string" },
            "detail": { "type": "string" }
          }
        },
        "idea": {
          "type": "object",
          "additionalProperties": false,
          "required": ["name","problem","audience","whyNow","valueProp","conviction"],
          "properties": {
            "name": { "type": "string" },
            "problem": { "type": "string" },
            "audience": { "type": "string", "description": "Who it's for." },
            "whyNow": { "type": "string" },
            "valueProp": { "type": "string", "description": "The promise in one line." },
            "conviction": { "type": "integer", "description": "0-100, how promising it is." }
          }
        },
        "step": {
          "type": "object",
          "additionalProperties": false,
          "required": ["action","why"],
          "properties": {
            "action": { "type": "string" },
            "why": { "type": "string" }
          }
        }
      }
    }
    """

    static var object: Any {
        (try? JSONSerialization.jsonObject(with: Data(json.utf8))) ?? [:]
    }
}
