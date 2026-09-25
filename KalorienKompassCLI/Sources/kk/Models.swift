import Foundation

// MARK: - MealType CLI-Erweiterungen
// Die eigentliche MealType-Definition kommt aus SharedLinks/MealType.swift
// (Symlink auf Shared/Model/MealType.swift — single source of truth).

extension MealType {
    /// Deutscher Kurzname fuer CLI-Ausgabe (ohne Localizable.xcstrings-Abhaengigkeit).
    var displayName: String {
        switch self {
        case .breakfast:       "Frühstück"
        case .secondBreakfast: "Zweites Frühstück"
        case .lunch:           "Mittagessen"
        case .coffeeBreak:     "Kaffeepause"
        case .dinner:          "Abendessen"
        case .snack:           "Snack"
        }
    }

    /// Die kanonischen `--meal`-Werte, wie sie in Hilfe und Fehlermeldungen erscheinen.
    static let cliNameHint = "breakfast, second-breakfast, lunch, coffee, dinner, snack"

    /// Parst den CLI --meal Parameter (deutsch/englisch, diverse Aliasse).
    static func from(string: String) throws -> MealType {
        switch string.lowercased() {
        case "breakfast", "fruehstueck", "frühstück":   return .breakfast
        case "second-breakfast", "secondbreakfast",
             "zweites-fruehstueck":                     return .secondBreakfast
        case "lunch", "mittagessen", "mittag":          return .lunch
        case "coffee", "coffeebreak", "coffee-break",
             "kaffeepause":                             return .coffeeBreak
        case "dinner", "abendessen", "abend":           return .dinner
        case "snack":                                   return .snack
        default:
            if let m = MealType(rawValue: string) { return m }
            throw KKError("Unbekannter Mahlzeitstyp: \(string). Erlaubt: \(cliNameHint)")
        }
    }
}

// MARK: - AIFoodEstimate
// Kopie aus Shared/Model/AIFoodEstimate.swift fuer Claude-Antworten

struct AIFoodEstimate: Codable, Sendable {
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

        func flexDouble(_ key: CodingKeys, default fallback: Double = 0) throws -> Double {
            if let d = try? c.decode(Double.self, forKey: key) { return d }
            if let i = try? c.decode(Int.self,    forKey: key) { return Double(i) }
            if fallback != 0 { return fallback }
            return try c.decode(Double.self, forKey: key)
        }

        name                 = try c.decode(String.self, forKey: .name)
        confidence           = (try? c.decode(String.self, forKey: .confidence)) ?? "medium"
        estimatedWeightGrams = try flexDouble(.estimatedWeightGrams)
        caloriesPer100g      = try flexDouble(.caloriesPer100g)
        proteinPer100g       = try flexDouble(.proteinPer100g)
        carbsPer100g         = try flexDouble(.carbsPer100g)
        fatPer100g           = try flexDouble(.fatPer100g)
        fiberPer100g         = (try? flexDouble(.fiberPer100g))        ?? 0
        sugarPer100g         = (try? flexDouble(.sugarPer100g))        ?? 0
        saturatedFatPer100g  = (try? flexDouble(.saturatedFatPer100g)) ?? 0
        saltPer100g          = (try? flexDouble(.saltPer100g))         ?? 0
        totalCalories        = (try? flexDouble(.totalCalories))       ?? 0
        components           = (try? c.decode([FoodComponent].self, forKey: .components)) ?? []
    }

    var portionCalories: Double { caloriesPer100g * estimatedWeightGrams / 100 }
    var portionProtein: Double  { proteinPer100g  * estimatedWeightGrams / 100 }
    var portionCarbs: Double    { carbsPer100g    * estimatedWeightGrams / 100 }
    var portionFat: Double      { fatPer100g      * estimatedWeightGrams / 100 }
}

struct FoodComponent: Codable, Sendable {
    let name: String
    let estimatedGrams: Double
}
