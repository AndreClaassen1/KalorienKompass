//
//  ClaudeAPIService.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 05.02.26.
//

import Foundation
import ImageIO
import os
#if canImport(UIKit)
import UIKit
#endif


/// HTTP-Client fuer die Anthropic Claude Messages API mit Vision
actor ClaudeAPIService {
    static let shared = ClaudeAPIService()

    private let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let apiVersion = "2023-06-01"
    private let defaultModel = "claude-haiku-4-5-20251001"
    /// Obergrenze der Antwortlaenge. Eine Position braucht rund 120 Tokens; mit den
    /// vorherigen 1024 riss die Antwort ab etwa sechs Positionen mitten im JSON ab
    /// und war nicht mehr lesbar (#88). Das Limit kostet nichts, solange es nicht
    /// ausgeschoepft wird — abgerechnet wird, was tatsaechlich zurueckkommt.
    private let maxResponseTokens = 4096

    /// Maximale Bildgroesse (laengste Seite) fuer die API
    private let maxImageDimension: CGFloat = 1568
    /// JPEG-Kompressionsqualitaet
    private let jpegQuality: CGFloat = 0.7

    // MARK: - Fehlertypen

    enum APIError: LocalizedError {
        case noAPIKey
        case networkError(Error)
        case invalidResponse(Int)
        case rateLimited
        case parseError(String)
        case imageProcessingFailed
        /// Die Antwort endete am Token-Limit, das JSON ist unvollstaendig (#88).
        case responseTruncated

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                String(localized: "ai_error_no_key")
            case .networkError(let error):
                String(localized: "ai_error_network") + " (\(error.localizedDescription))"
            case .invalidResponse(let code):
                "API-Fehler (HTTP \(code))"
            case .rateLimited:
                "Rate Limit erreicht. Bitte warte einen Moment."
            case .parseError(let detail):
                String(localized: "ai_error_parse") + " (\(detail))"
            case .imageProcessingFailed:
                "Bild konnte nicht verarbeitet werden."
            case .responseTruncated:
                String(localized: "ai_error_truncated")
            }
        }
    }

    // MARK: - Oeffentliche Methode

    /// Analysiert ein Mahlzeiten-Foto und gibt geschaetzte Naehrwerte zurueck
    #if canImport(UIKit) && !os(watchOS)
    func analyzeFood(image: UIImage, userHint: String? = nil) async throws -> AIFoodEstimate {
        guard let apiKey = resolveAPIKey(), !apiKey.isEmpty else {
            throw APIError.noAPIKey
        }

        let base64Image = try prepareImage(image)
        let requestBody = buildRequestBody(base64Image: base64Image, userHint: userHint)
        let responseText = try await sendRequest(body: requestBody, apiKey: apiKey)
        return try parseResponse(responseText)
    }
    #endif

    /// Schätzt Nährwerte anhand einer Freitextbeschreibung
    /// Schaetzt alle Speisen einer Eingabe.
    ///
    /// „Ruehrei mit Speck und ein Kaffee" ergibt drei Ergebnisse, „Lasagne" eines
    /// (Issue #73). Wer beim Sprechen mehrere Dinge nennt, bekam frueher einen
    /// verschmolzenen Eintrag, aus dem sich nichts mehr einzeln korrigieren liess.
    func estimateMeal(description: String) async throws -> [AIFoodEstimate] {
        guard let apiKey = resolveAPIKey(), !apiKey.isEmpty else {
            throw APIError.noAPIKey
        }
        let requestBody = buildTextRequestBody(description: description)
        let responseText = try await sendRequest(body: requestBody, apiKey: apiKey)
        return try parseEstimates(responseText)
    }

    /// Einzel-Variante fuer die Wege mit Vorschau (Kamera, KI-Schnelleingabe,
    /// Watch-Sheet): dort wird genau ein Ergebnis angezeigt und angepasst.
    func estimateNutrients(description: String) async throws -> AIFoodEstimate {
        guard let first = try await estimateMeal(description: description).first else {
            throw APIError.parseError("Keine Speise erkannt")
        }
        return first
    }

    /// Analysiert ein Mahlzeiten-Foto aus Bilddaten (plattformuebergreifend, nutzt CoreGraphics)
    func analyzeFood(imageData: Data, userHint: String? = nil) async throws -> AIFoodEstimate {
        guard let apiKey = resolveAPIKey(), !apiKey.isEmpty else {
            throw APIError.noAPIKey
        }

        let base64Image = try prepareImageData(imageData)
        let requestBody = buildRequestBody(base64Image: base64Image, userHint: userHint)
        let responseText = try await sendRequest(body: requestBody, apiKey: apiKey)
        return try parseResponse(responseText)
    }

    // MARK: - API-Key-Aufloesung

    /// Liest den API-Key: zuerst aus Bundle (xcconfig), dann aus Keychain (manuell eingegeben)
    nonisolated private func resolveAPIKey() -> String? {
        // 1. Eingebetteter Key aus Secrets.xcconfig (via Info.plist)
        if let bundleKey = Bundle.main.infoDictionary?["ClaudeAPIKey"] as? String,
           !bundleKey.isEmpty {
            return bundleKey
        }
        // 2. Manuell eingegebener Key aus dem Keychain
        return KeychainHelper.loadAPIKey()
    }

    // MARK: - Bild-Vorbereitung

    /// Bereitet Bilddaten vor: Resize via CoreGraphics + JPEG-Kompression (plattformuebergreifend)
    private func prepareImageData(_ data: Data) throws -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw APIError.imageProcessingFailed
        }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let longestSide = max(width, height)

        let finalImage: CGImage
        if longestSide > maxImageDimension {
            let scale = maxImageDimension / longestSide
            let newWidth = Int(width * scale)
            let newHeight = Int(height * scale)

            guard let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(
                      data: nil,
                      width: newWidth,
                      height: newHeight,
                      bitsPerComponent: 8,
                      bytesPerRow: 0,
                      space: colorSpace,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                throw APIError.imageProcessingFailed
            }
            context.interpolationQuality = .high
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
            guard let resized = context.makeImage() else {
                throw APIError.imageProcessingFailed
            }
            finalImage = resized
        } else {
            finalImage = cgImage
        }

        let jpegData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            jpegData as CFMutableData,
            "public.jpeg" as CFString,
            1,
            nil
        ) else {
            throw APIError.imageProcessingFailed
        }
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: jpegQuality
        ]
        CGImageDestinationAddImage(destination, finalImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw APIError.imageProcessingFailed
        }

        return (jpegData as Data).base64EncodedString()
    }

    #if canImport(UIKit) && !os(watchOS)
    private func prepareImage(_ image: UIImage) throws -> String {
        let resized = resizeImage(image, maxDimension: maxImageDimension)
        guard let jpegData = resized.jpegData(compressionQuality: jpegQuality) else {
            throw APIError.imageProcessingFailed
        }
        return jpegData.base64EncodedString()
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longestSide = max(size.width, size.height)

        guard longestSide > maxDimension else { return image }

        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    #endif

    // MARK: - API-Request

    // MARK: - Antwortschema

    /// JSON-Schema einer einzelnen Schaetzung.
    ///
    /// Der Grund fuer das Schema sind die drei Mikrowerte: gesaettigte Fette,
    /// Zucker und Salz standen frueher nur im Prompt und fehlten in etwa jeder
    /// zwanzigsten Antwort. Der Decoder machte aus einem fehlenden Feld still
    /// eine 0, und die Naehrstoff-Ampel bewertete das als besten Fall — ein
    /// Fruchtaufstrich ohne Zucker, Chips ohne Salz (Issue #95). Als `required`
    /// im Schema muss das Modell sie liefern.
    ///
    /// `additionalProperties: false` ist fuer strukturierte Ausgaben Pflicht,
    /// Zahlenbereiche (`minimum`, `maximum`) unterstuetzt das Schema dagegen
    /// nicht — die Plausibilitaet bleibt Sache des Prompts.
    private var estimateSchema: [String: Any] {
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

    /// Erzwingt die Antwortform. Ohne das bleibt es bei der Bitte im Prompt,
    /// und die wird nicht immer erfuellt.
    private func outputConfig(schema: [String: Any]) -> [String: Any] {
        ["format": ["type": "json_schema", "schema": schema]]
    }

    private func buildTextRequestBody(description: String) -> [String: Any] {
        let systemPrompt = """
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
          sind drei Elemente. Sie werden einzeln gebucht und einzeln korrigiert.
        - EIN Gericht bleibt EIN Element, auch wenn die Zutaten genannt werden:
          "Lasagne", "Salat mit Huehnchen und Dressing", "Brot mit Butter" sind je eines.
          Die Trennlinie ist "mehrere Speisen" gegen "ein Gericht aus Zutaten".
        - Getraenke sind eigene Elemente, ausser sie gehoeren zum Gericht (Suppe).
        - confidence: "high" bei bekannten Gerichten, "medium" bei unklarer Zubereitung, "low" bei sehr unklaren Angaben
        - estimatedWeightGrams: typische Portionsgroesse wenn keine Menge genannt
        - totalCalories = caloriesPer100g * estimatedWeightGrams / 100
        - Alle numerischen Felder muessen Zahlen sein (kein null)
        - sugarPer100g, saturatedFatPer100g und saltPer100g gehoeren zu jeder
          Schaetzung. Schaetze sie wie die uebrigen Naehrwerte und setze 0 nur,
          wenn der Wert tatsaechlich null ist (etwa Salz in Mineralwasser).
          Sie werden fuer die Naehrstoff-Ampel gebraucht; eine ausgelassene
          Angabe liest sich dort als bester Fall.
        - Kein Markdown, keine Erklaerung — NUR das JSON-Objekt
        """
        return [
            "model": defaultModel,
            "max_tokens": maxResponseTokens,
            "system": systemPrompt,
            "output_config": outputConfig(schema: [
                "type": "object",
                "additionalProperties": false,
                "properties": ["items": ["type": "array", "items": estimateSchema]],
                "required": ["items"]
            ]),
            "messages": [[
                "role": "user",
                "content": "Lebensmittel: \(description)"
            ]]
        ]
    }


    private func buildRequestBody(base64Image: String, userHint: String? = nil) -> [String: Any] {
        let systemPrompt = """
        Du bist ein Ernaehrungsexperte. Analysiere dieses Foto einer Mahlzeit.

        Antworte AUSSCHLIESSLICH mit einem JSON-Objekt im folgenden Format:

        {
          "name": "Kurze Beschreibung der Mahlzeit auf Deutsch",
          "confidence": "high" | "medium" | "low",
          "estimatedWeightGrams": <geschaetztes Gesamtgewicht in Gramm>,
          "caloriesPer100g": <Kalorien pro 100g>,
          "proteinPer100g": <Protein in Gramm pro 100g>,
          "carbsPer100g": <Kohlenhydrate in Gramm pro 100g>,
          "fatPer100g": <Fett in Gramm pro 100g>,
          "fiberPer100g": <Ballaststoffe in Gramm pro 100g>,
          "sugarPer100g": <Zucker in Gramm pro 100g>,
          "saturatedFatPer100g": <gesaettigte Fettsaeuren in Gramm pro 100g>,
          "saltPer100g": <Salz in Gramm pro 100g>,
          "totalCalories": <Gesamtkalorien der Portion>,
          "components": [
            {"name": "Zutat 1", "estimatedGrams": <Gramm>},
            {"name": "Zutat 2", "estimatedGrams": <Gramm>}
          ]
        }

        Regeln:
        - Schaetze die Portionsgroesse anhand visueller Hinweise (Teller, Besteck, Hand)
        - Gib realistische Naehrwerte an, basierend auf gaengigen Rezepturen
        - Bei Unsicherheit: lieber konservativ schaetzen (etwas mehr Kalorien)
        - "confidence": "high" bei eindeutigen Gerichten, "low" bei schlechter Bildqualitaet
        - sugarPer100g, saturatedFatPer100g und saltPer100g gehoeren zu jeder
          Schaetzung. Schaetze sie wie die uebrigen Naehrwerte und setze 0 nur,
          wenn der Wert tatsaechlich null ist. Sie werden fuer die
          Naehrstoff-Ampel gebraucht; eine ausgelassene Angabe liest sich dort
          als bester Fall.
        - Kein Markdown, kein erklaerrender Text — NUR das JSON-Objekt
        """

        var contentArray: [[String: Any]] = [
            [
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": base64Image
                ]
            ],
            [
                "type": "text",
                "text": systemPrompt
            ]
        ]

        if let hint = userHint, !hint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let hintText = """
            Zusaetzlicher Hinweis vom Benutzer: "\(hint)"
            Beruecksichtige diesen Hinweis bei deiner Analyse. Falls der Benutzer \
            eine Grammzahl oder Milliliter-Angabe nennt, verwende diese als \
            geschaetztes Portionsgewicht (estimatedWeightGrams). Falls der Benutzer \
            den Namen des Gerichts nennt, verwende diesen als Grundlage fuer die \
            Naehrwertberechnung.
            """
            contentArray.append([
                "type": "text",
                "text": hintText
            ])
        }

        return [
            "model": defaultModel,
            "max_tokens": maxResponseTokens,
            "output_config": outputConfig(schema: estimateSchema),
            "messages": [
                [
                    "role": "user",
                    "content": contentArray
                ]
            ]
        ]
    }

    private func sendRequest(body: [String: Any], apiKey: String) async throws -> String {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30

        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 429:
            throw APIError.rateLimited
        default:
            throw APIError.invalidResponse(httpResponse.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw APIError.parseError("Unerwartetes API-Antwortformat")
        }

        // Am Limit abgebrochen: das JSON endet mitten im Satz. Ohne diese Pruefung
        // scheitert erst der Decoder, und der kann nicht sagen, woran es lag (#88).
        if json["stop_reason"] as? String == "max_tokens" {
            Logger(subsystem: "com.andre.claassen.KalorienKompass", category: "ClaudeAPI")
                .error("Antwort am Token-Limit abgebrochen (\(self.maxResponseTokens) Tokens)")
            throw APIError.responseTruncated
        }

        return text
    }

    // MARK: - Response-Parsing

    /// Liest die Liste aus `{"items": [...]}`. Aeltere Antworten mit einem
    /// blossen Objekt bleiben lesbar — Sprachmodelle halten sich nicht immer ans
    /// Format, und ein einzelnes Ergebnis ist besser als ein Fehler.
    nonisolated func parseEstimates(_ text: String) throws -> [AIFoodEstimate] {
        let jsonString = extractJSON(from: text)
        guard let data = jsonString.data(using: .utf8) else {
            throw APIError.parseError("Ungueltige Zeichenkodierung")
        }

        struct Wrapper: Decodable { let items: [AIFoodEstimate] }
        if let wrapper = try? JSONDecoder().decode(Wrapper.self, from: data), !wrapper.items.isEmpty {
            return wrapper.items
        }
        return [try parseResponse(text)]
    }

    nonisolated func parseResponse(_ text: String) throws -> AIFoodEstimate {
        let apiLogger = Logger(subsystem: "com.andre.claassen.KalorienKompass", category: "ClaudeAPI")
        apiLogger.debug("Claude raw response: \(text, privacy: .public)")

        // JSON aus moeglichen Markdown-Code-Bloecken extrahieren
        let jsonString = extractJSON(from: text)
        apiLogger.debug("Extracted JSON: \(jsonString, privacy: .public)")

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw APIError.parseError("Ungueltige Zeichenkodierung")
        }

        do {
            return try JSONDecoder().decode(AIFoodEstimate.self, from: jsonData)
        } catch let decodeError as DecodingError {
            // Die Rohantwort gehoert ins Log, nicht auf den Bildschirm: sie fuellte
            // dort den halben Screen und half niemandem weiter (#88).
            apiLogger.error("Dekodierung fehlgeschlagen: \(String(describing: decodeError), privacy: .public) — Antwort: \(jsonString, privacy: .public)")
            let detail: String
            switch decodeError {
            case .keyNotFound(let key, _):
                detail = "fehlendes Feld '\(key.stringValue)'"
            case .typeMismatch(let type, let context):
                detail = "Typfehler (\(type)) bei '\(context.codingPath.map(\.stringValue).joined(separator: "."))'"
            case .valueNotFound(_, let context):
                detail = "leerer Wert bei '\(context.codingPath.map(\.stringValue).joined(separator: "."))'"
            default:
                detail = "unvollstaendige Antwort"
            }
            throw APIError.parseError(detail)
        } catch {
            apiLogger.error("Dekodierung fehlgeschlagen: \(error.localizedDescription, privacy: .public) — Antwort: \(jsonString, privacy: .public)")
            throw APIError.parseError("unlesbare Antwort")
        }
    }

    /// Extrahiert JSON aus einem String (entfernt ggf. Markdown-Code-Bloecke)
    private nonisolated func extractJSON(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Versuche ```json ... ``` zu entfernen
        if trimmed.hasPrefix("```") {
            let lines = trimmed.components(separatedBy: "\n")
            let filtered = lines.dropFirst().dropLast()
            return filtered.joined(separator: "\n")
        }

        // Versuche erstes { bis letztes } zu finden
        if let start = trimmed.firstIndex(of: "{"),
           let end = trimmed.lastIndex(of: "}") {
            return String(trimmed[start...end])
        }

        return trimmed
    }
}
