//
//  CalorieCalculator.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 05.02.26.
//

import Foundation

/// Kalorienberechnung nach Mifflin-St Jeor Formel
enum CalorieCalculator {

    /// Berechnet den Grundumsatz (BMR) nach Mifflin-St Jeor
    static func basalMetabolicRate(
        weightKg: Double,
        heightCm: Double,
        age: Int,
        gender: Gender
    ) -> Double {
        let base = 10.0 * weightKg + 6.25 * heightCm - 5.0 * Double(age)
        switch gender {
        case .male: return base + 5.0
        case .female: return base - 161.0
        }
    }

    /// Berechnet den Gesamtenergiebedarf (TDEE), gerundet auf 50 kcal
    static func totalDailyEnergyExpenditure(
        weightKg: Double,
        heightCm: Double,
        age: Int,
        gender: Gender,
        activityLevel: ActivityLevel
    ) -> Int {
        let bmr = basalMetabolicRate(
            weightKg: weightKg,
            heightCm: heightCm,
            age: age,
            gender: gender
        )
        let tdee = bmr * activityLevel.palFactor
        return Int((tdee / 50.0).rounded() * 50)
    }

    /// Berechnet das Kalorienziel mit Defizit, clamped auf Sicherheitsgrenze
    static func goalAdjustedCalories(
        weightKg: Double,
        heightCm: Double,
        age: Int,
        gender: Gender,
        activityLevel: ActivityLevel,
        weeklyGoalKg: Double
    ) -> Int {
        let tdee = totalDailyEnergyExpenditure(
            weightKg: weightKg,
            heightCm: heightCm,
            age: age,
            gender: gender,
            activityLevel: activityLevel
        )
        return BMICalculator.calorieGoalWithDeficit(
            tdee: tdee,
            weeklyGoalKg: weeklyGoalKg,
            gender: gender
        )
    }

    /// Berechnet die im PAL-Faktor implizierte Aktivitaet (TDEE − BMR)
    static func palImpliedActivity(
        weightKg: Double,
        heightCm: Double,
        age: Int,
        gender: Gender,
        activityLevel: ActivityLevel
    ) -> Int {
        let bmr = Int(basalMetabolicRate(
            weightKg: weightKg,
            heightCm: heightCm,
            age: age,
            gender: gender
        ))
        let tdee = totalDailyEnergyExpenditure(
            weightKg: weightKg,
            heightCm: heightCm,
            age: age,
            gender: gender,
            activityLevel: activityLevel
        )
        return tdee - bmr
    }
}
