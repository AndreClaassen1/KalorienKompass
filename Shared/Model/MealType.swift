//
//  MealType.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import Foundation
import SwiftUI

/// Mahlzeitentypen fuer die Kategorisierung von Tagebucheintraegen
enum MealType: String, CaseIterable, Identifiable, Codable, Sendable {
    case breakfast = "breakfast"
    case secondBreakfast = "secondBreakfast"
    case lunch = "lunch"
    case coffeeBreak = "coffeeBreak"
    case dinner = "dinner"
    case snack = "snack"

    var id: String { rawValue }

    /// Lokalisierter Anzeigename (fuer SwiftUI Views)
    var localizedName: LocalizedStringKey {
        switch self {
        case .breakfast: "meal_breakfast"
        case .secondBreakfast: "meal_second_breakfast"
        case .lunch: "meal_lunch"
        case .coffeeBreak: "meal_coffee_break"
        case .dinner: "meal_dinner"
        case .snack: "meal_snack"
        }
    }

    /// Lokalisierter Anzeigename als String (fuer Notifications und String-Interpolation)
    var localizedString: String {
        switch self {
        case .breakfast: String(localized: "meal_breakfast")
        case .secondBreakfast: String(localized: "meal_second_breakfast")
        case .lunch: String(localized: "meal_lunch")
        case .coffeeBreak: String(localized: "meal_coffee_break")
        case .dinner: String(localized: "meal_dinner")
        case .snack: String(localized: "meal_snack")
        }
    }

    /// SF Symbol fuer die Mahlzeit
    var symbolName: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .secondBreakfast: "sun.and.horizon.fill"
        case .lunch: "sun.max.fill"
        case .coffeeBreak: "cup.and.saucer.fill"
        case .dinner: "moon.fill"
        case .snack: "leaf.fill"
        }
    }

    /// Sortierreihenfolge
    var sortOrder: Int {
        switch self {
        case .breakfast: 0
        case .secondBreakfast: 1
        case .lunch: 2
        case .coffeeBreak: 3
        case .dinner: 4
        case .snack: 5
        }
    }

    /// Anteil am Tagesbudget (Summe = 1.0)
    var budgetWeight: Double {
        switch self {
        case .breakfast: 0.25
        case .secondBreakfast: 0.10
        case .lunch: 0.30
        case .coffeeBreak: 0.05
        case .dinner: 0.25
        case .snack: 0.05
        }
    }

    /// Leitet den passenden Mahlzeit-Typ aus einer Tagesstunde ab.
    static func forHour(_ hour: Int) -> MealType {
        switch hour {
        case 5..<10:  return .breakfast
        case 10..<12: return .secondBreakfast
        case 12..<15: return .lunch
        // Kaffeepause bewusst nur zwei Stunden: wer um kurz nach fuenf isst, meint
        // in aller Regel das Abendessen, nicht eine Nebenmahlzeit (Issue #79).
        case 15..<17: return .coffeeBreak
        case 17..<22: return .dinner
        default:      return .snack
        }
    }

    /// Leitet den passenden Mahlzeit-Typ aus der aktuellen Tageszeit ab.
    ///
    /// Nur fuer Eintraege am heutigen Tag sinnvoll. Bei rueckwirkenden Buchungen
    /// sagt die jetzige Uhrzeit nichts ueber die Mahlzeit aus, dort `forHour(_:)`
    /// mit der tatsaechlichen Essenszeit nutzen.
    static var currentBasedOnTime: MealType {
        forHour(Calendar.current.component(.hour, from: Date()))
    }

    /// Ziel-Mahlzeit fuer einen Plan (Issue #99): geplant wird nicht die
    /// jetzige, sondern die NAECHSTE Hauptmahlzeit. Drei Stunden Versatz ueber
    /// das Stundenraster, dann auf die Hauptmahlzeit aufgerundet —
    /// Nebenmahlzeiten plant niemand vor. Spaet abends bleibt es beim
    /// Abendessen, tief in der Nacht zielt der Plan aufs Fruehstueck.
    static func planningTarget(forHour hour: Int) -> MealType {
        let shifted = forHour((hour + 3) % 24)
        switch shifted {
        case .secondBreakfast: return .lunch
        case .coffeeBreak:     return .dinner
        case .snack:           return hour >= 19 ? .dinner : .breakfast
        default:               return shifted
        }
    }

    /// Ziel-Mahlzeit fuer einen Plan zur aktuellen Uhrzeit.
    static var planningTargetBasedOnTime: MealType {
        planningTarget(forHour: Calendar.current.component(.hour, from: Date()))
    }

    /// Hauptmahlzeit (immer sichtbar). Nebenmahlzeiten (2. Fruehstueck, Kaffeepause)
    /// erscheinen nur bei Bedarf.
    var isPrimaryMeal: Bool {
        switch self {
        case .breakfast, .lunch, .dinner, .snack: true
        case .secondBreakfast, .coffeeBreak: false
        }
    }

    /// Alle Faelle in Sortierreihenfolge.
    static var sortedCases: [MealType] {
        allCases.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Sichtbare Mahlzeiten nach der App-Regel: Hauptmahlzeiten immer,
    /// Nebenmahlzeiten nur wenn `showAll` oder Eintraege vorhanden.
    static func visibleTypes(showAll: Bool, hasEntries: (MealType) -> Bool) -> [MealType] {
        sortedCases.filter { $0.isPrimaryMeal || showAll || hasEntries($0) }
    }
}
