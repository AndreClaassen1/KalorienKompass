//
//  DayScore.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 15.07.26.
//
//  Bewertet, wie ausgewogen der aktuelle Tag verlaeuft, und liefert eine
//  passende Ambient-Farbe fuer den Fokus-Hintergrund und den Kalorienring.
//  Rein abgeleitet aus bereits berechneten Tagesdaten — aendert KEINE
//  Kalorienberechnung (CalorieCalculator/NutrientCalculator bleiben unberuehrt).
//

import SwiftUI

struct DayScore: Sendable, Equatable {

    /// Grobklassifizierung des Tagesverlaufs
    enum Level: Sendable {
        case fresh      // Tag hat kaum begonnen, zu wenig Daten
        case onTrack    // im Rahmen und ausgewogen
        case watch      // grenzwertig
        case over       // ueber dem Kalorienziel
    }

    let level: Level
    /// 0...100, `nil` solange der Tag noch kaum Daten hat (.fresh)
    let value: Int?

    /// Semantische Ambient-Farbe — funktioniert in Hell und Dunkel.
    var color: Color {
        switch level {
        case .fresh:   Color(red: 0.36, green: 0.56, blue: 0.84) // ruhiges Blau
        case .onTrack: Color(red: 0.16, green: 0.71, blue: 0.45) // Gruen
        case .watch:   Color(red: 0.90, green: 0.62, blue: 0.20) // Bernstein
        case .over:    Color(red: 0.89, green: 0.36, blue: 0.28) // Coral
        }
    }

    /// Budget-basierte Bewertung: die Farbe misst allein das verbrauchte
    /// Kalorienbudget (gegessen / effektives Ziel). Viel Puffer = gruen, knapp = gelb,
    /// darueber = rot. Protein und Wasser fliessen BEWUSST nicht in die Farbe ein
    /// (dafuer gibt es eigene Anzeigen) — sonst wirkt "viel Puffer" faelschlich als
    /// Warnung. `protein`/`water`-Parameter bleiben aus Kompatibilitaet erhalten.
    static func compute(
        eatenCalories: Double,
        calorieGoal: Int,
        protein: Double,
        proteinGoal: Int,
        waterMl: Int,
        waterGoalMl: Int
    ) -> DayScore {
        compute(eatenCalories: eatenCalories, calorieGoal: calorieGoal)
    }

    /// Dieselbe Bewertung ohne die Parameter, die nicht mehr einfliessen.
    /// Aufrufer, die nur Kalorien zur Hand haben — etwa die Wochenleiste —
    /// muessen so keine vier Nullen als Platzhalter uebergeben.
    static func compute(eatenCalories: Double, calorieGoal: Int) -> DayScore {
        let goal = Double(max(calorieGoal, 1))
        let ratio = eatenCalories / goal
        let value = Int((min(ratio, 1.0) * 100).rounded())

        // Tag hat noch kaum begonnen — ruhiges Blau, noch keine Wertung
        if eatenCalories < goal * 0.12 {
            return DayScore(level: .fresh, value: nil)
        }
        // Ueber dem Tagesziel
        if ratio > 1.0 {
            return DayScore(level: .over, value: value)
        }
        // Puffer fast aufgebraucht (>= 90 %)
        if ratio >= 0.9 {
            return DayScore(level: .watch, value: value)
        }
        // Komfortabel im Budget
        return DayScore(level: .onTrack, value: value)
    }
}
