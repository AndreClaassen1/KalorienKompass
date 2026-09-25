//
//  FoodItem.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import Foundation
import SwiftData

/// Lebensmittel-Stammdaten (lokal gespeichert nach erstem Abruf von OpenFoodFacts)
@Model
public class FoodItem {
    #Index<FoodItem>([\.barcode], [\.name])

    /// Eindeutiger Bezeichner
    var itemId: String = UUID().uuidString

    /// Produktname
    var name: String = ""

    /// Marke / Hersteller
    var brand: String?

    /// EAN/UPC Barcode (optional, kann auch manuell angelegt werden)
    var barcode: String?

    /// Kalorien pro 100g
    var caloriesPer100g: Double = 0

    /// Protein pro 100g (in Gramm)
    var proteinPer100g: Double = 0

    /// Kohlenhydrate pro 100g (in Gramm)
    var carbsPer100g: Double = 0

    /// Fett pro 100g (in Gramm)
    var fatPer100g: Double = 0

    /// Ballaststoffe pro 100g (in Gramm)
    var fiberPer100g: Double = 0

    /// Zucker pro 100g (in Gramm)
    var sugarPer100g: Double = 0

    /// Gesaettigte Fettsaeuren pro 100g (in Gramm)
    var saturatedFatPer100g: Double = 0

    /// Salz pro 100g (in Gramm)
    var saltPer100g: Double = 0

    /// Standard-Portionsgroesse in Gramm
    var defaultServingSizeGrams: Double = 100

    /// Bezeichnung der Standardportion (z.B. "1 Scheibe", "1 Stueck")
    var servingDescription: String?

    /// OpenFoodFacts Produkt-URL (fuer Quellenangabe)
    var sourceURL: String?

    /// Bild-URL des Produkts
    var imageURL: String?

    /// Zeitpunkt des letzten Abrufs
    var lastFetched: Date?

    /// Manuell vom Benutzer angelegt (nicht von OFF)
    var isUserCreated: Bool = false

    /// Schnelleintrag ohne Produktbezug (nicht in Suche anzeigen)
    var isQuickEntry: Bool = false

    /// Zugehoerige Tagebucheintraege
    @Relationship(deleteRule: .cascade, inverse: \DiaryEntry.foodItem)
    var diaryEntries: [DiaryEntry]?

    /// Zugehoerige geplante Eintraege (Issue #99). CloudKit verlangt fuer jede
    /// Relation ein explizites Inverse.
    @Relationship(deleteRule: .cascade, inverse: \PlannedEntry.foodItem)
    var plannedEntries: [PlannedEntry]?

    /// Gefilterte gueltige Eintraege (Schutz vor geloeschten Kontexten)
    var validEntries: [DiaryEntry] {
        (diaryEntries ?? []).filter { $0.modelContext != nil }
    }

    init(
        name: String,
        brand: String? = nil,
        barcode: String? = nil,
        caloriesPer100g: Double = 0,
        proteinPer100g: Double = 0,
        carbsPer100g: Double = 0,
        fatPer100g: Double = 0,
        fiberPer100g: Double = 0,
        sugarPer100g: Double = 0,
        saturatedFatPer100g: Double = 0,
        saltPer100g: Double = 0,
        defaultServingSizeGrams: Double = 100,
        servingDescription: String? = nil
    ) {
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.fiberPer100g = fiberPer100g
        self.sugarPer100g = sugarPer100g
        self.saturatedFatPer100g = saturatedFatPer100g
        self.saltPer100g = saltPer100g
        self.defaultServingSizeGrams = defaultServingSizeGrams
        self.servingDescription = servingDescription
    }
}
