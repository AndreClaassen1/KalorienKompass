# Anforderung: KI-Foto-Erkennung fuer Mahlzeiten

## 1. Uebersicht

KalorienKompass soll dem Benutzer ermoeglichen, eine Mahlzeit zu fotografieren und per KI die Naehrwerte schaetzen zu lassen. Aus dem Foto wird ein Schnelleintrag erzeugt, der vor dem Speichern bestaetigt und angepasst werden kann.

**Kernfunktionen:**

- **Foto aufnehmen oder aus Galerie waehlen** — direkt aus dem Tagebuch heraus
- **KI-Analyse via Claude API** — Erkennung der Mahlzeit, Schaetzung von Kalorien und Makros
- **Bestaetigungs-Screen** — Ergebnis pruefen, Name und Werte anpassen, dann als Eintrag speichern
- **Schnelleintrag erzeugen** — Kein Produkt-Lookup, sondern direkter Eintrag mit geschaetzten Werten

**UI-Referenz:** Yazio "KI Kamera" — Vollbild-Kamera mit Scan-Rahmen, danach Bestaetigungsscreen mit Foto, Beschreibung und Naehrwert-Zusammenfassung.

---

## 2. Bestehende Infrastruktur

### Bereits vorhanden

| Komponente | Status | Details |
|-----------|--------|---------|
| QuickEntryView | Vorhanden | Manuelle Eingabe: Name, Kalorien, Protein, Carbs, Fat, Fiber |
| FoodItem-Model | Vorhanden | `isQuickEntry`-Flag fuer Einmal-Eintraege |
| DiaryEntry-Model | Vorhanden | Verknuepfung FoodItem + Datum + MealType + Menge |
| Kamera-Berechtigung | Vorhanden | `NSCameraUsageDescription` fuer Barcode-Scanner |
| MealSectionView | Vorhanden | Pro-Mahlzeit-Buttons (`plus.circle.fill`) |
| Barcode-Scanner | Vorhanden | BarcodeScannerView mit AVFoundation-Kamera |

### Fehlt

| Komponente | Beschreibung |
|-----------|-------------|
| Claude API Client | HTTP-Client fuer Anthropic Messages API mit Vision |
| API-Key-Verwaltung | Sicherer Storage fuer den Anthropic API Key |
| Kamera-View fuer Mahlzeiten | Eigene Kamera-Ansicht (Vollbild, kein Barcode-Modus) |
| Bestaetigungs-Screen | Ergebnis pruefen und anpassen vor dem Speichern |
| KI-Button im Tagebuch | Button neben dem Plus-Button pro Mahlzeit |

---

## 3. Claude API Integration

### 3.1 API-Endpunkt

Anthropic Messages API mit Vision-Support:

```
POST https://api.anthropic.com/v1/messages
```

### 3.2 Empfohlenes Modell

**Claude Haiku 3.5** (`claude-haiku-4-5-20251001`) — bestes Preis-Leistungs-Verhaeltnis fuer diese Aufgabe. Falls die Genauigkeit nicht ausreicht, kann auf **Claude Sonnet 4** (`claude-sonnet-4-5-20250929`) gewechselt werden.

### 3.3 Request-Format

```json
{
  "model": "claude-haiku-4-5-20251001",
  "max_tokens": 1024,
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "image",
          "source": {
            "type": "base64",
            "media_type": "image/jpeg",
            "data": "<base64-kodiertes-bild>"
          }
        },
        {
          "type": "text",
          "text": "<System-Prompt: siehe Abschnitt 3.4>"
        }
      ]
    }
  ]
}
```

### 3.4 System-Prompt (Ernaehrungsanalyse)

```
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
- Kein Markdown, kein erklaerrender Text — NUR das JSON-Objekt
```

### 3.5 Response-Parsing

Die App erwartet exakt das JSON-Format aus dem Prompt. Parsing:

1. Extrahiere JSON aus der Claude-Antwort (ggf. Markdown-Code-Bloecke entfernen)
2. Dekodiere mit `JSONDecoder` in ein `AIFoodEstimate`-Struct
3. Bei Parse-Fehler: Fehlermeldung an den Benutzer, Option zum erneuten Versuch

### 3.6 Bild-Vorbereitung

Vor dem API-Call wird das Foto optimiert:

- **Maximale Aufloesung:** 1568px auf der laengsten Seite (Claude-Limit)
- **Format:** JPEG mit Kompression 0.7 (guter Kompromiss aus Qualitaet und Groesse)
- **Orientierung:** EXIF-Rotation anwenden vor dem Encoding
- **Ergebnis:** ~200-400 KB pro Bild, ~1.300-1.600 Input-Tokens

---

## 4. Kostenabschaetzung

### 4.1 Token-Berechnung pro Request

| Komponente | Tokens |
|-----------|--------|
| Bild (Smartphone-Foto, resized) | ~1.500 |
| Text-Prompt | ~200 |
| **Input gesamt** | **~1.700** |
| JSON-Antwort | ~300-400 |
| **Output gesamt** | **~350** |

### 4.2 Kosten pro Request

| Modell | Input-Kosten | Output-Kosten | **Gesamt/Request** |
|--------|-------------|--------------|-------------------|
| Haiku 3.5 | $0.0014 | $0.0014 | **~$0.003** |
| Sonnet 4 | $0.0051 | $0.0053 | **~$0.010** |
| Opus 4.5 | $0.0255 | $0.0263 | **~$0.052** |

### 4.3 Monatskosten bei 3-4 Bildern pro Tag

| Modell | 3 Bilder/Tag | 4 Bilder/Tag | **pro Monat (30 Tage)** |
|--------|-------------|-------------|------------------------|
| **Haiku 3.5** | $0.009/Tag | $0.012/Tag | **$0.27 – $0.36** |
| Sonnet 4 | $0.030/Tag | $0.040/Tag | $0.90 – $1.20 |
| Opus 4.5 | $0.156/Tag | $0.208/Tag | $4.68 – $6.24 |

**Empfehlung:** Haiku 3.5 mit **unter 40 Cent pro Monat** — vernachlaessigbar. Selbst bei taeglicher Nutzung kostet das Feature weniger als ein halber Cent pro Foto.

### 4.4 Zusaetzliche Optimierungen

- **Prompt Caching:** Der System-Prompt kann gecacht werden (bis zu 90% Einsparung auf den Text-Anteil)
- **Bild-Kompression:** JPEG-Qualitaet 0.7 reduziert Tokens ohne sichtbaren Qualitaetsverlust
- **Kein Batch-API noetig:** Interaktive Nutzung erfordert Echtzeit-Antworten (~2-3 Sekunden)

---

## 5. Datenmodell

### 5.1 Neues Struct: AIFoodEstimate

Nur fuer die Zwischenspeicherung des API-Ergebnisses (kein SwiftData):

```
struct AIFoodEstimate: Codable {
    let name: String
    let confidence: String           // "high", "medium", "low"
    let estimatedWeightGrams: Double
    let caloriesPer100g: Double
    let proteinPer100g: Double
    let carbsPer100g: Double
    let fatPer100g: Double
    let fiberPer100g: Double
    let sugarPer100g: Double
    let saturatedFatPer100g: Double
    let saltPer100g: Double
    let totalCalories: Double
    let components: [FoodComponent]
}

struct FoodComponent: Codable {
    let name: String
    let estimatedGrams: Double
}
```

### 5.2 Eintrag-Erzeugung

Aus dem `AIFoodEstimate` wird beim Bestaetigen:

1. Ein **FoodItem** erstellt mit `isQuickEntry = true` und allen Naehrwerten pro 100g
2. Ein **DiaryEntry** erstellt mit `amountGrams = estimatedWeightGrams` und dem gewaehlten MealType
3. Beide in SwiftData gespeichert

Die Naehrwerte werden **pro 100g** gespeichert (wie bei allen FoodItems), die geschaetzte Portionsgroesse wird als `amountGrams` im DiaryEntry erfasst. So kann der Benutzer die Menge nachtraeglich anpassen.

### 5.3 API-Key-Speicherung

Der Anthropic API Key wird im **iOS Keychain** gespeichert:

- Eingabe: In den Einstellungen (neue Sektion "KI-Einstellungen")
- Speicherung: `Security.framework` (SecItemAdd/SecItemCopyMatching)
- Anzeige: Maskiert (nur letzte 4 Zeichen sichtbar)
- Loeschbar: Button zum Entfernen des Keys

---

## 6. UI-Design

### 6.1 KI-Button im Tagebuch

Neben dem bestehenden `plus.circle.fill`-Button in der MealSectionView wird ein KI-Kamera-Button ergaenzt:

```
┌──────────────────────────────────────────────┐
│  🍳 Fruehstueck              [📷] [＋]      │
├──────────────────────────────────────────────┤
│  Haferflocken mit Milch       320 kcal       │
│  Apfel                         52 kcal       │
├──────────────────────────────────────────────┤
│                            Gesamt: 372 kcal  │
└──────────────────────────────────────────────┘
```

- **[📷]** = `camera.fill` SF Symbol als Button → oeffnet KI-Kamera
- **[＋]** = bestehender `plus.circle.fill` → oeffnet Lebensmittel-Suche
- Reihenfolge: Kamera links, Plus rechts (KI ist der schnellere Weg)
- Nur sichtbar auf iOS (macOS hat keine Kamera fuer Mahlzeiten-Fotos)

### 6.2 KI-Kamera-Screen (Vollbild)

Aehnlich der Yazio-Referenz: Vollbild-Kamera mit Scan-Rahmen.

```
┌──────────────────────────────────────────────┐
│  [←]        KI-Erkennung              (?)    │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │                                        │  │
│  │                                        │  │
│  │          (Kamera-Vorschau)             │  │
│  │                                        │  │
│  │       ┌─────────────────────┐          │  │
│  │       │                     │          │  │
│  │       │  (Scan-Rahmen)      │          │  │
│  │       │                     │          │  │
│  │       └─────────────────────┘          │  │
│  │                                        │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  Fotografiere deine Mahlzeit.                │
│  Achte auf gute Beleuchtung.                 │
│                                              │
│       [🖼]      (◉)       [⚡]              │
│      Fotos    Aufnahme    Blitz              │
│                                              │
└──────────────────────────────────────────────┘
```

**Elemente:**

- **Zurueck-Button** (←) oben links
- **Titel:** "KI-Erkennung"
- **Kamera-Vorschau:** Vollflaeche
- **Scan-Rahmen:** Abgerundetes Rechteck als visueller Hinweis (rein dekorativ)
- **Hinweistext:** "Fotografiere deine Mahlzeit. Achte auf gute Beleuchtung."
- **Fotos-Button:** Bild aus der Galerie waehlen (PhotosPicker)
- **Aufnahme-Button:** Grosser runder Button zum Fotografieren
- **Blitz-Button:** Toggle Kamera-Blitz (aus/ein/auto)

**Plattform:** Nur iOS (`#if os(iOS)`). Auf macOS entfaellt das Feature (kein Kamera-Button in MealSectionView).

### 6.3 Lade-Zustand (Analyse laeuft)

Nach der Aufnahme: Lade-Animation waehrend der API-Anfrage.

```
┌──────────────────────────────────────────────┐
│                                              │
│         ┌─────────────────────┐              │
│         │                     │              │
│         │   (aufgenommenes    │              │
│         │      Foto)          │              │
│         │                     │              │
│         └─────────────────────┘              │
│                                              │
│              ⏳ Analysiere...                │
│                                              │
│        Deine Mahlzeit wird erkannt.          │
│                                              │
└──────────────────────────────────────────────┘
```

- Foto wird angezeigt (verkleinert)
- ProgressView mit Text "Analysiere..."
- Typische Dauer: 2-4 Sekunden (Haiku)
- Abbrechen-Button verfuegbar

### 6.4 Bestaetigungs-Screen (Ergebnis)

Nach erfolgreicher Analyse: Ergebnis pruefen und bestaetigen.

```
┌──────────────────────────────────────────────┐
│  [←]       Mahlzeit erkannt                  │
│                                              │
│         ┌─────────────────────┐              │
│         │                     │              │
│         │   (aufgenommenes    │              │
│         │      Foto)          │              │
│         │                     │              │
│         └─────────────────────┘              │
│                                              │
│  Currywurst mit Pommes Frites                │  ← Editierbarer Name
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  542 kcal    54,0 g   39,0 g  19,0 g│    │
│  │  Kalorien    Kohlenh. Eiweiss Fett  │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  Geschaetzte Portion: 350 g                  │  ← Editierbar
│  Konfidenz: Hoch ●●●                        │
│                                              │
│  Bestandteile:                               │
│    Currywurst         ~150 g                 │
│    Pommes Frites      ~180 g                 │
│    Currysosse          ~20 g                 │
│                                              │
│         [Details anpassen]                   │  ← Oeffnet Edit-Modus
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │       Bestaetigen und tracken        │    │
│  └──────────────────────────────────────┘    │
│                                              │
│         [Erneut fotografieren]               │
│                                              │
└──────────────────────────────────────────────┘
```

**Elemente:**

- **Foto:** Verkleinertes Aufnahme-Bild (abgerundete Ecken, Schatten)
- **Name:** Grosse Schrift, editierbar (TextField)
- **Naehrwert-Karte:** 4 Werte in einer Reihe (Kalorien, Kohlenhydrate, Eiweiss, Fett) — zeigt **Gesamtwerte der Portion** (nicht pro 100g)
- **Portionsgroesse:** Editierbar (Stepper oder TextField)
- **Konfidenz-Anzeige:** 3 Punkte (●●● hoch, ●●○ mittel, ●○○ niedrig)
- **Bestandteile:** Liste der erkannten Zutaten mit geschaetzten Gramm
- **"Details anpassen":** Oeffnet erweiterte Bearbeitung (alle Naehrwerte editierbar)
- **"Bestaetigen und tracken":** Primaer-Button, erstellt den Eintrag
- **"Erneut fotografieren":** Zurueck zur Kamera

### 6.5 Einstellungen — KI-Sektion

Neue Sektion in SettingsView:

```
┌──────────────────────────────────────────────┐
│  KI-Einstellungen                            │
├──────────────────────────────────────────────┤
│  API-Schluessel      [••••••••••7xKf]  [✕]   │  ← Maskiert + Loeschen-Button
│  Modell              [Haiku 3.5 ▾]           │  ← Picker: Haiku / Sonnet / Opus
│  API-Status          ● Verbunden             │  ← Gruen wenn Key gueltig
└──────────────────────────────────────────────┘
```

Wenn kein API Key gesetzt ist:

```
┌──────────────────────────────────────────────┐
│  KI-Einstellungen                            │
├──────────────────────────────────────────────┤
│  Die KI-Erkennung erfordert einen            │
│  Anthropic API-Schluessel.                   │
│                                              │
│  [API-Schluessel eingeben]                   │
│                                              │
│  Kosten: ca. 0,3 Cent pro Foto              │
│  (Haiku 3.5)                                 │
└──────────────────────────────────────────────┘
```

### 6.6 Fehlerbehandlung UI

| Situation | Anzeige |
|-----------|---------|
| Kein API Key | Alert: "Bitte hinterlege deinen API-Schluessel in den Einstellungen." |
| Netzwerkfehler | Alert: "Keine Internetverbindung. Versuche es spaeter erneut." |
| API-Fehler (Rate Limit, Auth) | Alert mit konkreter Fehlermeldung |
| Kein Essen erkannt | "Das Bild konnte nicht als Mahlzeit erkannt werden. Versuche es mit einem anderen Foto." |
| Parse-Fehler | "Die Analyse konnte nicht verarbeitet werden. Versuche es erneut." |

---

## 7. Architektur

### 7.1 Neue Dateien

| Datei | Pfad | Beschreibung |
|-------|------|-------------|
| AIFoodEstimate.swift | Shared/Model/ | Codable Struct fuer API-Antwort |
| ClaudeAPIService.swift | Shared/Services/ | HTTP-Client fuer Anthropic Messages API |
| KeychainHelper.swift | Shared/Services/ | Keychain-Wrapper fuer API-Key |
| AIFoodCameraView.swift | iOS/AICamera/ | Vollbild-Kamera fuer Mahlzeiten-Fotos |
| AIFoodResultView.swift | iOS/AICamera/ | Bestaetigungs-Screen mit Ergebnis |
| AIFoodViewModel.swift | Shared/ViewModel/ | Geschaeftslogik: Foto → API → Eintrag |

### 7.2 Aenderungen an bestehenden Dateien

| Datei | Aenderung |
|-------|----------|
| MealSectionView.swift | KI-Kamera-Button neben Plus-Button (`#if os(iOS)`) |
| DiaryListView.swift | Sheet fuer AIFoodCameraView + Callback-Handling |
| SettingsView.swift | Neue Sektion "KI-Einstellungen" |
| SettingsViewModel.swift | API-Key laden/speichern/validieren |
| Localizable.xcstrings | ~20 neue Keys |
| project.pbxproj | Neue Dateien registrieren |

### 7.3 Datenfluss

```
[MealSectionView]
    │  Tap auf Kamera-Button
    ▼
[AIFoodCameraView]  ←─── Foto aufnehmen / aus Galerie
    │  UIImage
    ▼
[AIFoodViewModel]
    │  1. Bild zu JPEG komprimieren (max 1568px, quality 0.7)
    │  2. Base64-kodieren
    │  3. API-Request an Claude senden
    │  4. JSON-Antwort parsen → AIFoodEstimate
    ▼
[AIFoodResultView]  ←─── Ergebnis anzeigen + editieren
    │  Benutzer bestaetigt
    ▼
[AIFoodViewModel]
    │  1. FoodItem erstellen (isQuickEntry = true)
    │  2. DiaryEntry erstellen (amountGrams = estimatedWeightGrams)
    │  3. In SwiftData speichern
    │  4. DayViewModel.loadDay() aufrufen
    ▼
[DiaryListView]  ←─── Eintrag erscheint in der Mahlzeit
```

### 7.4 ClaudeAPIService — Schnittstelle

```
actor ClaudeAPIService {
    static let shared = ClaudeAPIService()

    func analyzeFood(image: UIImage) async throws -> AIFoodEstimate

    enum APIError: LocalizedError {
        case noAPIKey
        case networkError(Error)
        case invalidResponse
        case rateLimited
        case parseError(String)
    }
}
```

- Actor-basiert (thread-safe, wie bestehende Services)
- Verwendet `URLSession` fuer HTTP
- API-Key aus Keychain gelesen
- Modell konfigurierbar (UserDefaults oder UserProfile)
- Timeout: 30 Sekunden

---

## 8. Sicherheit und Datenschutz

| Aspekt | Massnahme |
|--------|----------|
| API-Key | Im iOS Keychain gespeichert, nie im Klartext in UserDefaults |
| Bilder | Werden NICHT auf Servern gespeichert — nur einmalig an Claude gesendet |
| Datenuebertragung | HTTPS (TLS 1.3) an api.anthropic.com |
| Lokale Speicherung | Fotos werden nach der Analyse nicht dauerhaft gespeichert |
| Kosten-Transparenz | Benutzer sieht geschaetzte Kosten in den Einstellungen |

---

## 9. Lokalisierung

Neue Keys (DE / EN):

| Key | Deutsch | English |
|-----|---------|---------|
| `ai_camera_title` | KI-Erkennung | AI Recognition |
| `ai_camera_hint` | Fotografiere deine Mahlzeit. Achte auf gute Beleuchtung. | Take a photo of your meal. Ensure good lighting. |
| `ai_analyzing` | Analysiere... | Analyzing... |
| `ai_analyzing_hint` | Deine Mahlzeit wird erkannt. | Your meal is being recognized. |
| `ai_result_title` | Mahlzeit erkannt | Meal Recognized |
| `ai_confirm_button` | Bestaetigen und tracken | Confirm and track |
| `ai_retake_button` | Erneut fotografieren | Retake photo |
| `ai_adjust_details` | Details anpassen | Adjust details |
| `ai_estimated_portion` | Geschaetzte Portion | Estimated portion |
| `ai_confidence` | Konfidenz | Confidence |
| `ai_confidence_high` | Hoch | High |
| `ai_confidence_medium` | Mittel | Medium |
| `ai_confidence_low` | Niedrig | Low |
| `ai_components` | Bestandteile | Components |
| `ai_settings_title` | KI-Einstellungen | AI Settings |
| `ai_settings_api_key` | API-Schluessel | API Key |
| `ai_settings_model` | Modell | Model |
| `ai_settings_status` | API-Status | API Status |
| `ai_settings_connected` | Verbunden | Connected |
| `ai_settings_no_key` | Die KI-Erkennung erfordert einen Anthropic API-Schluessel. | AI recognition requires an Anthropic API key. |
| `ai_settings_enter_key` | API-Schluessel eingeben | Enter API key |
| `ai_settings_cost_hint` | Kosten: ca. 0,3 Cent pro Foto (Haiku 3.5) | Cost: approx. 0.3 cents per photo (Haiku 3.5) |
| `ai_error_no_key` | Bitte hinterlege deinen API-Schluessel in den Einstellungen. | Please enter your API key in Settings. |
| `ai_error_network` | Keine Internetverbindung. Versuche es spaeter erneut. | No internet connection. Please try again later. |
| `ai_error_not_food` | Das Bild konnte nicht als Mahlzeit erkannt werden. | The image could not be recognized as a meal. |
| `ai_error_parse` | Die Analyse konnte nicht verarbeitet werden. Versuche es erneut. | The analysis could not be processed. Please try again. |
| `ai_photos_button` | Fotos | Photos |
| `ai_flash_button` | Blitz | Flash |
| `ai_total_calories` | Gesamtkalorien | Total calories |

---

## 10. Implementierungsreihenfolge

| Schritt | Beschreibung | Aufwand |
|---------|-------------|---------|
| 1 | `AIFoodEstimate` Struct + `FoodComponent` Struct | Klein |
| 2 | `KeychainHelper` fuer API-Key Speicherung | Klein |
| 3 | `ClaudeAPIService` — HTTP-Client mit Vision-Request | Mittel |
| 4 | `AIFoodViewModel` — Bild-Kompression, API-Call, Eintrag-Erzeugung | Mittel |
| 5 | `AIFoodCameraView` — Vollbild-Kamera (AVFoundation + PhotosPicker) | Mittel |
| 6 | `AIFoodResultView` — Bestaetigungs-Screen mit Naehrwert-Karte | Mittel |
| 7 | `MealSectionView` — KI-Button neben Plus-Button | Klein |
| 8 | `DiaryListView` — Sheet-Anbindung fuer KI-Kamera | Klein |
| 9 | `SettingsView` — KI-Einstellungen-Sektion | Klein |
| 10 | Lokalisierung — Alle neuen Keys | Klein |
| 11 | pbxproj — Alle neuen Dateien registrieren | Klein |
| 12 | Unit-Tests — API-Parsing, Bild-Kompression, Eintrag-Erzeugung | Klein |

---

## 11. Offene Entscheidungen

| Frage | Optionen | Empfehlung |
|-------|---------|------------|
| Foto dauerhaft speichern? | A) Nein (spart Speicher) B) Ja, in FoodItem.imageData | A — Kein Speicherverbrauch |
| Mehrere Gerichte pro Foto? | A) Ein Eintrag pro Foto B) Mehrere Eintraege | A — Einfacher, spaeter erweiterbar |
| Galerie-Auswahl erlauben? | A) Nur Kamera B) Kamera + Galerie | B — Flexibler (altes Foto nutzen) |
| Offline-Fallback? | A) Keiner B) Manuelle Eingabe anbieten | B — QuickEntryView als Fallback |

---

## 12. Zusammenfassung Kosten

**Fazit:** Bei 3-4 Fotos pro Tag mit Haiku 3.5 kostet das Feature **unter 40 Cent pro Monat**. Das ist weniger als ein halber Cent pro Analyse. Selbst mit Sonnet 4 bleiben die Kosten unter 1,50 EUR/Monat. Das Feature ist wirtschaftlich absolut sinnvoll und rechnet sich im Vergleich zu kommerziellen Apps wie Yazio (Premium ~45 EUR/Jahr), die aehnliche Funktionen bieten.
