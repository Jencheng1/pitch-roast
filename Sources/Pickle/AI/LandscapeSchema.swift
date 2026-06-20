import Foundation

/// Strict JSON Schema for the live-research landscape step (the second call that
/// structures web-search findings). Decodes into `BrainDumpSynthesis.Landscape`.
/// Players carry a `url` here (found via search); the `live` flag is set in code.
enum LandscapeSchema {

    static let json = """
    {
      "type": "object",
      "additionalProperties": false,
      "required": ["category","saturation","marketRead","players","whitespace","edge"],
      "properties": {
        "category": { "type": "string", "description": "The market/category this idea sits in." },
        "saturation": { "type": "integer", "description": "0-100, how crowded/contested the space is." },
        "marketRead": { "type": "string", "description": "Honest read on how contested it is and whether it's worth pursuing." },
        "players": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": ["name","what","relationship","gap","url"],
            "properties": {
              "name": { "type": "string" },
              "what": { "type": "string", "description": "What they do, one line." },
              "relationship": { "type": "string", "description": "Direct competitor, Adjacent, Incumbent, Alternative, or DIY / status quo." },
              "gap": { "type": "string", "description": "Where they fall short relative to this idea." },
              "url": { "type": "string", "description": "Homepage URL if found, else empty string." }
            }
          }
        },
        "whitespace": { "type": "array", "items": { "type": "string" } },
        "edge": { "type": "array", "items": { "type": "string" } }
      }
    }
    """

    static var object: Any {
        (try? JSONSerialization.jsonObject(with: Data(json.utf8))) ?? [:]
    }
}
