//
//  BMICalculator.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 05.02.26.
//

import SwiftUI

/// BMI-Berechnung und Ziel-Logik
enum BMICalculator {

    /// Berechnet den BMI aus Gewicht (kg) und Groesse (cm)
    static func bmi(weightKg: Double, heightCm: Double) -> Double {
        guard heightCm > 0 else { return 0 }
        let heightM = heightCm / 100.0
        return weightKg / (heightM * heightM)
    }

    /// Bestimmt die BMI-Kategorie
    static func category(bmi: Double) -> BMICategory {
        BMICategory.allCases.first { $0.range.contains(bmi) } ?? .obese3
    }

    /// Sicherheitsminimum in kcal nach Geschlecht
    static func safetyMinimum(gender: Gender) -> Int {
        switch gender {
        case .female: 1200
        case .male: 1500
        }
    }

    /// Tagesdefizit in kcal basierend auf Wochenziel (1 kg ≈ 7700 kcal)
    static func dailyDeficit(weeklyGoalKg: Double) -> Int {
        Int((weeklyGoalKg * 7700.0) / 7.0)
    }

    /// Kalorienziel mit Defizit, clamped auf Sicherheitsgrenze
    static func calorieGoalWithDeficit(tdee: Int, weeklyGoalKg: Double, gender: Gender) -> Int {
        let deficit = dailyDeficit(weeklyGoalKg: weeklyGoalKg)
        let raw = tdee + deficit
        return max(raw, safetyMinimum(gender: gender))
    }

    /// Geschaetztes Zieldatum basierend auf Abnehmgeschwindigkeit
    static func estimatedGoalDate(currentKg: Double, goalKg: Double, weeklyGoalKg: Double) -> Date? {
        guard weeklyGoalKg != 0 else { return nil }
        let remaining = currentKg - goalKg
        let weeks = remaining / abs(weeklyGoalKg)
        guard weeks > 0 else { return nil }
        let days = Int(weeks * 7)
        return Calendar.current.date(byAdding: .day, value: days, to: Date())
    }

    /// Berechnet Makro-Gramm nach 30/40/30-Verteilung (Protein/Carbs/Fat)
    static func macroGrams(calorieGoal: Int) -> (protein: Int, carbs: Int, fat: Int) {
        let cals = Double(calorieGoal)
        let protein = Int((cals * 0.30) / 4.0)
        let carbs = Int((cals * 0.40) / 4.0)
        let fat = Int((cals * 0.30) / 9.0)
        return (protein, carbs, fat)
    }
}

/// BMI-Kategorien nach WHO
enum BMICategory: CaseIterable, Identifiable, Sendable {
    case underweight, normal, overweight, obese1, obese2, obese3

    var id: String { localizedName }

    var localizedName: String {
        switch self {
        case .underweight: String(localized: "bmi_underweight")
        case .normal: String(localized: "bmi_normal")
        case .overweight: String(localized: "bmi_overweight")
        case .obese1: String(localized: "bmi_obese_1")
        case .obese2: String(localized: "bmi_obese_2")
        case .obese3: String(localized: "bmi_obese_3")
        }
    }

    var color: Color {
        switch self {
        case .underweight: .blue
        case .normal: .green
        case .overweight: .yellow
        case .obese1: .orange
        case .obese2: .red
        case .obese3: Color(red: 0.6, green: 0, blue: 0)
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .underweight: 0...18.49
        case .normal: 18.5...24.99
        case .overweight: 25.0...29.99
        case .obese1: 30.0...34.99
        case .obese2: 35.0...39.99
        case .obese3: 40.0...100.0
        }
    }

    /// Breite des Segments auf der BMI-Skala (15–45)
    var scaleWidth: Double {
        switch self {
        case .underweight: 3.5   // 15.0 – 18.5
        case .normal: 6.5        // 18.5 – 25.0
        case .overweight: 5.0    // 25.0 – 30.0
        case .obese1: 5.0        // 30.0 – 35.0
        case .obese2: 5.0        // 35.0 – 40.0
        case .obese3: 5.0        // 40.0 – 45.0
        }
    }
}
