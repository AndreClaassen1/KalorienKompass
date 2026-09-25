# KalorienKompass UI Redesign: Unified Day View

## Konzept

Dashboard und Tagebuch werden zu **einer einzigen scrollbaren Tagesansicht** zusammengefuehrt.
Vorbild: Yazio — eine Hauptansicht mit Kalorienring, Mahlzeitkarten und Wasser.
Tap auf eine Mahlzeit oeffnet eine **Detail-Ansicht** (NavigationLink push) mit Eintraegen,
Makros und "Hinzufuegen"-Button.

## Navigationsstruktur (vorher vs. nachher)

```
VORHER (2 getrennte Views):              NACHHER (unified):
┌─────────────┐  ┌─────────────┐         ┌─────────────┐
│  Dashboard  │  │  Tagebuch   │         │  Tagesview  │──push──▶ MealDetailView
│  (Ring,     │  │  (Eintraege │         │  (alles in  │──push──▶ FoodSearchView
│   Makros,   │  │   pro Meal, │         │   einem)    │
│   Meals     │  │   Actions)  │         │             │
│   kompakt)  │  │             │         │             │
└─────────────┘  └─────────────┘         └─────────────┘
```

## Sidebar (Mac/iPad) — vereinfacht

```
VORHER:                    NACHHER:
┌──────────────────┐       ┌──────────────────┐
│ ▪ Dashboard      │       │ ▪ Tagebuch       │  ◀── ersetzt Dashboard + Diary
│ ▪ Tagebuch       │       │ ▪ Suche          │
│ ▪ Suche          │       │ ▪ iCloud Sync    │
│ ▪ iCloud Sync    │       │ ▪ Einstellungen  │
│ ▪ Einstellungen  │       └──────────────────┘
└──────────────────┘
```

---

## Screen 1: Tagesansicht (Hauptscreen)

Ersetzt Dashboard + DiaryListView. Alles in einem ScrollView.

```
┌─────────────────────────────────────────┐
│  ◀  Do, 5. Maerz 2026  ▶     [Kalender]│  ◀── DateNavigationView
├─────────────────────────────────────────┤
│                                         │
│     449          ╭─────╮        272     │
│   Gegessen       │1.908│    Verbrannt   │  ◀── CalorieHeroView
│                  │Uebrig│               │
│                  ╰─────╯                │
│                                         │
│  Kohlenhydrate    Eiweiss        Fett   │
│  ████░░░░░░░░░   ███░░░░░░░░  ██░░░░░░ │  ◀── MacroLimitsView
│  49 / 259 g      16 / 144 g   19 / 76g │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  Ernaehrung                             │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ ☕ Fruehstueck →       449/707 kcal│  │
│  │     Gouda, Butter, Roggenbrot... │[+]│  ◀── Tap → push MealDetailView
│  ├───────────────────────────────────┤  │      [+] → push FoodSearchView
│  │ 🍝 Mittagessen →        0/943 kcal│  │
│  │                                   │[+]│
│  ├───────────────────────────────────┤  │
│  │ 🍲 Abendessen →         0/589 kcal│  │
│  │                                   │[+]│
│  ├───────────────────────────────────┤  │
│  │ 🍎 Snacks →              0/118 kcal│  │
│  │                                   │[+]│
│  └───────────────────────────────────┘  │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  Aktivitaet                    +136 kcal│
│                                         │
│  🚶 Schritte               4.523/10.000│
│  🔥 Aktivitaet (ohne Training)  136 kcal│
│  🏃 Laufen   45 min            320 kcal│
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  Koerper                                │
│                                         │
│  ┌─ Gewicht ────────────────────────┐   │
│  │  82,3 kg          [Bearbeiten]   │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ┌─ Wasser ─────────────────────────┐   │
│  │  💧 750 / 2000 ml                │   │
│  │  [+150] [+250] [+500] [Manuell]  │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ┌─ BMI ────────────────────────────┐   │
│  │  ▓▓▓▓▓▓▓▓▓█░░░░░░░░  24,8      │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ┌─ Gewichtsverlauf ────────────────┐   │
│  │       ╱╲                         │   │
│  │    ╱╱    ╲╲____   ← 80 kg Ziel  │   │
│  │  ╱╱                              │   │
│  │  [30T] [90T] [180T]             │   │
│  └──────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘
```

### Unterschiede zu Yazio

| Aspekt          | Yazio                        | KalorienKompass              |
|-----------------|------------------------------|------------------------------|
| Mahlzeiten      | 4 (Fr, Mi, Ab, Snacks)      | 6 (+ 2. Fruehst., Kaffee)   |
| Mahlzeit-Tap    | Push → MealDetailView        | Push → MealDetailView        |
| [+] Button      | Push → FoodSearchView        | Push → FoodSearchView        |
| Sport-Sektion   | Nicht auf Hauptscreen        | Ja, mit HealthKit-Daten      |
| Koerper-Sektion | Wasser auf Hauptscreen       | Gewicht + Wasser + BMI       |
| Tab Bar         | 5 Tabs unten                 | Keine (Sidebar Mac/iPad)     |

### Anpassung fuer KalorienKompass: 6 Mahlzeiten

Yazio zeigt 4 kompakte Mahlzeiten. Wir haben 6. Um die Hauptansicht nicht zu ueberladen:
- **Immer sichtbar:** Fruehstueck, Mittagessen, Abendessen, Snacks (die 4 Haupt-Mahlzeiten)
- **Eingeklappt / auf Wunsch:** 2. Fruehstueck, Kaffeepause (nur sichtbar wenn Eintraege vorhanden ODER in Einstellungen aktiviert)

---

## Screen 2: Mahlzeit-Detail (MealDetailView) — NEU

Wird per NavigationLink push von der Tagesansicht erreicht.
Zeigt alle Eintraege einer Mahlzeit mit Naehrwert-Zusammenfassung.

```
┌─────────────────────────────────────────┐
│  ◀ Zurueck     Fruehstueck     [Bearbei]│  ◀── NavigationTitle
├─────────────────────────────────────────┤
│                                         │
│  ┌───────────────────────────────────┐  │
│  │           ☕                       │  │
│  │                            [📷]   │  │  ◀── Hero-Bereich (Emoji oder Foto)
│  └───────────────────────────────────┘  │
│                                         │
│  ┌────────────┬──────────────────────┐  │
│  │  449 kcal  │  49,0 g             │  │
│  │  Kalorien  │  Kohlenhydrate      │  │  ◀── 2x2 Makro-Grid
│  ├────────────┼──────────────────────┤  │
│  │  16,4 g    │  18,7 g             │  │
│  │  Eiweiss   │  Fett               │  │
│  └────────────┴──────────────────────┘  │
│                                         │
├─ Eintraege ─────────────────────────────┤
│                                         │
│  Gouda Kaese 40% Fett i.Tr.            │
│  40 g                      120 kcal  ▶ │  ◀── Tap → FoodAddView (Edit)
│  ─────────────────────────────────────  │
│  Butter                                 │
│  10 g                       74 kcal  ▶ │
│  ─────────────────────────────────────  │
│  Roggenbrot (Graubrot)                  │
│  120 g                     254 kcal  ▶ │
│  ─────────────────────────────────────  │
│                                         │
├─ Naehrwerte ────────────────────────────┤
│                                         │
│  Kalorien       ████████░░░  449/707 kcal│
│  Kohlenhydrate  ██████░░░░░   49/78 g  │
│  Eiweiss        ███░░░░░░░░   16/43 g  │
│  Fett           ████░░░░░░░   19/27 g  │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  ┌───────────────────────────────────┐  │
│  │        Mehr hinzufuegen           │  │  ◀── Prominent Button
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

### Aktionen im MealDetailView

| Aktion              | Ausloeser                     | Ziel                         |
|---------------------|-------------------------------|------------------------------|
| Eintrag bearbeiten  | Tap auf Eintrag-Zeile (▶)    | Sheet: FoodAddView (edit)    |
| Eintrag loeschen    | Swipe-to-delete              | Direkt loeschen              |
| Neues Essen suchen  | "Mehr hinzufuegen" Button     | Push: FoodSearchView         |
| KI-Schnelleingabe   | Toolbar ✨ Button             | Sheet: AIQuickEntryView      |
| KI-Kamera           | 📷 im Hero-Bereich           | Sheet: AIFoodCameraView      |
| Barcode scannen     | Toolbar Barcode-Button        | Sheet: BarcodeScannerView    |

---

## Screen 3: Essen hinzufuegen (FoodSearchView) — existiert bereits

Wird per push von MealDetailView erreicht. Titel zeigt Mahlzeitentyp.

```
┌─────────────────────────────────────────┐
│  ◀ Zurueck      Fruehstueck        •••  │
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────[📷]│  ◀── Suchfeld + Barcode-Button
│  │ 🔍 Was hattest du zum Fruehstueck?  │
│  └─────────────────────────────────────┘│
│                                         │
│  [Haeufig]  [Zuletzt]  [Favoriten]     │  ◀── Segment-Tabs
│                                         │
│  ─────────────────────────────────────  │
│  Butter                                 │
│  10 g                       74 kcal [+] │  ◀── Quick-Add via [+]
│  ─────────────────────────────────────  │
│  Roggenbrot (Graubrot)                  │
│  120 g                     254 kcal [+] │
│  ─────────────────────────────────────  │
│  Gouda Kaese 40% Fett i.Tr.            │
│  40 g                      120 kcal [+] │
│  ─────────────────────────────────────  │
│  Apfel (mit Schale), frisch             │
│  1 Frucht, gross (200 g)   130 kcal [+] │
│  ─────────────────────────────────────  │
│  Weizenbroetchen (Semmel)               │
│  1 Broetchen, ganz (60 g)  175 kcal [+] │
│  ─────────────────────────────────────  │
│                                         │
│                                         │
├─────────────────────────────────────────┤
│  ┌───────────────────────────────────┐  │
│  │            Fertig                 │  │  ◀── Schliesst und kehrt zurueck
│  └───────────────────────────────────┘  │
│                                         │
│     [📷 KI Kamera]    [🔍 Suche]       │  ◀── Bottom-Tabs (optional)
└─────────────────────────────────────────┘
```

---

## Navigationsfluss

```
Tagesansicht
  │
  ├── Tap auf Mahlzeit-Karte ──push──▶ MealDetailView
  │                                      │
  │                                      ├── "Mehr hinzufuegen" ──push──▶ FoodSearchView
  │                                      │                                  │
  │                                      │                                  ├── Tap [+] → Quick-Add
  │                                      │                                  ├── Tap Eintrag → FoodAddView (sheet)
  │                                      │                                  └── "Fertig" → pop zurueck
  │                                      │
  │                                      ├── Tap Eintrag ──sheet──▶ FoodAddView (edit)
  │                                      ├── Toolbar ✨ ──sheet──▶ AIQuickEntryView
  │                                      ├── Toolbar 📷 ──sheet──▶ BarcodeScannerView
  │                                      └── Hero 📷 ──sheet──▶ AIFoodCameraView
  │
  ├── Tap [+] auf Mahlzeit ──push──▶ FoodSearchView (direkt, ohne Detail)
  │
  ├── Gewicht [Bearbeiten] ──sheet──▶ WeightEntrySheet
  ├── Wasser [Manuell] ──sheet──▶ WaterManualEntrySheet
  └── Wasser [+150/+250/+500] → direkte Aktion
```

---

## Technische Umsetzung

### Was sich aendert

| Komponente         | Aktion                                             |
|--------------------|-----------------------------------------------------|
| `ContentView`      | `SidebarCategory.diary` entfernen, `.dashboard` → Tagesview |
| `DashboardView`    | Wird zur neuen "DayView" (umbenannt oder ersetzt)  |
| `DiaryListView`    | Entfaellt — Logik wandert in MealDetailView        |
| `MealCategoryCard` | Wird NavigationLink statt nur onTap                |
| **NEU:** `MealDetailView` | Neue View: Eintraege + Makros + Actions     |
| `NavigationModel`  | `selectedCategory` hat kein `.diary` mehr          |
| `FoodSearchView`   | Push statt Sheet (wenn von MealDetail kommend)     |

### Was bleibt gleich

- `DayViewModel` — unveraendert, wird von DayView UND MealDetailView geteilt
- `FoodAddView` — weiterhin Sheet fuer Menge/Einheit bearbeiten
- `AIQuickEntryView`, `AIFoodCameraView`, `BarcodeScannerView` — weiterhin Sheets
- `WeightEntryCard`, `WaterTrackingCard` — bleiben in der Tagesansicht
- `CalorieHeroView`, `MacroLimitsView` — bleiben oben in der Tagesansicht
- Alle Services, Models, WidgetKit — komplett unveraendert

### Entscheidungen

1. **Push statt Sheet fuer FoodSearch:** Ja. Logischer Navigationsstack: Tagesansicht → MealDetail → FoodSearch → zurueck. Konsistent mit Yazio.
2. **6 Mahlzeiten — Hybrid:** 4 Hauptmahlzeiten (Fruehstueck, Mittagessen, Abendessen, Snacks) immer sichtbar. 2. Fruehstueck und Kaffeepause nur wenn Eintraege vorhanden ODER in Einstellungen aktiviert (Toggle "Alle 6 Mahlzeiten anzeigen").
3. **macOS — Push im Detail-Bereich:** Kein 3-Column-Layout. NavigationStack im Detail-Bereich der bestehenden NavigationSplitView. Push funktioniert identisch zu iOS.
4. **Quick-Add [+] — Beides:** Tap auf Mahlzeitkarte → Push zu MealDetailView. [+] Button → Push direkt zu FoodSearchView (Shortcut, ueberspringt Detail).
