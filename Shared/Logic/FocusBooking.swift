//
//  FocusBooking.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 13.07.26.
//
//  Buchungslogik des Fokus-Modus: erzeugt aus EINER KI-Schaetzung genau EINEN
//  Eintrag (ein Produkt = ein Eintrag), und nimmt eine Charge auch wieder zurueck
//  oder bucht sie um. Genutzt vom FocusViewModel (App), vom AIFocusLogIntent
//  (Siri/Shortcuts) samt dessen Snippet-Knoepfen, und von der Watch.
//

import Foundation
import SwiftData

enum FocusBooking {

    /// Bucht eine KI-Schaetzung als genau einen Eintrag und gibt ihn zurueck.
    ///
    /// - Parameter amountGrams: uebersteuert die geschaetzte Portion. Die Uhr laesst
    ///   sie vor dem Buchen anpassen; sonst gilt die Schaetzung.
    @discardableResult
    static func book(
        estimate: AIFoodEstimate,
        meal: MealType,
        date: Date,
        amountGrams: Double? = nil,
        context: ModelContext
    ) -> DiaryEntry {
        let name = estimate.name.trimmingCharacters(in: .whitespacesAndNewlines)

        let foodItem = FoodItem(
            name: name.isEmpty ? String(localized: "quick_entry_default_name") : name,
            caloriesPer100g: estimate.caloriesPer100g,
            proteinPer100g:  estimate.proteinPer100g,
            carbsPer100g:    estimate.carbsPer100g,
            fatPer100g:      estimate.fatPer100g,
            fiberPer100g:    estimate.fiberPer100g,
            sugarPer100g:    estimate.sugarPer100g,
            saturatedFatPer100g: estimate.saturatedFatPer100g,
            saltPer100g:     estimate.saltPer100g
        )
        foodItem.isQuickEntry = true

        let entry = DiaryEntry(
            date: date,
            mealType: meal,
            amountGrams: max(amountGrams ?? estimate.estimatedWeightGrams, 1),
            foodItem: foodItem
        )
        context.insert(foodItem)
        context.insert(entry)
        try? context.save()
        return entry
    }

    /// Legt aus den KI-Schaetzungen einer Eingabe EINEN geplanten Eintrag an
    /// (Issue #99, Planungsmodus der Fokus-Eingabe).
    ///
    /// Mehrere Speisen werden zu einem Plan zusammengefasst: geplant wird die
    /// Mahlzeit als Ganzes, nicht ihre Komponenten. Die per-100g-Werte entstehen
    /// aus den gewichteten Gesamtmengen, damit Kalorien und Makros der Summe
    /// der Einzelschaetzungen entsprechen.
    @discardableResult
    static func plan(
        estimates: [AIFoodEstimate],
        meal: MealType,
        date: Date,
        context: ModelContext
    ) -> PlannedEntry? {
        guard !estimates.isEmpty else { return nil }

        let grams = estimates.map { max($0.estimatedWeightGrams, 1) }
        let totalGrams = grams.reduce(0, +)
        func per100(_ value: (AIFoodEstimate) -> Double) -> Double {
            zip(estimates, grams).reduce(0) { $0 + value($1.0) * $1.1 } / totalGrams
        }

        let names = estimates
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let name = names.isEmpty
            ? String(localized: "quick_entry_default_name")
            : names.joined(separator: ", ")

        let foodItem = FoodItem(
            name: name,
            caloriesPer100g: per100 { $0.caloriesPer100g },
            proteinPer100g:  per100 { $0.proteinPer100g },
            carbsPer100g:    per100 { $0.carbsPer100g },
            fatPer100g:      per100 { $0.fatPer100g },
            fiberPer100g:    per100 { $0.fiberPer100g },
            sugarPer100g:    per100 { $0.sugarPer100g },
            saturatedFatPer100g: per100 { $0.saturatedFatPer100g },
            saltPer100g:     per100 { $0.saltPer100g }
        )
        foodItem.isQuickEntry = true
        context.insert(foodItem)

        let plan = PlannedEntry.setPlan(
            foodItem: foodItem,
            date: date,
            mealType: meal,
            amountGrams: totalGrams,
            in: context
        )
        try? context.save()
        return plan
    }

    /// Nimmt eine gebuchte Charge zurueck: loescht die Eintraege und die dazu
    /// angelegten Schnell-Lebensmittel.
    ///
    /// Liegt hier und nicht im FocusViewModel, weil auch Siri zuruecknehmen
    /// koennen muss — dort gibt es kein ViewModel (Issue #74).
    ///
    /// - Returns: die Zahl der geloeschten Eintraege.
    @discardableResult
    static func undo(entryIds: [String], foodItemIds: [String], context: ModelContext) -> Int {
        let entries = entries(with: entryIds, context: context)
        guard !entries.isEmpty else { return 0 }
        for entry in entries { context.delete(entry) }

        if !foodItemIds.isEmpty {
            let foods = (try? context.fetch(
                FetchDescriptor<FoodItem>(predicate: #Predicate { foodItemIds.contains($0.itemId) })
            )) ?? []
            for food in foods { context.delete(food) }
        }

        try? context.save()
        return entries.count
    }

    /// Ordnet gebuchte Eintraege einer anderen Mahlzeit zu.
    ///
    /// - Returns: die Zahl der geaenderten Eintraege.
    @discardableResult
    static func move(entryIds: [String], to meal: MealType, context: ModelContext) -> Int {
        let entries = entries(with: entryIds, context: context)
        guard !entries.isEmpty else { return 0 }
        for entry in entries { entry.mealType = meal }

        try? context.save()
        return entries.count
    }

    /// Laedt gebuchte Eintraege in der Reihenfolge ihrer Erstellung.
    /// Leer, wenn die Charge inzwischen zurueckgenommen wurde.
    static func entries(with entryIds: [String], context: ModelContext) -> [DiaryEntry] {
        guard !entryIds.isEmpty else { return [] }
        let found = (try? context.fetch(
            FetchDescriptor<DiaryEntry>(
                predicate: #Predicate<DiaryEntry> { entryIds.contains($0.entryId) },
                sortBy: [SortDescriptor(\.createdAt)]
            )
        )) ?? []
        return found
    }
}
