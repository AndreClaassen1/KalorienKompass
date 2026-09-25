# Kalorienberechnung in KalorienKompass

## Uebersicht

KalorienKompass bietet drei Modi fuer die Kalorienberechnung:

| Modus          | Basis           | Aktivitaet                              | Typischer Nutzer   |
|----------------|-----------------|---------------------------------------- |--------------------|
| **Dynamisch**  | TDEE            | PAL-Basis + HealthKit-Bonus (Apple Watch) | Apple Watch-Traeger |
| **Geschaetzt** | TDEE            | Aktivitaetsfaktor (PAL)                 | Ohne Apple Watch   |
| **Manuell**    | Benutzereingabe | —                                       | Eigenes Ziel       |

## Grundformeln

### BMR (Grundumsatz) — Mifflin-St Jeor

```
Maenner: BMR = 10 × Gewicht(kg) + 6.25 × Groesse(cm) - 5 × Alter + 5
Frauen:  BMR = 10 × Gewicht(kg) + 6.25 × Groesse(cm) - 5 × Alter - 161
```

**Gewichtsquelle:** `Gewicht(kg)` ist `UserProfile.bodyWeightKg`. Es hat genau eine
Eingabequelle — das taegliche Wiegen (Gewicht-Kachel). `DayViewModel.updateWeight`
schreibt den Wiegewert fuer heute zusaetzlich in `bodyWeightKg`, sodass BMR/TDEE im
Auto-Modus (live berechnet in `NutrientCalculator`) immer das aktuelle Gewicht nutzen.
Es gibt kein separates Gewichtsfeld mehr im Profil.

### TDEE (Gesamtenergiebedarf)

```
TDEE = BMR × PAL-Faktor
```

| Aktivitaetslevel | PAL-Faktor |
|------------------|------------|
| Sitzend          | 1.200      |
| Leicht aktiv     | 1.375      |
| Maessig aktiv    | 1.550      |
| Sehr aktiv       | 1.725      |

Ergebnis wird auf 50 kcal gerundet.

### Defizit / Ueberschuss

```
Tagesdefizit = (Wochenziel_kg × 7700) / 7
```

1 kg Koerperfett entspricht ca. 7700 kcal.

| Wochenziel | Tagesdefizit |
|------------|--------------|
| -0.25 kg   | -275 kcal    |
| -0.50 kg   | -550 kcal    |
| -0.75 kg   | -825 kcal    |
| -1.00 kg   | -1100 kcal   |

### Sicherheitsminimum

```
Maenner: 1500 kcal/Tag
Frauen:  1200 kcal/Tag
```

Das berechnete Ziel wird nie unter diesen Wert gesenkt.

## Effektives Kalorienziel (pro Tag)

### Dynamischer Modus (Apple Watch) — PAL-Bonus-Modell

```
Basis = TDEE + Defizit (clamped auf Sicherheitsminimum)
palImpliedActivity = TDEE - BMR
activityBonus = max(0, nonWorkoutActive - palImpliedActivity)
effectiveGoal = Basis × (1 + Wochenend-Bonus%) + activityBonus + creditedWorkout
```

- **nonWorkoutActive** = HealthKit activeEnergyBurned - workoutCalories
- **palImpliedActivity** = die im PAL-Faktor bereits enthaltene Aktivitaet (TDEE − BMR)
- **activityBonus** = nur die Aktivitaet, die UEBER der PAL-Schaetzung liegt
- **creditedWorkout** = workoutCalories × exerciseCreditPercent / 100
- **Keine Doppelzaehlung**: Der PAL-Faktor schaetzt die taegliche Grundaktivitaet.
  Die Apple Watch gibt nur einen Bonus, wenn die reale Bewegung diese Schaetzung uebersteigt.
  An ruhigen Tagen bleibt das Ziel bei TDEE + Defizit — es sinkt nie unter die PAL-Basis.

**In der App sichtbar** (Issue #80): Ein Tipp auf den Kalorienring oeffnet die
Aufschluesselung — Grundziel, Wochenendbonus, angerechnete Bewegung, angerechnetes
Training, Ziel, Gegessen, Uebrig. Sie kommt aus `NutrientCalculator.goalBreakdown()`,
und `effectiveCalorieGoal()` ist die Summe genau dieser Posten; beide koennen also
nicht auseinander laufen. Die Bewegungszeile nennt neben dem angerechneten Bonus auch
den Rohwert und den bereits im Grundziel enthaltenen Anteil — sonst wirkt es, als
haette die Aktivitaet keine Wirkung.

**Auch die Wochenleiste rechnet hiermit** (Issue #81): der Balken unter jedem
Tag zeigt `gegessen / Ziel dieses Tages`, das Ziel kommt aus derselben
Aufschluesselung. `goalBreakdown` gibt es dafuer in zwei Fassungen — einmal mit
einem `DayRecord`, einmal mit dessen Rohwerten (`date`, `workoutCaloriesKcal`,
`nonWorkoutActiveEnergy`). Die zweite wird gebraucht, weil die Leiste sieben Tage
auf einmal ueber `DayRecord.days(in:from:to:)` liest, also mit gefalteten
Tageswerten statt mit Records. Die Formel liegt nur in der Rohwert-Fassung, die
Record-Fassung reicht durch: zwei Rechnungen wuerden auseinander laufen, und dann
zeigte die Leiste eine andere Stufe als der Tag, den sie oeffnet.

### Geschaetzter Modus (ohne Apple Watch)

```
Basis = TDEE + Defizit (clamped auf Sicherheitsminimum)
effectiveGoal = Basis × (1 + Wochenend-Bonus%) + creditedWorkout
```

- **Kein nonWorkoutActive**, da der PAL-Faktor die Aktivitaet bereits abbildet
- Nur Workout-Anrechnung wird addiert (weil Sport ueber dem PAL-Niveau liegt)

### Manueller Modus

```
effectiveGoal = manuelles Ziel × (1 + Wochenend-Bonus%) + creditedWorkout
```

## Wochenend-Bonus

Samstag (weekday=7) und Sonntag (weekday=1) erhalten einen prozentualen Aufschlag auf die Basis:

```
adjustedBase = base + (base × weekendBonusPercent / 100)
```

Einstellbar: 0% (aus), 5%, 10%, 15%, 20%, 25%.

## Workout-Anrechnung

Workout-Kalorien aus HealthKit werden anteilig angerechnet:

```
creditedWorkout = workoutCalories × exerciseCreditPercent / 100
```

Einstellbar: 0-100%, Standard 50%.

## Makro-Verteilung (automatisch)

Bei aktivierter automatischer Berechnung: 30/40/30-Verteilung.

```
Protein = (Kalorienziel × 0.30) / 4 kcal/g
Carbs   = (Kalorienziel × 0.40) / 4 kcal/g
Fat     = (Kalorienziel × 0.30) / 9 kcal/g
```

## Beispielrechnungen

### Beispiel 1: Dynamischer Modus (PAL-Bonus)

Mann, 80 kg, 175 cm, 30 Jahre, leicht aktiv (PAL 1.375), Ziel -0.5 kg/Woche, Apple Watch

```
BMR  = 10×80 + 6.25×175 - 5×30 + 5 = 1749 kcal
TDEE = 1749 × 1.375 = 2405 → gerundet 2400 kcal
palImpliedActivity = 2400 - 1749 = 651 kcal
Defizit = -550 kcal
Basis = max(2400 - 550, 1500) = 1850 kcal

Tag A: nonWorkoutActive = 300 kcal (unter PAL), Workout 400 kcal, Credit 50%
  activityBonus = max(0, 300 - 651) = 0
  effectiveGoal = 1850 + 0 + (400 × 50%) = 2050 kcal

Tag B: nonWorkoutActive = 800 kcal (ueber PAL), Workout 400 kcal, Credit 50%
  activityBonus = max(0, 800 - 651) = 149
  effectiveGoal = 1850 + 149 + (400 × 50%) = 2199 kcal
```

### Beispiel 2: Geschaetzter Modus

Mann, 80 kg, 175 cm, 30 Jahre, maessig aktiv, Ziel -0.5 kg/Woche

```
TDEE = 1749 × 1.55 = 2710 → gerundet 2700 kcal
Defizit = -550 kcal
Basis = max(2700 - 550, 1500) = 2150 kcal

Tag: Workout 400 kcal, Credit 50%
effectiveGoal = 2150 + (400 × 50%) = 2350 kcal
```

### Beispiel 3: Dynamischer Modus mit Wochenend-Bonus

Frau, 60 kg, 165 cm, 25 Jahre, leicht aktiv (PAL 1.375), Ziel -0.25 kg/Woche, Apple Watch, Samstag, 10% Bonus

```
BMR  = 10×60 + 6.25×165 - 5×25 - 161 = 1345 kcal
TDEE = 1345 × 1.375 = 1849 → gerundet 1850 kcal
palImpliedActivity = 1850 - 1345 = 505 kcal
Defizit = -275 kcal
Basis = max(1850 - 275, 1200) = 1575 kcal
adjustedBase = 1575 + (1575 × 10%) = 1733 kcal

Tag: nonWorkoutActive = 200 kcal (unter PAL), kein Workout
  activityBonus = max(0, 200 - 505) = 0
  effectiveGoal = 1733 + 0 + 0 = 1733 kcal
```

## Implementierung

| Datei                      | Verantwortung                                                          |
|----------------------------|------------------------------------------------------------------------|
| `CalorieCalculator.swift`  | BMR, TDEE, goalAdjustedCalories, palImpliedActivity                    |
| `BMICalculator.swift`      | Defizit, Sicherheitsminimum, calorieGoalWithDeficit                    |
| `NutrientCalculator.swift` | `goalBreakdown()` — einheitliche 3-Pfad-Logik (PAL-Bonus-Modell); `effectiveCalorieGoal()` ist nur noch deren Summe |
| `CalorieBudgetSheet.swift` | Zeigt die Posten aus `goalBreakdown()` (Tipp auf den Kalorienring)     |
| `DayViewModel.swift`       | Delegiert an `NutrientCalculator.effectiveCalorieGoal()`; `refreshWeek()` rechnet die sieben Tage der Wochenleiste ueber `goalBreakdown(profile:date:workoutCaloriesKcal:nonWorkoutActiveEnergy:)` |
| `WidgetDataProvider.swift` | Delegiert an `NutrientCalculator.effectiveCalorieGoal()`               |
| `SettingsViewModel.swift`  | `calculatedCalorieGoal` (TDEE-basiert, fuer Einstellungs-Anzeige)      |
| `UserProfile.swift`        | `useAutoCalories`, `useHealthKitActivity`, `expectedDailyActivityKcal` |
