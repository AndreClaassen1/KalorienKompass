//
//  AIFoodEstimate.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 05.02.26.
//

import Foundation

/// KI-geschaetzte Naehrwerte aus einem Mahlzeiten-Foto
nonisolated struct AIFoodEstimate: Codable, Sendable {
    let name: String
    let confidence: String
    let estimatedWeightGrams: Double
    let caloriesPer100g: Double
    let proteinPer100g: Double
    let carbsPer100g: Double
    let fatPer100g: Double
    let fiberPer100g: Double
    let sugarPer100g: Double
    let saturatedFatPer100g: Double
    let saltPer100g: Double
    let totalCalories: Double
    let components: [FoodComponent]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        /// Liest Double tolerant: akzeptiert sowohl Double als auch Int in JSON
        func flexDouble(_ key: CodingKeys, default fallback: Double = 0) throws -> Double {
            if let d = try? c.decode(Double.self, forKey: key) { return d }
            if let i = try? c.decode(Int.self, forKey: key)    { return Double(i) }
            if fallback != 0 { return fallback }
            return try c.decode(Double.self, forKey: key) // wirft DecodingError
        }

        name                = try c.decode(String.self, forKey: .name)
        confidence          = (try? c.decode(String.self, forKey: .confidence)) ?? "medium"
        estimatedWeightGrams = try flexDouble(.estimatedWeightGrams)
        caloriesPer100g     = try flexDouble(.caloriesPer100g)
        proteinPer100g      = try flexDouble(.proteinPer100g)
        carbsPer100g        = try flexDouble(.carbsPer100g)
        fatPer100g          = try flexDouble(.fatPer100g)
        fiberPer100g        = (try? flexDouble(.fiberPer100g)) ?? 0
        sugarPer100g        = (try? flexDouble(.sugarPer100g)) ?? 0
        saturatedFatPer100g = (try? flexDouble(.saturatedFatPer100g)) ?? 0
        saltPer100g         = (try? flexDouble(.saltPer100g)) ?? 0
        totalCalories       = (try? flexDouble(.totalCalories)) ?? 0
        components          = (try? c.decode([FoodComponent].self, forKey: .components)) ?? []
    }

    /// Gesamtkalorien der geschaetzten Portion
    var portionCalories: Double {
        caloriesPer100g * estimatedWeightGrams / 100
    }

    /// Gesamt-Protein der geschaetzten Portion
    var portionProtein: Double {
        proteinPer100g * estimatedWeightGrams / 100
    }

    /// Gesamt-Kohlenhydrate der geschaetzten Portion
    var portionCarbs: Double {
        carbsPer100g * estimatedWeightGrams / 100
    }

    /// Gesamt-Fett der geschaetzten Portion
    var portionFat: Double {
        fatPer100g * estimatedWeightGrams / 100
    }

    /// Konfidenz-Level als Enum
    var confidenceLevel: ConfidenceLevel {
        ConfidenceLevel(rawValue: confidence) ?? .medium
    }
}


/// Einzelne Zutat einer erkannten Mahlzeit
struct FoodComponent: Codable, Sendable {
    let name: String
    let estimatedGrams: Double
}

/// Konfidenz-Stufen der KI-Erkennung
enum ConfidenceLevel: String, Codable, Sendable {
    case high, medium, low

    var dots: Int {
        switch self {
        case .high: 3
        case .medium: 2
        case .low: 1
        }
    }

    var localizedName: String {
        switch self {
        case .high: String(localized: "ai_confidence_high")
        case .medium: String(localized: "ai_confidence_medium")
        case .low: String(localized: "ai_confidence_low")
        }
    }
}
