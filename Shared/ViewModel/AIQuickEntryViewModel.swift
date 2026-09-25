//
//  AIQuickEntryViewModel.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 19.02.26.
//

import SwiftUI
import SwiftData
import WidgetKit

/// ViewModel fuer KI-basierte Freitext-Schnelleingabe
@Observable
final class AIQuickEntryViewModel {
    var description: String = ""
    var mealType: MealType = .lunch
    var estimate: AIFoodEstimate?
    var isLoading: Bool = false
    var errorMessage: String?
    var saveForLater: Bool = false

    // Editierbare Felder — Nährwerte pro 100g + Portionsgröße
    var editedName: String = ""
    var editedPortionGrams: Double = 0
    var editedCaloriesPer100g: Double = 0
    var editedProteinPer100g: Double = 0
    var editedCarbsPer100g: Double = 0
    var editedFatPer100g: Double = 0
    var editedFiberPer100g: Double = 0

    // Berechnete Portionswerte (skalieren proportional mit editedPortionGrams)
    var portionCalories: Double { editedCaloriesPer100g * editedPortionGrams / 100 }
    var portionProtein:  Double { editedProteinPer100g  * editedPortionGrams / 100 }
    var portionCarbs:    Double { editedCarbsPer100g    * editedPortionGrams / 100 }
    var portionFat:      Double { editedFatPer100g      * editedPortionGrams / 100 }

    var hasAPIKey: Bool { KeychainHelper.hasAPIKey }

    // MARK: - KI-Schaetzung

    @MainActor
    func estimateNutrients() async {
        let text = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        estimate = nil

        do {
            let result = try await ClaudeAPIService.shared.estimateNutrients(description: text)
            estimate = result
            editedName           = result.name.isEmpty ? text : result.name
            editedPortionGrams   = result.estimatedWeightGrams
            editedCaloriesPer100g = result.caloriesPer100g
            editedProteinPer100g  = result.proteinPer100g
            editedCarbsPer100g    = result.carbsPer100g
            editedFatPer100g      = result.fatPer100g
            editedFiberPer100g    = result.fiberPer100g
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Setzt die Schätzung zurück, damit der User einen neuen Text eingeben kann
    func clearEstimate() {
        estimate = nil
        errorMessage = nil
    }

    // MARK: - Eintrag speichern

    func saveEntry(date: Date, context: ModelContext) {
        guard editedPortionGrams > 0, editedCaloriesPer100g > 0 else { return }

        let name = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let foodItem = FoodItem(
            name: name.isEmpty ? String(localized: "quick_entry_default_name") : name,
            caloriesPer100g: editedCaloriesPer100g,
            proteinPer100g:  editedProteinPer100g,
            carbsPer100g:    editedCarbsPer100g,
            fatPer100g:      editedFatPer100g,
            fiberPer100g:    editedFiberPer100g
        )

        if let est = estimate {
            foodItem.sugarPer100g        = est.sugarPer100g
            foodItem.saturatedFatPer100g = est.saturatedFatPer100g
            foodItem.saltPer100g         = est.saltPer100g
        }
        foodItem.isQuickEntry  = !saveForLater
        foodItem.isUserCreated = saveForLater

        let entry = DiaryEntry(
            date: date,
            mealType: mealType,
            amountGrams: editedPortionGrams,
            foodItem: foodItem
        )
        context.insert(foodItem)
        context.insert(entry)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        NavigationModel.shared.entryAddedCount += 1
    }
}
