//
//  WidgetDataProvider.swift
//  KalorienKompassWidget
//
//  Erstellt von André Claaßen am 05.02.26.
//

import Foundation
import SwiftData

/// Snapshot der Tagesdaten fuer Widget-Anzeige
struct DaySnapshot: Sendable {
    let date: Date
    let totalCaloriesConsumed: Double
    let effectiveCalorieGoal: Int
    let remainingCalories: Double
    let burnedCalories: Int
    let waterIntakeMl: Int
    let waterGoalMl: Int
    let mealCalories: [MealType: Double]
    let mealBudgets: [MealType: Int]

    static let empty = DaySnapshot(
        date: Date(),
        totalCaloriesConsumed: 0,
        effectiveCalorieGoal: 2000,
        remainingCalories: 2000,
        burnedCalories: 0,
        waterIntakeMl: 0,
        waterGoalMl: 2000,
        mealCalories: [:],
        mealBudgets: [:]
    )
}

/// Laedt Tagesdaten aus SwiftData fuer Widget-Anzeige
enum WidgetDataProvider {

    /// Laedt den Durchschnitt der Aktivitaetskalorien der letzten 6 Tage
    /// - Returns: Durchschnitt oder nil wenn weniger als 3 Tage mit > 100 kcal vorhanden
    private static func fetchAverageActivityKcal(context: ModelContext, days: Int = 6) -> Int? {
        let endDate = Date().addingDays(-1)  // Gestern
        guard let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) else {
            return nil
        }

        return DayRecord.averageActiveEnergy(in: context, from: startDate, to: endDate)
    }

    /// Laedt den heutigen Tages-Snapshot
    static func loadTodaySnapshot() -> DaySnapshot {
        let container = DataModel.shared.modelContainer
        let context = ModelContext(container)
        let today = Date().startOfDay
        let endOfDay = today.endOfDay

        // Profil laden — kanonisch nach createdAt, ohne Bereinigung (Issue #63)
        let profile = UserProfile.existing(in: context)

        // DayRecord kanonisch lesen, damit Widget und App bei CloudKit-Duplikaten
        // dieselben Zahlen zeigen (Issue #65)
        let dayRecord = DayRecord.existing(in: context, for: today)

        // Tagebucheintraege laden
        let entryDescriptor = FetchDescriptor<DiaryEntry>(
            predicate: #Predicate<DiaryEntry> { entry in
                entry.date >= today && entry.date <= endOfDay
            }
        )
        let entries = (try? context.fetch(entryDescriptor)) ?? []

        // Effektives Kalorienziel — einheitliche Berechnung
        let nonWorkoutActive = dayRecord.nonWorkoutActiveEnergy

        let effectiveGoal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile,
            dayRecord: dayRecord,
            nonWorkoutActiveEnergy: nonWorkoutActive
        )

        // Gesamtkalorien
        let totalConsumed = entries.reduce(0.0) { $0 + $1.calories }
        let remaining = Double(effectiveGoal) - totalConsumed

        // Verbrannte Kalorien (Aktivitaet gesamt, inklusive Training)
        let burned = dayRecord?.activeEnergyKcal ?? 0

        // Pro-Mahlzeit-Kalorien und -Budgets (alle 6 Mahlzeiten)
        let widgetMeals = MealType.allCases
        var mealCals: [MealType: Double] = [:]
        var mealBudgets: [MealType: Int] = [:]
        for meal in widgetMeals {
            let mealEntries = entries.filter { $0.mealType == meal }
            mealCals[meal] = mealEntries.reduce(0.0) { $0 + $1.calories }
            mealBudgets[meal] = Int(Double(effectiveGoal) * meal.budgetWeight)
        }

        return DaySnapshot(
            date: today,
            totalCaloriesConsumed: totalConsumed,
            effectiveCalorieGoal: effectiveGoal,
            remainingCalories: remaining,
            burnedCalories: burned,
            waterIntakeMl: dayRecord?.waterIntakeMl ?? 0,
            waterGoalMl: profile?.dailyWaterGoalMl ?? 2000,
            mealCalories: mealCals,
            mealBudgets: mealBudgets
        )
    }
}
