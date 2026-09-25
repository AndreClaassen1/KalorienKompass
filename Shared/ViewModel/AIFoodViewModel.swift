//
//  AIFoodViewModel.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 05.02.26.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// ViewModel fuer KI-basierte Mahlzeiten-Erkennung
@Observable
final class AIFoodViewModel {
    private let modelContext: ModelContext

    var estimate: AIFoodEstimate?
    var isAnalyzing = false
    var errorMessage: String?

    /// Gespeichertes Bild als Rohdaten fuer plattformuebergreifende Analyse
    var capturedImageData: Data?

    /// Gespeichertes Bild fuer erneute Analyse mit Benutzer-Hinweis (iOS)
    #if canImport(UIKit)
    var capturedImage: UIImage?
    #endif
    /// Benutzer-Hinweis fuer die erneute Analyse (z.B. "Das ist Kaesekuchen, ca. 150g")
    var userHint: String = ""

    /// Editierbare Felder (vom Benutzer anpassbar)
    var editedName: String = ""
    var editedPortionGrams: Double = 0
    var editedCaloriesPer100g: Double = 0
    var editedProteinPer100g: Double = 0
    var editedCarbsPer100g: Double = 0
    var editedFatPer100g: Double = 0
    var editedFiberPer100g: Double = 0

    /// Berechnete Portionswerte
    var portionCalories: Double {
        editedCaloriesPer100g * editedPortionGrams / 100
    }

    var portionProtein: Double {
        editedProteinPer100g * editedPortionGrams / 100
    }

    var portionCarbs: Double {
        editedCarbsPer100g * editedPortionGrams / 100
    }

    var portionFat: Double {
        editedFatPer100g * editedPortionGrams / 100
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - KI-Analyse

    #if canImport(UIKit)
    /// Analysiert ein Foto mit der Claude API
    @MainActor
    func analyzeImage(_ image: UIImage) async {
        capturedImage = image
        userHint = ""
        isAnalyzing = true
        errorMessage = nil
        estimate = nil

        do {
            let result = try await ClaudeAPIService.shared.analyzeFood(image: image)
            estimate = result
            applyEstimate(result)
        } catch {
            errorMessage = error.localizedDescription
        }

        isAnalyzing = false
    }

    /// Analysiert das gespeicherte Bild erneut mit dem Benutzer-Hinweis
    @MainActor
    func reanalyzeWithHint() async {
        guard let image = capturedImage,
              !userHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        isAnalyzing = true
        errorMessage = nil

        do {
            let result = try await ClaudeAPIService.shared.analyzeFood(image: image, userHint: userHint)
            estimate = result
            applyEstimate(result)
            userHint = ""
        } catch {
            errorMessage = error.localizedDescription
        }

        isAnalyzing = false
    }
    #endif

    // MARK: - Plattformuebergreifende Analyse (Data-basiert)

    /// Analysiert Bilddaten mit der Claude API (plattformuebergreifend)
    @MainActor
    func analyzeImageData(_ data: Data) async {
        capturedImageData = data
        userHint = ""
        isAnalyzing = true
        errorMessage = nil
        estimate = nil

        do {
            let result = try await ClaudeAPIService.shared.analyzeFood(imageData: data)
            estimate = result
            applyEstimate(result)
        } catch {
            errorMessage = error.localizedDescription
        }

        isAnalyzing = false
    }

    /// Analysiert die gespeicherten Bilddaten erneut mit dem Benutzer-Hinweis
    @MainActor
    func reanalyzeDataWithHint() async {
        guard let data = capturedImageData,
              !userHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        isAnalyzing = true
        errorMessage = nil

        do {
            let result = try await ClaudeAPIService.shared.analyzeFood(imageData: data, userHint: userHint)
            estimate = result
            applyEstimate(result)
            userHint = ""
        } catch {
            errorMessage = error.localizedDescription
        }

        isAnalyzing = false
    }

    /// Uebernimmt KI-Schaetzung in die editierbaren Felder
    private func applyEstimate(_ est: AIFoodEstimate) {
        editedName = est.name
        editedPortionGrams = est.estimatedWeightGrams
        editedCaloriesPer100g = est.caloriesPer100g
        editedProteinPer100g = est.proteinPer100g
        editedCarbsPer100g = est.carbsPer100g
        editedFatPer100g = est.fatPer100g
        editedFiberPer100g = est.fiberPer100g
    }

    // MARK: - Eintrag erzeugen

    /// Erstellt FoodItem + DiaryEntry aus den (ggf. bearbeiteten) Werten
    func createEntry(date: Date, mealType: MealType) {
        let displayName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)

        let foodItem = FoodItem(
            name: displayName.isEmpty
                ? String(localized: "quick_entry_default_name")
                : displayName,
            caloriesPer100g: editedCaloriesPer100g,
            proteinPer100g: editedProteinPer100g,
            carbsPer100g: editedCarbsPer100g,
            fatPer100g: editedFatPer100g,
            fiberPer100g: editedFiberPer100g
        )
        foodItem.sugarPer100g = estimate?.sugarPer100g ?? 0
        foodItem.saturatedFatPer100g = estimate?.saturatedFatPer100g ?? 0
        foodItem.saltPer100g = estimate?.saltPer100g ?? 0
        foodItem.isQuickEntry = true

        let entry = DiaryEntry(
            date: date,
            mealType: mealType,
            amountGrams: editedPortionGrams,
            foodItem: foodItem
        )

        modelContext.insert(foodItem)
        modelContext.insert(entry)
        try? modelContext.save()
    }
}
