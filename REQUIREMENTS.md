# KalorienKompass - Anforderungsdokument

## Projektübersicht

Multiplatform Kalorien-Tracking-App in SwiftUI mit SwiftData, inspiriert von CaloryGuard Pro. Projektname: **KalorienKompass**.

**Zielplattformen:** iOS, iPadOS, macOS, watchOS
**Technologie:** SwiftUI, SwiftData, CloudKit
**Design-Sprache:** Liquid Glass (iOS 26 / macOS 26) — modernes, transluzentes Design, keine 1:1-Kopie des Originals
**Referenz-Architektur:** AboveAndBeyond-Projekt (Shared-Ordner-Struktur, Actor-based DataModel, CloudKit-Sync)

---

## 1. Datenmodell

### 1.1 FoodItem (Lebensmittel-Datenbank)
- `name: String` — Name des Lebensmittels
- `category: String` — Kategorie (z.B. "Fastfood", "Diverse andere Gerichte")
- `brand: String?` — Marke (optional)
- `barcode: String?` — EAN/UPC Barcode (für OpenFoodFacts-Abgleich)
- `openFoodFactsId: String?` — OpenFoodFacts Produkt-ID (für Updates)
- `caloriesPer100g: Double` — Kalorien pro 100g
- `fatPer100g: Double` — Fett pro 100g
- `carbsPer100g: Double` — Kohlenhydrate pro 100g
- `proteinPer100g: Double` — Eiweiß pro 100g
- `defaultPortionGrams: Double` — Standard-Portionsgröße in Gramm
- `defaultPortionLabel: String?` — Bezeichnung der Portion (z.B. "1 Stück", "1 Portion")
- `isFavorite: Bool` — Favoriten-Markierung
- `isUserCreated: Bool` — Vom Benutzer manuell angelegt vs. aus OpenFoodFacts

### 1.2 DiaryEntry (Tagebucheintrag / gegessene Speise)
- `date: Date` — Datum des Eintrags
- `meal: MealType` — Mahlzeit (Frühstück, Mittagessen, Abendessen, Snack)
- `foodItem: FoodItem` — Referenz auf das Lebensmittel
- `portionCount: Double` — Anzahl Portionen
- `gramsConsumed: Double` — tatsächlich gegessene Menge in Gramm
- **Computed:** `calories`, `fat`, `carbs`, `protein` (berechnet aus Gramm × Nährwerte/100g)

### 1.3 ActivityEntry (Sport / Aktivität)
- `date: Date` — Datum
- `activityType: ActivityType?` — Referenz auf vordefinierte Aktivität (optional)
- `name: String` — Name der Aktivität
- `durationMinutes: Int` — Dauer in Minuten
- `caloriesBurned: Double` — Verbrannte Kalorien (automatisch berechnet oder manuell)
- `fromHealthKit: Bool` — Ob aus HealthKit importiert

### 1.3a ActivityType (Vordefinierte Aktivitäten-Datenbank)
- `name: String` — Name der Aktivität (z.B. "Joggen", "Radfahren", "Schwimmen")
- `category: String` — Kategorie (Ausdauer, Kraft, Alltag, etc.)
- `metValue: Double` — MET-Wert (Metabolic Equivalent of Task)
- **Berechnung:** Kalorien = MET × Gewicht(kg) × Dauer(h)

### 1.4 DayRecord (Tagesübersicht)
- `date: Date` — Datum
- `weight: Double?` — Tagesgewicht in kg (optional)
- `steps: Int?` — Schritte (optional)
- `note: String?` — Tagesnotiz (optional)

### 1.5 UserProfile (Benutzerprofil / Einstellungen)
- `calorieGoal: Double` — Kalorienziel pro Tag
- `fatGoalGrams: Double` — Fettziel in Gramm
- `carbsGoalGrams: Double` — Kohlenhydrate-Ziel in Gramm
- `proteinGoalGrams: Double` — Eiweiß-Ziel in Gramm
- `weightGoal: Double?` — Zielgewicht in kg
- `currentWeight: Double?` — Aktuelles Gewicht
- `stepsGoal: Int` — Schritteziel (Standard: 10.000)
- `waterGoalLiters: Double` — Wasserziel in Litern (Standard: 2,7)

---

## 2. Screens / Views

### 2.1 Tagesübersicht (Home / Dashboard)
**Hauptscreen der App — zeigt den aktuellen Tag**

#### Datumsnavigation
- **macOS/iPadOS:** Pfeile links/rechts zum Tageswechsel + Kalender-Button
- **iPhone:** Horizontaler scrollbarer Datums-Strip mit ~10 Tagen
  - Zeigt Tageszahlen (30, 31, 01, 02, ...) nebeneinander
  - Aktueller Tag hervorgehoben mit Wochentag-Kürzel + Monat (z.B. "Mi. 04 Feb.")
  - Swipe-Geste zum schnellen Tageswechsel

#### Tagesumsatz-Karte ("Dein Tagesumsatz")
- **Kalorien (kcal):** Aktuell / Ziel / Übrig
- **Gewicht (kg):** Aktuell / Ziel / Differenz
- **Makro-Limits:** Max. Eiweiß (aktuell/Ziel), Max. KH (aktuell/Ziel), Max. Fett (aktuell/Ziel)
- **Schritte:** Aktuelle Schrittzahl
- **Getrunken:** X / X l (Phase 2)
- **macOS:** Zusätzlich Pie Chart mit Makro-Verteilung (Fett %, KH %, Eiweiß %)
- **macOS:** Visueller Fortschrittsbalken für Kalorien
- **iPhone:** Kompaktes Grid-Layout (Kalorien links, Gewicht rechts, Limits darunter)

#### Schnellaktionen (Seitenleiste auf iPhone)
- Auf iPhone: Icons rechts neben der Tagesumsatz-Karte
  - Waage (Tagesgewicht erfassen)
  - Aktivitäten hinzufügen
  - Einstellungen
- Auf macOS: Toolbar-Buttons oben

#### Speisen-Sektion
- Header: "Speisen" + Gesamtkalorien rechts + Hinzufügen-Icon
- Gruppiert nach Mahlzeit (Frühstück, Mittagessen, Abendessen, Snack)
- Pro Eintrag: Name, Menge (Gramm + Portionsbezeichnung), Kalorien, Fett, KH, Eiweiß
- Summenzeile pro Mahlzeit
- Tap auf Hinzufügen-Icon → Lebensmittel-Suche

#### Sport/Aktivität-Sektion
- Header: "Sport / Aktivität" + Gesamtkalorien rechts + Hinzufügen-Icon
- Name, Dauer, Verbrannte Kalorien
- Tap auf Hinzufügen-Icon → Aktivitäten-Suche

### 2.2 Lebensmittel-Suche
**Suche und Auswahl von Lebensmitteln zum Hinzufügen**

#### macOS/iPadOS-Layout (Side Panel)
- **Suchfeld:** Echtzeit-Suche nach Name
- **Tab-Filter:** Favoriten, Ergebnisse (Relevanz), Ergebnisse (alphabetisch), Kategorien, Marken
- **Ergebnisliste:** Tabelle mit Name, Kategorie, Kalorien, Fett, KH, Eiweiß (pro 100g)
- **Detail-Panel rechts bei Auswahl:**
  - Name + "Ändern"-Button
  - Portionen: Slider + Stepper
  - Gramm: Slider + Stepper
  - Kalorien: Slider + Stepper (berechnet)
  - Mahlzeit-Auswahl: Dropdown
  - Favoriten-Herz-Button + "Hinzufügen"-Button

#### iPhone-Layout (Vollbild-Navigation)
- **Header:** "Zurück" + Suchfeld + "Neu"-Button
- **Tabs:** "Favoriten" / "Hauptliste" (vereinfacht gegenüber macOS)
- **Toolbar-Icons:** Barcode-Scanner, Sortierung, Filter
- **Ergebnisliste alphabetisch gruppiert:**
  - Sektions-Header pro Anfangsbuchstabe (A, B, C, ...)
  - Pro Eintrag: Name + Marke in Klammern (z.B. "Weizenbrötchen (Aldi)")
  - Zweite Zeile: "EW: X g  KH: X g  F: X g" — kompakte Nährwert-Anzeige
  - Kalorien rechts: "XXX kcal"
  - Werte die Tageslimit überschreiten farblich hervorgehoben (rot)
- **"Neu"-Button:** Eigenes Lebensmittel anlegen

#### Gemeinsame Funktionalität
- Echtzeit-Suche (lokal + OpenFoodFacts)
- Favoriten-Filter
- Barcode-Scanner-Zugang (iOS/iPadOS)

### 2.3 Lebensmittel-Detail / Hinzufügen (iPhone)
**Eigener Screen nach Auswahl eines Lebensmittels**

- **Navigation:** "< Suche" (zurück), "Bearbeiten", "Zu Favoriten"
- **Lebensmittel-Name** als Überschrift
- **Kompakte Eingabe:**
  - Kalorien (kcal) und Gewicht (g) nebeneinander (werden gegenseitig berechnet)
  - Mahlzeit-Auswahl: Frühstück / Mittagessen / Abendessen / Snack (Navigation-Link)
- **Mengen-Picker (unten, Wheel-Style):**
  - Spalte 1: Ganzzahl (0, 1, 2, 3, ...)
  - Spalte 2: Bruch (—, ⅛, ¼, ⅓, ½, ⅔, ¾)
  - Spalte 3: Einheit (Gramm (g), Stück, Kalorien)
  - Ermöglicht Eingabe wie "1 ½ Stück" oder "300 Gramm" oder direkt "450 Kalorien"
- **"OK"-Button:** Bestätigen und zum Tagebuch hinzufügen

### 2.4 Lebensmittel bearbeiten / Neues Lebensmittel
- Name, Kategorie, Marke
- Nährwerte pro 100g: Kalorien, Fett, Kohlenhydrate, Eiweiß
- Standard-Portionsgröße und -bezeichnung

### 2.5 Aktivitäten-Suche / Hinzufügen
- Suche nach Aktivitäten (aus Datenbank oder eigene)
- Dauer eingeben
- Kalorienverbrauch (manuell oder berechnet)

### 2.6 Tagesgewicht erfassen
- Gewichtseingabe für den aktuellen Tag
- Verlauf/Trend sichtbar

### 2.7 Notiz hinzufügen (verworfen)
- Freitext-Notiz zum aktuellen Tag. Nie umgesetzt; das Feld `DayRecord.notes` wurde
  mit Issue #68 entfernt, weil es nie eine Oberfläche bekam und als optionales Feld
  ohne Wert auch nie im CloudKit-Schema landete — dort wäre es beim ersten Setzen
  zum Sync-Stopper geworden.

### 2.8 Statistik
- Kalorienentwicklung über Zeit (Woche/Monat/Jahr)
- Gewichtsverlauf
- Makronährstoff-Verteilung über Zeit
- Durchschnittswerte

### 2.9 Einstellungen
- Kalorienziel, Makronährstoff-Ziele
- Gewichtsziel
- Schritteziel
- Wasserziel
- Persönliche Daten

### 2.10 Barcode-Scanner (iOS/iPadOS)
- Kamera-basierter Barcode-Scan (EAN/UPC)
- Automatische Abfrage bei OpenFoodFacts API
- Produkt mit Nährwerten automatisch laden und in lokale DB übernehmen
- Falls Produkt nicht gefunden: Option zum manuellen Anlegen mit gescanntem Barcode
- Plattform-spezifisch: nur iOS/iPadOS (nicht macOS/watchOS)

---

---

## 3. Design-Richtung: Liquid Glass (iOS 26 / macOS 26)

Die App soll **nicht** das Original-Design von CaloryGuard Pro kopieren, sondern die Funktionalität in modernes Apple Liquid Glass Design übersetzen (unter dem neuen Projektnamen **KalorienKompass**):

- **Liquid Glass Materialien:** Transluzente, glasartige Oberflächen mit Tiefeneffekt
- **Dynamische Farben:** Vibrante Akzentfarben, die sich an den Hintergrund anpassen
- **Rounded Corners:** Großzügige Abrundungen bei Karten und Containern
- **Typografie:** SF Pro mit klarer Hierarchie (Large Title, Headline, Body, Caption)
- **Cards/Grouped Sections:** Inhalte in Glaseffekt-Karten statt flachen Tabellen
- **Haptic Feedback:** Taktiles Feedback bei Interaktionen (iPhone/Watch)
- **Animationen:** Flüssige Übergänge und Micro-Animations
- **Dark Mode:** Vollständige Unterstützung von Anfang an
- **Adaptive Layout:** Responsive Anpassung an iPhone/iPad/Mac-Bildschirmgrößen

### Plattform-spezifische Design-Anpassungen
- **iPhone:** Kompaktes, vertikal-optimiertes Layout, Datums-Strip, Bottom-Sheet-Dialoge
- **iPad:** Sidebar-Navigation, Split-View für Suche + Detail
- **macOS:** Toolbar, Menüleiste, größere Tabellenansichten, Keyboard-Shortcuts
- **watchOS:** Minimalistisch, fokussiert auf Tagesübersicht und Quick-Add

---

## 4. Toolbar-Aktionen (aus Screenshot 1)

| Icon | Aktion |
|------|--------|
| Lebensmittel | Lebensmittel-Suche öffnen |
| Aktivitäten | Aktivitäten hinzufügen |
| Barcode | Barcode-Scanner öffnen |
| Tagesgewicht | Gewicht für heute erfassen |
| ~~Notiz hinzufügen~~ | verworfen, siehe 2.7 |
| Statistik | Statistik-Ansicht öffnen |
| Einstellungen | Einstellungen öffnen |

---

## 5. Technische Architektur (orientiert an AboveAndBeyond)

### 5.1 Projektstruktur
```
KalorienKompass/
├── Shared/                          # Plattformübergreifender Code (~90%)
│   ├── Model/                       # SwiftData Models
│   │   ├── FoodItem.swift
│   │   ├── DiaryEntry.swift
│   │   ├── ActivityEntry.swift
│   │   ├── DayRecord.swift
│   │   ├── UserProfile.swift
│   │   └── DataModel.swift          # Actor-based ModelContainer
│   ├── ViewModel/                   # @Observable ViewModels
│   │   ├── DayViewModel.swift       # Tagesübersicht-State
│   │   ├── FoodSearchViewModel.swift
│   │   └── StatisticsViewModel.swift
│   ├── Views/                       # SwiftUI Views
│   │   ├── DashboardView.swift
│   │   ├── FoodSearchView.swift
│   │   ├── FoodDetailPanel.swift
│   │   ├── DiaryListView.swift
│   │   ├── ActivityListView.swift
│   │   ├── StatisticsView.swift
│   │   ├── SettingsView.swift
│   │   ├── NutrientPieChart.swift
│   │   └── CalorieProgressBar.swift
│   ├── Logic/                       # Business-Logik
│   │   └── NutrientCalculator.swift
│   └── KalorienKompassApp.swift
├── KalorienKompass (watchOS) Watch App/  # watchOS-spezifisch
│   ├── WatchDashboardView.swift     # Vereinfachte Tagesübersicht
│   └── WatchQuickAddView.swift      # Schnelles Hinzufügen
├── macOS/                           # macOS-spezifisch
│   └── AppKitMenu.swift             # Native Menüleiste
├── Tests/                           # Unit Tests
└── KalorienKompass.xcodeproj
```

### 5.2 Technologie-Stack
- **UI:** SwiftUI (NavigationSplitView für responsive Layouts)
- **Persistenz:** SwiftData mit `@Model`
- **Sync:** CloudKit (Private Database über App Group)
- **State Management:** `@Observable` (modern), `@Observable` ViewModels
- **Charts:** Swift Charts Framework für Statistiken und Pie Chart
- **Barcode:** AVFoundation (iOS/iPadOS only)
- **Lebensmittel-API:** OpenFoodFacts REST API (kostenlos, keine API-Key nötig)
- **Gesundheitsdaten:** HealthKit (Gewicht, Schritte, Workouts, verbrannte Kalorien)
- **Concurrency:** Swift Concurrency (async/await, actors)
- **Lokalisierung:** Deutsch + Englisch (String Catalogs / Localizable.xcstrings)
- **Export:** CSV/JSON-Export für Tagebuch und Lebensmittel-Datenbank

### 5.3 Multiplatform-Strategie
- **Shared (90%):** Alle Models, ViewModels, die meisten Views
- **iOS/iPadOS:** Barcode-Scanner, optimierte Touch-UI
- **macOS:** Native Menüleiste, Keyboard-Shortcuts, größere Layouts
- **watchOS:** Vereinfachte Tagesübersicht, Quick-Add für häufige Speisen
- **Conditional Compilation:** `#if os(iOS)`, `#if os(macOS)`, `#if os(watchOS)`

### 5.4 DataModel-Pattern (aus AboveAndBeyond)
- Actor-based `DataModel` Singleton
- App Group Container für Widget-/Extension-Zugriff
- CloudKit-Sync mit automatischer Umgebungserkennung (Dev/Prod)
- DEBUG-Modus mit Store-Recovery

---

## 6. Integrationen

### 6.1 OpenFoodFacts API
- **Lebensmittel-Suche:** Textsuche über OpenFoodFacts API (`https://world.openfoodfacts.org/api/v2/search`)
- **Barcode-Lookup:** Produkt per Barcode laden (`https://world.openfoodfacts.org/api/v2/product/{barcode}`)
- **Datenübernahme:** Nährwerte pro 100g, Produktname, Marke, Kategorie, Portionsgröße
- **Lokaler Cache:** Einmal geladene Produkte werden als FoodItem in SwiftData gespeichert
- **Offline-fähig:** Lokale DB funktioniert ohne Internetverbindung

### 6.2 HealthKit
- **Lesen:** Gewicht, Schritte (täglich), Workout-Aktivitäten mit verbrannten Kalorien
- **Schreiben:** Kalorien-Intake als Dietary Energy (optional)
- **Automatische Synchronisation:** Schritte und Gewicht automatisch in DayRecord übernehmen
- **Plattform:** iOS, iPadOS, watchOS (nicht macOS)

### 6.3 Import/Export
- **CSV-Export:** Tagebucheinträge mit Datum, Mahlzeit, Lebensmittel, Menge, Nährwerten
- **JSON-Export:** Vollständige Lebensmittel-Datenbank (eigene + bearbeitete Einträge)
- **CSV-Import:** Lebensmittel-Datenbank aus CSV importieren
- **Share Sheet:** Export über iOS Share Sheet / macOS Sharing

---

## 7. Priorisierung (MVP)

### Phase 1 — Kern-Funktionalität
1. Datenmodell (SwiftData) + Persistenz
2. Tagesübersicht (Dashboard) mit Fortschrittsbalken + Nährwert-Chart
3. OpenFoodFacts-Integration (Lebensmittel-Suche + Barcode-Scan)
4. Speisen-Liste pro Tag mit Mahlzeit-Gruppierung
5. Einstellungen (Ziele konfigurieren)
6. HealthKit-Integration (Schritte, Gewicht)
7. Lokalisierung Deutsch + Englisch

### Phase 2 — Erweiterung
8. Aktivitäten mit vordefinierter Datenbank (MET-Werte)
9. Gewichtsverlauf + Statistik-Ansichten
10. Favoriten-System
11. Eigene Lebensmittel anlegen/bearbeiten
12. Wasser-Tracking
13. Import/Export (CSV/JSON)

### Phase 3 — Plattform-spezifisch
14. watchOS Companion App
15. CloudKit-Sync
16. macOS-Menüleiste
17. Widgets

---

## 8. Geklärte Entscheidungen

| Frage | Entscheidung |
|-------|-------------|
| Lebensmittel-Datenbank | OpenFoodFacts API (online) |
| Wasser-Tracking | Später (Phase 2+), im Datenmodell vorbereiten |
| HealthKit-Integration | Ja, von Anfang an (Schritte, Gewicht, Workouts) |
| Sprachen | Deutsch + Englisch (Lokalisierung von Anfang an) |
| Import/Export | Ja (CSV/JSON) |
| Aktivitäten-Datenbank | Vordefinierte DB mit MET-Werten (automatische Kalorienberechnung) |
| Barcode-Scanner | Ja, direkt mit OpenFoodFacts verknüpft |
| Design-Sprache | Liquid Glass (iOS 26 / macOS 26), keine 1:1-Kopie des Originals |

---

*Dokument wird nach und nach mit weiteren Screenshots und Feedback erweitert.*
