# Konzept: Minimalistisches Interface ("Fokus-Modus")

Status: Entwurf, 2026-07-13
Autor: André Claaßen (Konzept mit Claude Code)

## 1. Zielbild in einem Satz

Ein radikal reduziertes Alternativ-Interface, in dem der einzige Erfassungsweg
**Sprache oder Text** ist: Man sagt oder tippt in Alltagssprache, was man gegessen
hat, die KI zerlegt das in einzelne Lebensmittel und sortiert sie automatisch in
die richtigen Mahlzeiten-Rubriken. Darunter stehen die Rubriken mit den Einträgen,
alles direkt bearbeitbar.

## 2. Motivation

Die App ist funktional gewachsen: Dashboard, Suche, Barcode, KI-Kamera,
KI-Schnelleingabe, Widgets, Makros, BMI, Sport, Wasser, Gewicht. Das ist mächtig,
aber für den Alltagsfall "kurz eintragen, was ich gegessen habe" zu viel. Der
Fokus-Modus stellt die These auf: **Erfassen muss ein einziger Handgriff sein,
sprechen oder tippen, fertig.** Alles andere tritt in den Hintergrund.

Wichtig: Der bestehende Vollmodus ("Abenteuermodus" mit allen Erfassungswegen)
bleibt vollständig erhalten. Der Fokus-Modus ist eine **zweite, gleichberechtigte
Oberfläche auf denselben Daten**, kein Ersatz und kein Fork.

## 3. Abgrenzung: Was der Fokus-Modus NICHT hat

| Entfällt im Fokus-Modus | Bleibt im Vollmodus |
|---|---|
| Barcode-Scanner | ja |
| KI-Foto-Kamera | ja |
| 3-Tier-Nahrungssuche (Offline-DB, SwiftData, OpenFoodFacts) | ja |
| Manuelle Nährwert-Eingabe mit Feldern | ja |
| Favoriten, eigene Einheiten, FoodCustomization-UI | ja (Daten bleiben nutzbar) |
| Makro-Detailbalken, BMI, Sport-Sektion, Gewichts-Chart | ja |
| Plus-Menü mit sechs Erfassungsarten | ersetzt durch **einen** Eingabebereich |

Der Fokus-Modus zeigt bewusst nur: Eingabe (Sprache/Text), die Mahlzeiten-Rubriken
mit Einträgen, und die Restkalorien als schlichte Zahl. Nicht mehr.

## 4. Kern-Interaktion

### 4.1 Der Ablauf

1. Nutzer tippt auf das Mikrofon (oder ins Textfeld).
2. Bei Sprache: **On-Device-Transkription** wandelt gesprochene Sprache live in Text.
3. Nutzer sagt frei: "Heute Morgen ein Brötchen mit Butter und Marmelade und einen Cappuccino."
4. Nach dem Stoppen (oder mit "Senden") geht der Text an die KI.
5. Die KI liefert **mehrere** Einträge zurück, jeder mit Nährwerten **und** einer
   vorgeschlagenen Mahlzeit (hier: Frühstück, aus "heute Morgen" abgeleitet).
6. Die Einträge erscheinen sofort in den passenden Rubriken darunter.
7. Nutzer kann jeden Eintrag antippen und korrigieren (Menge, Mahlzeit, Nährwerte)
   oder löschen.

### 4.2 Der entscheidende Unterschied zur heutigen KI-Schnelleingabe

Die heutige `ClaudeAPIService.estimateNutrients(description:)` liefert **genau einen**
`AIFoodEstimate`. Für den Fokus-Modus reicht das nicht, weil ein gesprochener Satz
typischerweise **mehrere Lebensmittel** enthält und zusätzlich **eine Mahlzeit-Zuordnung**
gebraucht wird.

Neuer Baustein: ein Mehrfach-Parsing, das aus einem Freitext eine **Liste** von
Einträgen erzeugt, jeder inklusive Mahlzeit-Vorschlag.

```
Eingabe: "heute Morgen ein Brötchen mit Butter und Marmelade und einen Cappuccino"

KI-Ausgabe (konzeptionell):
[
  { name: "Brötchen",   menge: 60 g,   mahlzeit: breakfast, kcal/100g: 265, ... },
  { name: "Butter",     menge: 10 g,   mahlzeit: breakfast, kcal/100g: 717, ... },
  { name: "Marmelade",  menge: 20 g,   mahlzeit: breakfast, kcal/100g: 250, ... },
  { name: "Cappuccino", menge: 150 ml, mahlzeit: breakfast, kcal/100g: 45,  ... }
]
```

### 4.3 Mahlzeit-Zuordnung: drei Ebenen

Die KI leitet die Mahlzeit aus dem Text ab, mit einer klaren Fallback-Kette:

1. **Explizit im Text**: "zum Mittagessen", "als Snack", "heute Morgen" → direkte Zuordnung.
2. **Aus der Uhrzeit**: kein Zeitwort genannt → aktuelle Tageszeit bestimmt die Mahlzeit
   (morgens Frühstück, mittags Mittagessen, abends Abendessen, dazwischen Snack/Kaffeepause).
3. **Kontext-Override**: Hat der Nutzer vor dem Sprechen eine Rubrik ausgewählt
   (z.B. Karte "Mittagessen" angetippt), landet alles dort, unabhängig vom Text.

Die zugeordnete Mahlzeit ist immer sichtbar und pro Eintrag per Tap änderbar
(Menü mit den sechs MealTypes). Damit bleibt die Automatik korrigierbar und
gewinnt Vertrauen.

## 5. Spracherkennung: On-Device

Der Nutzer wünscht ausdrücklich die von iOS angebotene Transkription **auf dem Gerät**.
Dafür gibt es zwei Wege, die je nach Ziel-OS gewählt werden:

- **Neu (iOS 26): `SpeechAnalyzer` + `SpeechTranscriber`** aus dem überarbeiteten
  Speech-Framework. Läuft on-device, ist auf längere, freie Diktate ausgelegt,
  liefert live Teilergebnisse und ist die von Apple empfohlene moderne API. Da das
  Projekt ohnehin iOS 26 als Deployment-Target hat, ist das der Primärweg.
- **Fallback: `SFSpeechRecognizer`** mit `requiresOnDeviceRecognition = true`.
  Bewährt, funktioniert auch on-device, aber älter und eher auf kürzere Phrasen
  optimiert.

Anforderungen unabhängig vom Weg:
- Berechtigungen: `NSSpeechRecognitionUsageDescription` (Spracherkennung) und
  weiterhin `NSMicrophoneUsageDescription` (Mikrofonzugriff) als `INFOPLIST_KEY_`
  im pbxproj hinterlegen, **für iOS- und Mac-Target**.
- Deutsche Locale als Standard, Sprachmodell bei Bedarf on-device nachladen.
- Live-Transkript sichtbar, damit der Nutzer beim Sprechen sieht, was ankommt.
- Kein Netz für die Transkription nötig; nur die anschließende Nährwert-Schätzung
  ruft die Claude-API auf (wie heute die KI-Schnelleingabe).

**macOS-Besonderheiten** (entscheidend, weil der Fokus-Modus auch auf dem Mac läuft):
- Die Mac-App ist sandboxed. Für Mikrofonzugriff braucht das Mac-Target zusätzlich
  das Entitlement `com.apple.security.device.audio-input`. Fehlt es, schlägt der
  Zugriff **still** fehl (gleiches Muster wie bei den Widget-Sandbox-Fallen im Projekt).
- `SpeechAnalyzer`/`SpeechTranscriber` sind auch unter macOS 26 verfügbar, on-device.
- Diktat-Auslösung auf dem Mac: Button plus **lokaler** Keyboard-Shortcut (greift nur
  bei aktivem Fenster). Ein **globaler** Hotkey (CGEvent-Tap) ist bewusst nicht Teil
  dieses Konzepts, er bräuchte Accessibility-Berechtigung und ist späterer Zusatz.

Neuer Service, konzeptionell: ein `SpeechTranscriptionService` (Actor), der Start,
Live-Teilergebnisse und Endresultat kapselt. Er läuft auf **iOS und macOS**
(`#if os(iOS) || os(macOS)`), da das Speech-Framework auf beiden vorhanden ist.
Auf der Watch existiert bereits eine Freitext-KI-Eingabe; Diktat dort ist ein
späterer Zusatz, kein Teil dieses Konzepts.

## 6. UI-Aufbau des Fokus-Modus

Ein einziger Screen, von oben nach unten:

```
┌───────────────────────────────────────────┐
│           1.908 kcal übrig                 │  ← schlichte Restkalorien-Zeile
│        (heute · Do, 13. Juli)              │     mit Datumsnavigation
├───────────────────────────────────────────┤
│  ┌─────────────────────────────────────┐  │
│  │  🎙  "Sag oder tippe, was du..."     │  │  ← Eingabebereich
│  │      [ Live-Transkript erscheint ]   │  │     groß, mittig, einladend
│  └─────────────────────────────────────┘  │
├───────────────────────────────────────────┤
│  Frühstück                        320 kcal │  ← Rubriken (MealTypes)
│   · Brötchen        60 g          160 kcal │     mit Einträgen darunter
│   · Butter          10 g           72 kcal │     jeder Eintrag: Tap = bearbeiten
│   · Cappuccino     150 ml          68 kcal │                    Swipe = löschen
│  ─────────────────────────────────────────│
│  Mittagessen                        0 kcal │
│  Abendessen                         0 kcal │
│  Snack                              0 kcal │
└───────────────────────────────────────────┘
```

Prinzipien:
- **Eine Erfassung, ein Ort.** Der Eingabebereich ist der einzige "Aktions"-Punkt.
- **Restkalorien als reine Zahl** (entschieden am 2026-07-13), kein Ring. Maximal
  reduziert, die Einträge stehen im Vordergrund. Plattformgleich auf iOS und Mac.
- **Rubriken immer sichtbar**, auch leere Hauptmahlzeiten, damit klar ist, wohin
  Einträge wandern. (Zweites Frühstück und Kaffeepause folgen der bestehenden
  Sichtbarkeitsregel: nur bei Einträgen oder wenn `showAllMealTypes` gesetzt ist.)
- **Bearbeiten bleibt vollwertig.** Tap auf einen Eintrag öffnet ein schlankes
  Editier-Sheet (Menge, Mahlzeit, Nährwerte). Das kann das bestehende Sheet-Muster
  wiederverwenden. Auf macOS: Sheet-Größe explizit setzen (`.frame(minWidth:...)`),
  wie im Projekt üblich, sonst bleibt der Inhalt unsichtbar.
- Liquid Glass nur auf dem Eingabebereich und der Navigationsebene, nicht auf den
  Einträgen (Content).
- **Mac-Layout**: derselbe Ein-Spalten-Aufbau, nur breiteres Fenster mit sinnvoller
  Mindestgröße und maximaler Inhaltsbreite, damit die Zeilen nicht auseinanderlaufen.

## 7. Koexistenz mit dem Vollmodus

Der Fokus-Modus ist eine Ansicht auf **denselben SwiftData/CloudKit-Daten**
(`FoodItem`, `DiaryEntry`, `DayRecord`, `UserProfile`). Kein neues Schema, kein
CloudKit-Deployment nötig. Ein im Fokus-Modus erfasster Eintrag ist im Vollmodus
sofort sichtbar und umgekehrt.

Umschalten zwischen den Modi (**entschieden am 2026-07-13, Option A**):
App-weiter Schalter in den Einstellungen. Ein `@AppStorage("interfaceMode")`
entscheidet beim Start, welche Wurzel-View geladen wird (Fokus vs. Voll). Klar,
kein Zustandschaos, gut testbar.

Verworfen: Fokus als zusätzlicher Tab (verwässert die Reduktion, volle Navigation
bliebe daneben) und Fokus als Zen-Einstiegsscreen mit Geste in den Vollmodus.

**Der Fokus-Modus ist ausdrücklich auch für macOS** (entschieden am 2026-07-13):
- Der `interfaceMode`-Schalter greift app-weit und ersetzt auf dem Mac den Inhalt
  des **Hauptfensters** (statt `NavigationSplitView` lädt `FocusDayView`).
- Die bestehende **MenuBarExtra bleibt unverändert** daneben. Sie ist mit ihrer
  KI-Schnelleingabe faktisch schon heute ein Mini-Fokus-Modus.
- Kein `#if os(iOS)`-Flickenteppich nötig: Die im Fokus-Modus entfallenden Features
  (Barcode, KI-Kamera) sind ohnehin iOS-only; was bleibt (Text, Sprache, Rubriken),
  ist plattformneutral.

## 8. Neue und geänderte Bausteine (Überblick, kein Code)

| Baustein | Art | Zweck |
|---|---|---|
| `SpeechTranscriptionService` | neu (Actor, iOS-only) | On-Device-Diktat, Live-Transkript |
| KI-Mehrfach-Parsing | neu (Methode in `ClaudeAPIService`) | Freitext → Liste von Einträgen inkl. Mahlzeit |
| `ParsedFoodItem` (o.ä.) | neu (Struct, Codable/Sendable) | ein geparster Eintrag mit Mahlzeit-Vorschlag |
| `FocusInputView` | neu (SwiftUI) | Eingabebereich mit Mikrofon + Textfeld + Transkript |
| `FocusDayView` | neu (SwiftUI) | Der Minimal-Screen (Restkalorien + Rubriken) |
| `FocusViewModel` | neu (@Observable) | Orchestriert Diktat, KI-Parsing, Speichern |
| Eintrag-Editier-Sheet | Wiederverwendung | vorhandenes Muster für Korrektur |
| `interfaceMode`-Schalter | neu (@AppStorage + Root-Switch, iOS + macOS) | Umschaltung Fokus/Voll |
| Info.plist-Keys | Ergänzung (iOS + Mac-Target) | Speech-Recognition- und Mikrofon-Berechtigung |
| Mac-Entitlement | Ergänzung | `com.apple.security.device.audio-input` (Sandbox) |
| Lokaler Keyboard-Shortcut (Mac) | neu | Diktat auslösen bei aktivem Fenster |

Datenzugriff (Laden des Tages, Speichern von Einträgen, Restkalorien) kann weitgehend
die Logik von `DayViewModel` und `AIQuickEntryViewModel.saveEntry` wiederverwenden,
nur eben für eine Liste statt eines Einzeleintrags.

## 9. Offene Fragen für die Konzeptrunde

Alle inhaltlichen Weichen sind gestellt (Stand 2026-07-13):

1. ~~Umschaltung~~ **Entschieden: Schalter in den Einstellungen (Option A).**
2. ~~Bestätigen oder sofort buchen?~~ **Entschieden: Sofort buchen.** Die geparsten
   Einträge erscheinen direkt in den Rubriken; die zuletzt gebuchte Charge wird klar
   markiert und ist per "Rückgängig" entfernbar. Schneller Flow, bleibt korrigierbar.
3. ~~Mengen-Genauigkeit~~ **Entschieden: Still Standardportion.** Die KI schätzt bei
   vagen Angaben ("ein bisschen Käse") still eine typische Portion, ohne Rückfrage.
   Korrektur per Tap.
4. ~~Restkalorien-Zeile~~ **Entschieden: Reine Zahl**, kein Ring. Plattformgleich.
5. ~~Watch~~ **Entschieden: Später, separat.** Watch-Diktat ist nicht Teil dieses
   Konzepts.
6. ~~Mac~~ **Entschieden: Hauptfenster-Ersatz auf macOS**, MenuBar bleibt. Globaler
   Hotkey bewusst nicht in diesem Umfang.

Bleibt nur als Umsetzungsdetail (keine Grundsatzentscheidung): die **Fehlerfälle /
Leerzustände**, jeweils mit klarem Weg zurück, kein Netz (KI nicht erreichbar),
Spracherkennung nicht verfügbar oder nicht erlaubt (dann nur Textfeld), API-Key
fehlt (Sprung in die Einstellungen), auf Mac zusätzlich Mikrofon-Berechtigung
verweigert.

## 10. Umsetzung in Etappen (Vorschlag)

1. **Etappe 1, Texteingabe zuerst**: `FocusDayView` + `FocusInputView` (nur Textfeld),
   KI-Mehrfach-Parsing, Buchen in Rubriken, Bearbeiten. Noch ohne Sprache. Damit ist
   das Kernkonzept vollständig testbar. Aufwand: ★★★☆☆
2. **Etappe 2, Sprache**: `SpeechTranscriptionService` (On-Device), Mikrofon-Button,
   Live-Transkript. Aufwand: ★★★☆☆
3. **Etappe 3, Umschaltung + Feinschliff**: `interfaceMode`-Schalter, Leerzustände,
   "Rückgängig" für die letzte Charge, Fehlerfälle. Aufwand: ★★☆☆☆

Gesamt: ★★★★☆ (mehrere neue Views und Services, aber datenseitig kein Neuland).

## 11. Nicht-Ziele

- Keine Änderung am Datenmodell, keine CloudKit-Migration.
- Kein Entfernen von Funktionen aus dem Vollmodus.
- Keine Offline-Nährwert-Schätzung: Die KI-Schätzung bleibt netzabhängig (Claude-API),
  nur die Transkription läuft on-device.
