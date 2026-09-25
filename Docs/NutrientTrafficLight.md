# Naehrstoff-Ampel (Traffic Light Scoring)

Bewertungssystem fuer Lebensmittel nach dem **britischen Traffic-Light-System** (UK FSA).

## Prinzip

Jeder Naehrstoff wird einzeln bewertet und erhaelt Punkte:
- **Gruen** = 0 Punkte (niedrig)
- **Gelb/Amber** = 1 Punkt (mittel)
- **Rot** = 2 Punkte (hoch)

Die Punkte werden summiert. Die Gesamtsumme ergibt die Ampelfarbe des Lebensmittels.

## Schwellwerte pro 100g

| Naehrstoff         | Gruen (0) | Gelb (1)    | Rot (2)  |
|--------------------|-----------|-------------|----------|
| Fett               | ≤ 3,0 g   | 3,1–17,5 g | > 17,5 g |
| Gesaettigte Fetts. | ≤ 1,5 g   | 1,6–5,0 g  | > 5,0 g  |
| Zucker             | ≤ 5,0 g   | 5,1–22,5 g | > 22,5 g |
| Salz               | ≤ 0,3 g   | 0,4–1,5 g  | > 1,5 g  |

Die vier Kategorien entsprechen den offiziellen UK-FSA-Grenzwerten.

**Kein Kalorien-Malus.** Eine fruehere Fassung zaehlte die Energiedichte als fuenfte
Kategorie mit. Sie wertete gesunde Lebensmittel ab, deren Kaloriengehalt nichts
ueber ihre Qualitaet sagt: Haferflocken, Nuesse und Trockenobst wurden gelb bis rot,
obwohl keiner der vier Naehrwerte auffaellig ist. Die Kalorien stehen ohnehin im
Tagesbudget; sie ein zweites Mal in die Qualitaetsbewertung zu ziehen, bestraft
dasselbe doppelt.

## Gesamtbewertung

| Score | Ampel | Bedeutung |
|-------|-------|-----------|
| 0–1   | Gruen | Gesund / unbedenklich |
| 2–3   | Gelb  | Mittel / in Massen ok |
| 4–8   | Rot   | Ungesund / sparsam verwenden |

Maximaler Score: 4 Kategorien x 2 Punkte = **8**.

## Beispiele

| Lebensmittel      | Fett | Ges.F. | Zucker | Salz | Score | Ampel |
|-------------------|------|--------|--------|------|-------|-------|
| Gurke             | 0    | 0      | 0      | 0    | **0** | Gruen |
| Apfel             | 0    | 0      | 1      | 0    | **1** | Gruen |
| Haferflocken      | 1    | 0      | 0      | 0    | **1** | Gruen |
| Roggenbrot        | 0    | 0      | 0      | 2    | **2** | Gelb  |
| Pommes            | 1    | 1      | 0      | 1    | **3** | Gelb  |
| Chips             | 2    | 1      | 0      | 1    | **4** | Rot   |
| Olivenoel         | 2    | 2      | 0      | 0    | **4** | Rot   |

## Fehlende Naehrwerte

Die vier Eingangswerte sind am `FoodItem` nicht optional; ein fehlender Wert ist
von einer echten Null nicht zu unterscheiden. `FoodItem.trafficLight` unterscheidet
deshalb ueber die Kalorien: ein Lebensmittel **mit** Energie, aber ohne ein einziges
Gramm Fett, Zucker oder Salz hat keine erfassten Naehrwerte, keine besonders reinen,
und bekommt `nil`. Bei null Kalorien (Wasser, schwarzer Kaffee) sind die Nullen
dagegen echt.

Geraten wird nirgends, nur die Darstellung unterscheidet sich: das CLI laesst die
Spalte leer und fuehrt den Eintrag als „ohne Angabe", die App zeigt an derselben
Stelle ein graues Fragezeichen samt Hinweis, damit das Zeilenraster stehen bleibt.
Eine falsche gruene Ampel ist schlechter als gar keine.

**Teilweise erfasste Werte.** Ein einziges Gramm Fett laesst die drei uebrigen
Kategorien als echte Null durchgehen; die Ampel faellt dann zu gruen aus. Die
Quelle dieser Luecken war die KI-Schaetzung: gesaettigte Fette, Zucker und Salz
standen nur im Prompt und fehlten in etwa jeder zwanzigsten Antwort, worauf der
Decoder still eine 0 einsetzte. Seit Issue #95 gibt `ClaudeAPIService` die
Antwortform als JSON-Schema vor und fuehrt die drei Felder als `required`; neue
Schaetzungen tragen sie damit immer.

Aeltere Eintraege behalten ihre Luecken und werden dadurch zu gruen bewertet. Die
Anzeigeregel wurde dafuer bewusst **nicht** verschaerft, weil die Menge feststeht
und nicht mehr waechst; stattdessen traegt `kk repair nutrients` (Issue #98) die
fehlenden Werte nach. Der Befehl listet ohne `--apply` nur auf, setzt allein die
drei Mikrowerte und laesst Kalorien und Makros unberuehrt, damit vergangene
Tagessummen sich nicht nachtraeglich verschieben.

Ausgenommen sind Lebensmittel, denen **auch** die Makros fehlen: dort gibt es
keinen Anker fuer eine Nachschaetzung, und der ehrliche Platzhalter aus #94 ist
besser als eine Ampel aus zwei nachgetragenen Werten und vier Nullen.

## Implementierung

- **Logik:** `Shared/Logic/NutrientTrafficLight.swift` — Schwellwerte, `score`,
  `rating(forScore:)` und `FoodItem.trafficLight` (Foundation-only, wird auch vom
  CLI kompiliert)
- **View:** `Shared/Views/Components/TrafficLightIndicator.swift` — Farbe und
  Icon-Name des Ratings
- **CLI:** `KalorienKompassCLI/Sources/kk/Nutrition.swift` — Punkt, Farbnamen und
  Tageszusammenfassung; Ausgabe in `kk today` und `kk today --json`
- **Quelle:** [UK FSA Traffic Light Labelling](https://www.food.gov.uk/safety-hygiene/check-the-label)
