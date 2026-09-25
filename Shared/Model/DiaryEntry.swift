//
//  DiaryEntry.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import Foundation
import SwiftData

/// Ein einzelner Eintrag im Ernaehrungstagebuch
@Model
public class DiaryEntry {
    #Index<DiaryEntry>([\.date], [\.mealTypeRaw])

    /// Eindeutiger Bezeichner
    var entryId: String = UUID().uuidString

    /// Datum des Eintrags (nur Datum, ohne Uhrzeit)
    var date: Date = Date()

    /// Mahlzeitentyp als String (CloudKit-kompatibel)
    var mealTypeRaw: String = MealType.snack.rawValue

    /// Mahlzeitentyp (Computed Property)
    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }

    /// Menge in Gramm
    var amountGrams: Double = 100

    /// Anzahl Portionen (alternative Eingabe)
    var servings: Double = 1.0

    /// Zeitpunkt der Erstellung
    var createdAt: Date = Date()

    /// Referenz auf das Lebensmittel
    var foodItem: FoodItem?

    // MARK: - Berechnete Naehrwerte

    /// Kalorien fuer die eingetragene Menge
    var calories: Double {
        guard let food = foodItem else { return 0 }
        return food.caloriesPer100g * amountGrams / 100.0
    }

    /// Protein fuer die eingetragene Menge (in Gramm)
    var protein: Double {
        guard let food = foodItem else { return 0 }
        return food.proteinPer100g * amountGrams / 100.0
    }

    /// Kohlenhydrate fuer die eingetragene Menge (in Gramm)
    var carbs: Double {
        guard let food = foodItem else { return 0 }
        return food.carbsPer100g * amountGrams / 100.0
    }

    /// Fett fuer die eingetragene Menge (in Gramm)
    var fat: Double {
        guard let food = foodItem else { return 0 }
        return food.fatPer100g * amountGrams / 100.0
    }

    /// Ballaststoffe fuer die eingetragene Menge (in Gramm)
    var fiber: Double {
        guard let food = foodItem else { return 0 }
        return food.fiberPer100g * amountGrams / 100.0
    }

    /// Zucker fuer die eingetragene Menge (in Gramm)
    var sugar: Double {
        guard let food = foodItem else { return 0 }
        return food.sugarPer100g * amountGrams / 100.0
    }

    /// Gesaettigte Fettsaeuren fuer die eingetragene Menge (in Gramm)
    var saturatedFat: Double {
        guard let food = foodItem else { return 0 }
        return food.saturatedFatPer100g * amountGrams / 100.0
    }

    /// Salz fuer die eingetragene Menge (in Gramm)
    var salt: Double {
        guard let food = foodItem else { return 0 }
        return food.saltPer100g * amountGrams / 100.0
    }

    init(
        date: Date = Date(),
        mealType: MealType = .snack,
        amountGrams: Double = 100,
        servings: Double = 1.0,
        foodItem: FoodItem? = nil
    ) {
        self.date = date.startOfDay
        self.mealTypeRaw = mealType.rawValue
        self.amountGrams = amountGrams
        self.servings = servings
        self.foodItem = foodItem
    }
}
