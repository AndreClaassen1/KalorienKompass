//
//  MealTypeAppEnum.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 20.02.26.
//

import AppIntents

// MARK: - MealType AppEnum

/// AppEnum-Wrapper fuer MealType, damit Siri die Mahlzeiten kennt
enum MealTypeAppEnum: String, AppEnum {
    case breakfast
    case secondBreakfast
    case lunch
    case coffeeBreak
    case dinner
    case snack

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Mahlzeit"
    }

    static var caseDisplayRepresentations: [MealTypeAppEnum: DisplayRepresentation] {
        [
            .breakfast: "Frühstück",
            .secondBreakfast: "Zweites Frühstück",
            .lunch: "Mittagessen",
            .coffeeBreak: "Kaffeepause",
            .dinner: "Abendessen",
            .snack: "Snack"
        ]
    }

    /// Konvertiert zum internen MealType
    var mealType: MealType {
        MealType(rawValue: rawValue) ?? .snack
    }

    init(mealType: MealType) {
        self = MealTypeAppEnum(rawValue: mealType.rawValue) ?? .snack
    }
}
