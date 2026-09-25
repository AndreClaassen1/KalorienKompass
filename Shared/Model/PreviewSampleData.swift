//
//  PreviewSampleData.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import SwiftData
import Foundation

/// Beispieldaten fuer SwiftUI Previews und Tests
@MainActor
enum PreviewSampleData {

    /// In-Memory ModelContainer fuer Previews
    static let container: ModelContainer = {
        let schema = Schema([
            FoodItem.self,
            DiaryEntry.self,
            DayRecord.self,
            UserProfile.self,
            FoodCustomization.self,
            CustomUnit.self,
            PlannedEntry.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)

        // Beispieldaten einfuegen
        populateSampleData(context: container.mainContext)

        return container
    }()

    /// Fuellt den Context mit Beispieldaten
    static func populateSampleData(context: ModelContext) {
        // Benutzerprofil
        let profile = UserProfile(dailyCalorieGoal: 2000)
        profile.proteinGoalGrams = 60
        profile.carbsGoalGrams = 250
        profile.fatGoalGrams = 65
        profile.fiberGoalGrams = 30
        profile.dailyStepsGoal = 10000
        context.insert(profile)

        // Lebensmittel
        let oatmeal = FoodItem(
            name: "Haferflocken",
            brand: "Koelln",
            caloriesPer100g: 372,
            proteinPer100g: 13.5,
            carbsPer100g: 58.7,
            fatPer100g: 7.0,
            fiberPer100g: 10.0,
            defaultServingSizeGrams: 50,
            servingDescription: "1 Portion"
        )

        let banana = FoodItem(
            name: "Banane",
            caloriesPer100g: 89,
            proteinPer100g: 1.1,
            carbsPer100g: 22.8,
            fatPer100g: 0.3,
            fiberPer100g: 2.6,
            defaultServingSizeGrams: 120,
            servingDescription: "1 Stueck"
        )

        let chickenBreast = FoodItem(
            name: "Haehnchenbrust",
            caloriesPer100g: 165,
            proteinPer100g: 31.0,
            carbsPer100g: 0.0,
            fatPer100g: 3.6,
            fiberPer100g: 0.0,
            defaultServingSizeGrams: 150,
            servingDescription: "1 Stueck"
        )

        let rice = FoodItem(
            name: "Reis (gekocht)",
            caloriesPer100g: 130,
            proteinPer100g: 2.7,
            carbsPer100g: 28.2,
            fatPer100g: 0.3,
            fiberPer100g: 0.4,
            defaultServingSizeGrams: 200,
            servingDescription: "1 Portion"
        )

        let apple = FoodItem(
            name: "Apfel",
            caloriesPer100g: 52,
            proteinPer100g: 0.3,
            carbsPer100g: 13.8,
            fatPer100g: 0.2,
            fiberPer100g: 2.4,
            defaultServingSizeGrams: 180,
            servingDescription: "1 Stueck"
        )

        let salmon = FoodItem(
            name: "Lachs",
            caloriesPer100g: 208,
            proteinPer100g: 20.4,
            carbsPer100g: 0.0,
            fatPer100g: 13.4,
            fiberPer100g: 0.0,
            defaultServingSizeGrams: 150,
            servingDescription: "1 Filet"
        )

        let foods = [oatmeal, banana, chickenBreast, rice, apple, salmon]
        foods.forEach { context.insert($0) }

        // Tagebucheintraege fuer heute
        let today = Date().startOfDay

        let entry1 = DiaryEntry(date: today, mealType: .breakfast, amountGrams: 50, foodItem: oatmeal)
        let entry2 = DiaryEntry(date: today, mealType: .breakfast, amountGrams: 120, foodItem: banana)
        let entry3 = DiaryEntry(date: today, mealType: .lunch, amountGrams: 150, foodItem: chickenBreast)
        let entry4 = DiaryEntry(date: today, mealType: .lunch, amountGrams: 200, foodItem: rice)
        let entry5 = DiaryEntry(date: today, mealType: .snack, amountGrams: 180, foodItem: apple)
        let entry6 = DiaryEntry(date: today, mealType: .secondBreakfast, amountGrams: 120, foodItem: banana)
        let entry7 = DiaryEntry(date: today, mealType: .coffeeBreak, amountGrams: 180, foodItem: apple)

        [entry1, entry2, entry3, entry4, entry5, entry6, entry7].forEach { context.insert($0) }

        // Tagesrekord
        let dayRecord = DayRecord(date: today)
        dayRecord.steps = 7500
        dayRecord.weight = 82.5
        dayRecord.waterIntakeMl = 1500
        context.insert(dayRecord)
    }
}
