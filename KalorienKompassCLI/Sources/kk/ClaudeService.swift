import Foundation

// MARK: - Fehlertypen

enum ClaudeServiceError: LocalizedError {
    case noAPIKey
    case networkError(Error)
    case invalidResponse(Int, String)
    case rateLimited
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "Kein API-Key. Setze CLAUDE_API_KEY oder lege ~/.config/kk/config.json an."
        case .networkError(let err):
            return "Netzwerkfehler: \(err.localizedDescription)"
        case .invalidResponse(let code, let body):
            return "API-Fehler (HTTP \(code)): \(body.prefix(200))"
        case .rateLimited:
            return "Rate Limit erreicht. Warte kurz und versuche es erneut."
        case .parseError(let detail):
            return "Antwort konnte nicht verarbeitet werden: \(detail)"
        }
    }
}

// MARK: - Hauptfunktion

/// Schätzt Nährwerte anhand einer Freitextbeschreibung via Claude Haiku.
/// Vereinfachte Version von ClaudeAPIService.estimateNutrients() aus der App.
func estimateMeal(description: String, apiKey: String) async throws -> [AIFoodEstimate] {
    let body: [String: Any] = [
        "model": "claude-haiku-4-5-20251001",
        "max_tokens": 1024,
        "system": claudeSystemPrompt,
        // Erzwingt die Antwortform, damit gesaettigte Fette, Zucker und Salz
        // nicht ausbleiben (Issue #95) — dieselbe Begruendung wie in
        // ClaudeAPIService.estimateSchema.
        "output_config": [
            "format": [
                "type": "json_schema",
                "schema": [
                    "type": "object",
                    "additionalProperties": false,
                    "properties": ["items": ["type": "array", "items": estimateSchema()]],
                    "required": ["items"]
                ]
            ]
        ],
        "messages": [[
            "role": "user",
            "content": "Lebensmittel: \(description)"
        ]]
    ]
    let text = try await sendAPIRequest(body: body, apiKey: apiKey)
    return try parseAIResponses(text)
}

// MARK: - Nachtrag fehlender Mikrowerte

/// Zaehlt nur auf, was tatsaechlich erfasst ist.
///
/// Ein nicht erfasster Makrowert steht im Modell als 0. Ihn als „0 g Fett" zu
/// nennen, waere eine Behauptung — und eine, die sich raecht: zusammen mit der
/// Regel „gesaettigte Fette nicht groesser als das Gesamtfett" zwingt sie die
/// Schaetzung auf null.
private func bekannteWerte(calories: Double, protein: Double, carbs: Double, fat: Double) -> String {
    var teile = ["\(Int(calories)) kcal"]
    if protein > 0 { teile.append(String(format: "%.1f g Protein", protein)) }
    if carbs > 0   { teile.append(String(format: "%.1f g Kohlenhydrate", carbs)) }
    if fat > 0     { teile.append(String(format: "%.1f g Fett", fat)) }
    return teile.joined(separator: ", ") + "."
}

/// Die drei Werte, die Altbestaenden fehlen (Issue #98).
struct Micronutrients: Decodable, Sendable {
    let saturatedFatPer100g: Double
    let sugarPer100g: Double
    let saltPer100g: Double
}

/// Schaetzt **nur** gesaettigte Fette, Zucker und Salz eines bekannten
/// Lebensmittels nach.
///
/// Bewusst kein vollstaendiger Neuaufruf: eine komplette Neuschaetzung wuerde
/// auch Kalorien und Makros ersetzen und damit rueckwirkend Tagessummen
/// verschieben (im Test sprang ein Fruchtaufstrich von 39 auf 220 kcal).
/// Vergangene Tage bleiben, wie sie waren; verbessert wird allein die Ampel.
///
/// Die bekannten Werte gehen mit in die Anfrage, damit die Schaetzung zu diesem
/// Lebensmittel passt und nicht zu einem gleichnamigen anderen.
func estimateMicronutrients(
    name: String,
    caloriesPer100g: Double,
    proteinPer100g: Double,
    carbsPer100g: Double,
    fatPer100g: Double,
    apiKey: String
) async throws -> Micronutrients {
    let number: [String: Any] = ["type": "number"]
    let body: [String: Any] = [
        "model": "claude-haiku-4-5-20251001",
        "max_tokens": 256,
        "system": """
            Du bist ein Ernaehrungsexperte. Zu einem Lebensmittel sind Kalorien und
            Makronaehrwerte bereits bekannt. Ergaenze die drei fehlenden Angaben je
            100 g: gesaettigte Fettsaeuren, Zucker und Salz.

            Regeln:
            - Die Schaetzung muss zu den bekannten Werten passen. Gesaettigte Fette
              koennen nicht groesser sein als das Gesamtfett, Zucker nicht groesser
              als die Kohlenhydrate.
            - 0 nur, wenn der Wert tatsaechlich null ist.
            - Salz in Gramm, nicht Natrium.
            """,
        "output_config": [
            "format": [
                "type": "json_schema",
                "schema": [
                    "type": "object",
                    "additionalProperties": false,
                    "properties": [
                        "saturatedFatPer100g": number,
                        "sugarPer100g": number,
                        "saltPer100g": number
                    ],
                    "required": ["saturatedFatPer100g", "sugarPer100g", "saltPer100g"]
                ]
            ]
        ],
        "messages": [[
            "role": "user",
            "content": """
                Lebensmittel: \(name)
                Bekannt je 100 g: \(bekannteWerte(
                    calories: caloriesPer100g, protein: proteinPer100g,
                    carbs: carbsPer100g, fat: fatPer100g))
                """
        ]]
    ]

    let text = try await sendAPIRequest(body: body, apiKey: apiKey)
    guard let data = extractJSON(from: text).data(using: .utf8) else {
        throw ClaudeServiceError.parseError("Ungültige Zeichenkodierung")
    }
    do {
        return try JSONDecoder().decode(Micronutrients.self, from: data)
    } catch {
        throw ClaudeServiceError.parseError(String(extractJSON(from: text).prefix(200)))
    }
}

// MARK: - HTTP-Request

private func sendAPIRequest(body: [String: Any], apiKey: String) async throws -> String {
    let url = URL(string: "https://api.anthropic.com/v1/messages")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json",  forHTTPHeaderField: "Content-Type")
    request.setValue(apiKey,              forHTTPHeaderField: "x-api-key")
    request.setValue("2023-06-01",        forHTTPHeaderField: "anthropic-version")
    request.timeoutInterval = 30

    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let http = response as? HTTPURLResponse else {
        throw ClaudeServiceError.networkError(URLError(.badServerResponse))
    }

    switch http.statusCode {
    case 200:
        break
    case 429:
        throw ClaudeServiceError.rateLimited
    default:
        let body = String(data: data, encoding: .utf8) ?? ""
        throw ClaudeServiceError.invalidResponse(http.statusCode, body)
    }

    guard let json    = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let content = json["content"] as? [[String: Any]],
          let first   = content.first,
          let text    = first["text"] as? String else {
        throw ClaudeServiceError.parseError("Unerwartetes API-Antwortformat")
    }

    return text
}

// MARK: - Response-Parsing

/// Liest die Liste aus `{"items": [...]}`. Ein blosses Objekt bleibt lesbar,
/// falls das Modell das Format nicht einhaelt (Issue #73).
func parseAIResponses(_ text: String) throws -> [AIFoodEstimate] {
    let jsonString = extractJSON(from: text)
    guard let data = jsonString.data(using: .utf8) else {
        throw ClaudeServiceError.parseError("Ungültige Zeichenkodierung")
    }

    struct Wrapper: Decodable { let items: [AIFoodEstimate] }
    if let wrapper = try? JSONDecoder().decode(Wrapper.self, from: data), !wrapper.items.isEmpty {
        return wrapper.items
    }
    return [try parseAIResponse(text)]
}

private func parseAIResponse(_ text: String) throws -> AIFoodEstimate {
    let jsonString = extractJSON(from: text)

    guard let jsonData = jsonString.data(using: .utf8) else {
        throw ClaudeServiceError.parseError("Ungültige Zeichenkodierung")
    }

    do {
        return try JSONDecoder().decode(AIFoodEstimate.self, from: jsonData)
    } catch let err as DecodingError {
        let detail: String
        switch err {
        case .keyNotFound(let key, _):
            detail = "Fehlendes Feld '\(key.stringValue)' — \(jsonString.prefix(200))"
        case .typeMismatch(_, let ctx):
            detail = "Typfehler bei '\(ctx.codingPath.map(\.stringValue).joined(separator: "."))'"
        default:
            detail = "\(jsonString.prefix(300))"
        }
        throw ClaudeServiceError.parseError(detail)
    }
}

private func extractJSON(from text: String) -> String {
    let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if t.hasPrefix("```") {
        let lines = t.components(separatedBy: "\n")
        return lines.dropFirst().dropLast().joined(separator: "\n")
    }
    if let start = t.firstIndex(of: "{"), let end = t.lastIndex(of: "}") {
        return String(t[start...end])
    }
    return t
}

// MARK: - Antwortschema (identisch mit ClaudeAPIService.estimateSchema)

/// Als Funktion statt als globale Konstante: ein `[String: Any]` auf Dateiebene
/// ist nicht `Sendable` und damit unter strikter Nebenlaeufigkeit ein Fehler.
private func estimateSchema() -> [String: Any] {
    let number: [String: Any] = ["type": "number"]
    return [
        "type": "object",
        "additionalProperties": false,
        "properties": [
            "name": ["type": "string"],
            "confidence": ["type": "string", "enum": ["high", "medium", "low"]],
            "estimatedWeightGrams": number,
            "caloriesPer100g": number,
            "proteinPer100g": number,
            "carbsPer100g": number,
            "fatPer100g": number,
            "fiberPer100g": number,
            "sugarPer100g": number,
            "saturatedFatPer100g": number,
            "saltPer100g": number,
            "totalCalories": number,
            "components": [
                "type": "array",
                "items": [
                    "type": "object",
                    "additionalProperties": false,
                    "properties": [
                        "name": ["type": "string"],
                        "estimatedGrams": number
                    ],
                    "required": ["name", "estimatedGrams"]
                ]
            ]
        ],
        "required": [
            "name", "confidence", "estimatedWeightGrams", "caloriesPer100g",
            "proteinPer100g", "carbsPer100g", "fatPer100g", "fiberPer100g",
            "sugarPer100g", "saturatedFatPer100g", "saltPer100g",
            "totalCalories", "components"
        ]
    ]
}

// MARK: - System-Prompt (identisch mit ClaudeAPIService.buildTextRequestBody)

private let claudeSystemPrompt = """
Du bist ein Ernaehrungsexperte. Schaetze die Naehrwerte fuer das Beschriebene.

Antworte AUSSCHLIESSLICH mit einem JSON-Objekt der Form {"items": [ ... ]}.
Jedes Element hat alle folgenden Felder:
{
  "name": "Kurze Beschreibung der Speise auf Deutsch",
  "confidence": "high",
  "estimatedWeightGrams": 300,
  "caloriesPer100g": 150,
  "proteinPer100g": 8.0,
  "carbsPer100g": 20.0,
  "fatPer100g": 5.0,
  "fiberPer100g": 2.0,
  "sugarPer100g": 3.0,
  "saturatedFatPer100g": 1.5,
  "saltPer100g": 0.5,
  "totalCalories": 450,
  "components": []
}

Regeln:
- MEHRERE Speisen ergeben MEHRERE Elemente: "Ruehrei mit Speck und ein Kaffee"
  sind drei Elemente.
- EIN Gericht bleibt EIN Element, auch wenn die Zutaten genannt werden:
  "Lasagne", "Salat mit Huehnchen und Dressing", "Brot mit Butter" sind je eines.
- Getraenke sind eigene Elemente, ausser sie gehoeren zum Gericht (Suppe).
- confidence: "high" bei bekannten Gerichten, "medium" bei unklarer Zubereitung, "low" bei sehr unklaren Angaben
- estimatedWeightGrams: typische Portionsgroesse wenn keine Menge genannt
- totalCalories = caloriesPer100g * estimatedWeightGrams / 100
- Alle numerischen Felder muessen Zahlen sein (kein null)
- sugarPer100g, saturatedFatPer100g und saltPer100g gehoeren zu jeder
  Schaetzung. Schaetze sie wie die uebrigen Naehrwerte und setze 0 nur, wenn der
  Wert tatsaechlich null ist (etwa Salz in Mineralwasser). Sie werden fuer die
  Naehrstoff-Ampel gebraucht; eine ausgelassene Angabe liest sich dort als
  bester Fall.
- Kein Markdown, keine Erklaerung — NUR das JSON-Objekt
"""
