//
//  FocusLeverTrigger.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 20.07.26.
//

import Foundation

/// Entscheidet, wann der Hebel hervorgehoben wird.
///
/// Ein permanenter Hinweis ist nach drei Tagen unsichtbar (Banner-Blindheit).
/// Der Hebel bleibt deshalb dauerhaft als dezente Zeile sichtbar und
/// wird nur dann hervorgehoben, wenn die Situation zu ihr passt: am Abend oder
/// direkt nach dem Buchen eines Snacks bzw. Abendessens.
enum FocusLeverTrigger {

    /// Mahlzeiten, bei denen `triggerOnSnack` greift.
    static let snackMealTypes: Set<MealType> = [.snack, .dinner]

    /// Soll der Hebel gerade hervorgehoben werden?
    /// - Parameters:
    ///   - lever: der aktive Hebel
    ///   - now: aktueller Zeitpunkt
    ///   - lastBookedMeal: zuletzt gebuchte Mahlzeit dieser Sitzung, sonst `nil`
    static func isHighlighted(lever: FocusLever, now: Date = Date(), lastBookedMeal: MealType? = nil) -> Bool {
        if let lastBookedMeal, lever.triggerOnSnack, snackMealTypes.contains(lastBookedMeal) {
            return true
        }
        let hour = Calendar.current.component(.hour, from: now)
        return hour >= lever.triggerStartHour
    }
}
