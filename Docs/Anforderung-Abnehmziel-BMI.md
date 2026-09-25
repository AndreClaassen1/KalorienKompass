# Anforderung: Abnehmziel und BMI-Visualisierung

## 1. Uebersicht

KalorienKompass soll dem Benutzer ermoeglichen, ein persoenliches Abnehmziel festzulegen und den Fortschritt visuell zu verfolgen. Dazu gehoeren:

- **Persoenliches Profil** mit Koerperdaten (Alter, Geschlecht, Groesse, Gewicht, Aktivitaetslevel)
- **BMI-Visualisierung** mit farbcodiertem Balken und Kategorie-Anzeige
- **Zielgewicht** und automatische Berechnung des Kaloriendefizits
- **Wochenziel** fuer die Abnehmgeschwindigkeit
- **Automatische Kalorienberechnung** basierend auf TDEE minus Defizit

---

## 2. Bestehende Infrastruktur

### Bereits vorhanden

| Komponente | Status | Details |
|-----------|--------|---------|
| UserProfile-Model | Vorhanden | Alter, Geschlecht, Groesse, Gewicht, Aktivitaetslevel |
| `weightGoalKg: Double?` | Im Model definiert | Aber **kein UI** dafuer |
| CalorieCalculator | Vorhanden | BMR (Mifflin-St Jeor) + TDEE (BMR x PAL) |
| Auto-Kalorien-Toggle | Vorhanden | `useAutoCalories` berechnet TDEE |
| Taegliche Gewichtserfassung | Vorhanden | DayRecord.weight via HealthKit/manuell |
| SettingsView | Vorhanden | Form-basiert mit Sections |

### Fehlt

| Komponente | Beschreibung |
|-----------|-------------|
| BMI-Berechnung | `gewicht / (groesse_m)^2` — trivial, aber nirgends berechnet |
| BMI-Visualisierung | Farbbalken mit Kategorien und Zeiger |
| Zielgewicht-UI | Eingabe fuer Zielgewicht |
| Wochenziel | Abnehmgeschwindigkeit (z.B. -0,3 kg/Woche) |
| Kaloriendefizit-Logik | TDEE minus Defizit basierend auf Wochenziel |
| Ziel-Sektion in Settings | Eigener Bereich fuer alle Ziel-Einstellungen |

---

## 3. Datenmodell-Erweiterungen

### UserProfile — neue Felder

```
weightGoalKg: Double?          // Zielgewicht (bereits vorhanden, aber ungenutzt)
startWeightKg: Double?         // Startgewicht bei Zielbeginn
goalStartDate: Date?           // Datum des Zielbeginns
weeklyWeightGoalKg: Double     // Wochenziel in kg (default: -0.5)
                               // Negative Werte = Abnehmen
                               // Positive Werte = Zunehmen
                               // 0 = Gewicht halten
goalType: GoalType             // Enum: lose, maintain, gain
```

### Neues Enum: GoalType

```
enum GoalType: Int, Codable, CaseIterable {
    case lose = 0      // Abnehmen
    case maintain = 1  // Halten
    case gain = 2      // Zunehmen
}
```

### Erlaubte Wochenziel-Stufen

| Stufe | kg/Woche | kcal Defizit/Tag | Bewertung |
|-------|----------|-----------------|-----------|
| Langsam | -0,25 kg | ~275 kcal | Schonend, nachhaltig |
| Moderat | -0,50 kg | ~550 kcal | Empfohlen |
| Schnell | -0,75 kg | ~825 kcal | Ambitioniert |
| Sehr schnell | -1,00 kg | ~1100 kcal | Nur kurzfristig empfohlen |

> **Formel:** 1 kg Koerperfett ≈ 7.700 kcal → Defizit/Tag = (Wochenziel_kg x 7700) / 7

---

## 4. Berechnungslogik

### BMI

```
BMI = gewicht_kg / (groesse_m)^2
```

### BMI-Kategorien (WHO)

| Kategorie | BMI-Bereich | Farbe |
|----------|-------------|-------|
| Untergewicht | < 18,5 | Blau |
| Normalgewicht | 18,5 – 24,9 | Gruen |
| Uebergewicht | 25,0 – 29,9 | Gelb |
| Adipositas I | 30,0 – 34,9 | Orange |
| Adipositas II | 35,0 – 39,9 | Rot |
| Adipositas III | >= 40,0 | Dunkelrot |

### Kalorienziel mit Defizit

```
Grundumsatz (BMR)     = Mifflin-St Jeor (bereits implementiert)
Gesamtumsatz (TDEE)   = BMR x PAL-Faktor (bereits implementiert)
Tagesdefizit          = (weeklyWeightGoalKg x 7700) / 7
Kalorienziel          = TDEE + Tagesdefizit
                        (Tagesdefizit ist negativ beim Abnehmen)
```

### Sicherheitsgrenzen

- Kalorienziel **niemals unter 1200 kcal** (Frauen) / **1500 kcal** (Maenner)
- Warnung anzeigen, wenn berechnetes Ziel unter Sicherheitsgrenze faellt
- In dem Fall: Defizit automatisch reduzieren

### Geschaetzte Zieldauer

```
verbleibendes_gewicht = aktuelles_gewicht - zielgewicht
wochen_bis_ziel = verbleibendes_gewicht / |weeklyWeightGoalKg|
zieldatum = heute + (wochen_bis_ziel x 7) Tage
```

---

## 5. UI-Design

### 5.1 Einstellungen — Neue Sektion "Mein Ziel"

Die bestehende SettingsView erhaelt eine neue Sektion zwischen "Persoenliche Daten" und "Kalorien". Der Aufbau ist fuer **beide Plattformen identisch** (SwiftUI Form), da Form auf Mac und iOS nativ korrekt gerendert wird.

#### Sektion "Mein Ziel"

```
┌─────────────────────────────────────────────────┐
│  Mein Ziel                                      │
├─────────────────────────────────────────────────┤
│  Ziel              [Abnehmen ▾]                 │  ← Picker: Abnehmen/Halten/Zunehmen
│  Startgewicht      89,5 kg          (autom.)    │  ← Wird beim Setzen des Ziels gespeichert
│  Aktuelles Gewicht 87,2 kg          (HealthKit) │  ← Letzter DayRecord.weight
│  Zielgewicht       [  82,0  ] kg                │  ← Eingabefeld
│  Wochenziel        [-0,50 kg ▾]                 │  ← Picker mit den 4 Stufen
├─────────────────────────────────────────────────┤
│  ┌─ BMI ──────────────────────────────────────┐ │
│  │ ██████████████████████░░░░░░░░░░░░░░░░░░░ │ │
│  │ unter │ normal │ überge. │ Adip.I│II│III  │ │  ← Farbbalken
│  │            ▲                              │ │
│  │          25,4                             │ │  ← Aktueller BMI mit Zeiger
│  └───────────────────────────────────────────┘ │
├─────────────────────────────────────────────────┤
│  Berechneter Grundumsatz (BMR)     1.756 kcal   │
│  Gesamtumsatz (TDEE)               2.722 kcal   │
│  Tagesdefizit                       -550 kcal   │
│  ─────────────────────────────────────────────  │
│  Dein Kalorienziel                 2.172 kcal   │  ← Fett hervorgehoben
│  Geschaetztes Zieldatum         ca. 12.05.2026  │
├─────────────────────────────────────────────────┤
│  [ ] Kalorienziel manuell festlegen             │  ← Toggle ueberschreibt Berechnung
│  Manuelles Ziel       [  2.200  ] kcal          │  ← Nur sichtbar wenn Toggle an
└─────────────────────────────────────────────────┘
```

### 5.2 BMI-Visualisierung (Komponente)

Eine eigenstaendige SwiftUI-View `BMIBarView`, wiederverwendbar in Settings und optional im Dashboard.

**Aufbau:**

```
┌──────────────────────────────────────────────────────┐
│  Dein BMI                                            │
│  ┌──┬────────┬──────────┬─────────┬──────┬─────────┐ │
│  │  │        │          │         │      │         │ │
│  │  │ Normal │ Übergew. │ Adip. I │ II   │  III    │ │
│  └──┴────────┴──────────┴─────────┴──────┴─────────┘ │
│           ▲                                          │
│         25,4                                         │
│  Kategorie: Uebergewicht                             │
└──────────────────────────────────────────────────────┘
```

**Technische Details:**
- `GeometryReader` fuer responsive Breite
- Farbsegmente als `HStack` mit proportionaler Breite (BMI 15–45 als Gesamtskala)
- Zeiger als `Triangle`-Shape, positioniert via `offset`
- BMI-Wert und Kategorie-Label darunter
- Farben: Blau → Gruen → Gelb → Orange → Rot → Dunkelrot

### 5.3 Dashboard-Integration (optional, spaeter)

Auf dem Dashboard koennte ein kompakter Fortschrittsbereich erscheinen:

```
┌─────────────────────────────────────────┐
│  Ziel: 82,0 kg                         │
│  87,2 ━━━━━━━━━━━━━━░░░░░░░ 82,0 kg    │  ← Fortschrittsbalken
│  Noch 5,2 kg · ca. 10 Wochen           │
└─────────────────────────────────────────┘
```

### 5.4 Dashboard: Gewichtsverlauf-Grafik

Im Dashboard-Bereich "Koerper" wird eine Gewichtsverlauf-Grafik mit Swift Charts angezeigt:

```
┌─────────────────────────────────────────────────┐
│  Gewichtsverlauf                                │
│  90 ┤                                           │
│     │ •                                         │
│  88 ┤   •  •                                    │
│     │        •  •                               │
│  86 ┤             •  •                          │
│     │                  · · · · · · · · (Ziel)   │  ← Gestrichelte Ziellinie
│  82 ┤─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─   │  ← Zielgewicht
│     └───┬───┬───┬───┬───┬───┬───┬───┬───┬───   │
│       Jan  Feb  Mär  Apr  Mai  Jun  Jul  Aug    │
│                                                 │
│  Aktuell: 87,2 kg → Ziel: 82,0 kg              │
│  Noch 5,2 kg · ca. 10 Wochen                   │
└─────────────────────────────────────────────────┘
```

**Technische Details:**
- `Chart` mit `LineMark` fuer Gewichtsdaten (aus DayRecord.weight)
- `RuleMark` fuer Zielgewicht-Linie (gestrichelt)
- `LineMark` mit Interpolation fuer Trend-Projektion
- Datenquelle: DayRecord-Eintraege mit `weight != nil`
- Zeitraum: Letzte 30/90/180 Tage (Segmented Picker)
- Y-Achse: Automatisch skaliert mit etwas Padding

### 5.5 Dashboard: Kompakter BMI-Balken

Im Koerper-Bereich des Dashboards erscheint ein kompakter BMI-Balken:

```
┌─────────────────────────────────────────┐
│  BMI 25,4 · Uebergewicht               │
│  ██████████████░░░░░░░░░░░░░░░░░░░░░░  │
└─────────────────────────────────────────┘
```

Kleiner als in den Einstellungen — nur Balken + Wert + Kategorie in einer Zeile.

---

## 6. Auswirkung auf bestehende Logik

### Kalorienziel-Berechnung aendern

Aktuell berechnet `CalorieCalculator.totalDailyEnergyExpenditure()` nur den reinen TDEE. Das Kalorienziel im UserProfile wird entweder manuell gesetzt oder gleich dem TDEE.

**Neu:** Wenn ein Abnehmziel aktiv ist UND `useAutoCalories == true`:

```
Kalorienziel = max(TDEE + Defizit, Sicherheitsgrenze)
```

Die bestehende `updateAutoCalories()`-Methode im SettingsViewModel muss erweitert werden.

### Makro-Anpassung (automatisch)

Bei einem Kaloriendefizit werden die Makroziele automatisch proportional angepasst:

```
Standard-Verteilung:
  Protein:        30% der Kalorien  →  g = (Kalorienziel x 0.30) / 4
  Kohlenhydrate:  40% der Kalorien  →  g = (Kalorienziel x 0.40) / 4
  Fett:           30% der Kalorien  →  g = (Kalorienziel x 0.30) / 9
  Ballaststoffe:  Fest 30 g (unabhaengig vom Kalorienziel)
```

Die automatische Anpassung greift nur bei `useAutoCalories == true`. Bei manueller Kalorienvorgabe bleiben die Makros ebenfalls manuell.

### HealthKit: Zielgewicht synchronisieren (bidirektional)

Das Zielgewicht wird mit HealthKit synchronisiert:

- **Schreiben:** Wenn der Benutzer ein Zielgewicht in KalorienKompass setzt, wird es als `HKQuantityType(.bodyMassGoal)` in HealthKit gespeichert.
- **Lesen:** Beim App-Start und bei Aenderungen wird das Zielgewicht aus HealthKit gelesen. Wenn es dort neuer ist, wird es uebernommen.
- **Konfliktloesung:** Die juengere Aenderung gewinnt (Vergleich ueber Zeitstempel).

---

## 7. Lokalisierung

Neue Keys (DE / EN):

| Key | Deutsch | English |
|-----|---------|---------|
| `goal_section_title` | Mein Ziel | My Goal |
| `goal_type_lose` | Abnehmen | Lose Weight |
| `goal_type_maintain` | Gewicht halten | Maintain Weight |
| `goal_type_gain` | Zunehmen | Gain Weight |
| `goal_start_weight` | Startgewicht | Starting Weight |
| `goal_current_weight` | Aktuelles Gewicht | Current Weight |
| `goal_target_weight` | Zielgewicht | Target Weight |
| `goal_weekly_rate` | Wochenziel | Weekly Goal |
| `goal_estimated_date` | Geschaetztes Zieldatum | Estimated Goal Date |
| `bmi_title` | Dein BMI | Your BMI |
| `bmi_underweight` | Untergewicht | Underweight |
| `bmi_normal` | Normalgewicht | Normal |
| `bmi_overweight` | Uebergewicht | Overweight |
| `bmi_obese_1` | Adipositas I | Obese I |
| `bmi_obese_2` | Adipositas II | Obese II |
| `bmi_obese_3` | Adipositas III | Obese III |
| `calorie_bmr` | Grundumsatz (BMR) | Basal Metabolic Rate |
| `calorie_tdee` | Gesamtumsatz (TDEE) | Total Daily Energy |
| `calorie_deficit` | Tagesdefizit | Daily Deficit |
| `calorie_your_goal` | Dein Kalorienziel | Your Calorie Goal |
| `calorie_manual_override` | Kalorienziel manuell festlegen | Set calorie goal manually |
| `goal_safety_warning` | Das berechnete Ziel liegt unter der empfohlenen Mindestmenge. Das Defizit wurde automatisch angepasst. | The calculated goal is below the recommended minimum. The deficit has been adjusted automatically. |
| `weekly_rate_slow` | Langsam (-0,25 kg) | Slow (-0.25 kg) |
| `weekly_rate_moderate` | Moderat (-0,50 kg) | Moderate (-0.50 kg) |
| `weekly_rate_fast` | Schnell (-0,75 kg) | Fast (-0.75 kg) |
| `weekly_rate_very_fast` | Sehr schnell (-1,0 kg) | Very fast (-1.0 kg) |

---

## 8. Implementierungsreihenfolge

| Schritt | Beschreibung | Aufwand |
|---------|-------------|---------|
| 1 | UserProfile um neue Felder erweitern (`GoalType`, `startWeightKg`, `goalStartDate`, `weeklyWeightGoalKg`) | Klein |
| 2 | `BMICalculator` erstellen (BMI, Kategorie, Sicherheitsgrenzen, Makro-Verteilung) | Klein |
| 3 | `BMIBarView` als eigenstaendige SwiftUI-Komponente | Mittel |
| 4 | CalorieCalculator um Defizit-Logik und Auto-Makros erweitern | Klein |
| 5 | SettingsView: Neue "Mein Ziel"-Sektion mit allen Feldern + BMI-Bar | Mittel |
| 6 | SettingsViewModel: Ziel-Logik, Auto-Update bei Aenderungen | Mittel |
| 7 | HealthKitManager: `bodyMassGoal` lesen/schreiben (bidirektional) | Mittel |
| 8 | Dashboard: Kompakter BMI-Balken im Koerper-Bereich | Klein |
| 9 | Dashboard: Gewichtsverlauf-Grafik (Swift Charts + Ziellinie) | Mittel |
| 10 | Lokalisierung: Alle neuen Keys in Localizable.xcstrings | Klein |

---

## 9. Entschiedene Fragen

| Frage | Entscheidung |
|-------|-------------|
| HealthKit-Zielgewicht | Bidirektional: Lesen + Schreiben (`HKQuantityType(.bodyMassGoal)`) |
| Gewichtsverlauf-Grafik | Ja, im Dashboard (Swift Charts mit Ziellinie) |
| Makro-Anpassung | Automatisch proportional zum Kalorienziel (30/40/30) |
| BMI-Anzeige | Einstellungen (gross) + Dashboard (kompakt) |
