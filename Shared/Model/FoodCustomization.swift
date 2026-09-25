//
//  FoodCustomization.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 05.02.26.
//

import Foundation
import SwiftData

/// Benutzerdefinierte Anpassungen fuer ein Lebensmittel (Favoriten, eigene Einheiten).
/// Getrennt von FoodItem gespeichert, damit Offline-DB-Updates die Daten nicht ueberschreiben.
@Model
public class FoodCustomization {
    /// Barcode des Lebensmittels (stabiler Schluessel fuer OFF-Produkte)
    var barcode: String?

    /// FoodItem-ID als Fallback (fuer Produkte ohne Barcode / Schnelleintraege)
    var foodItemId: String = ""

    /// Ist dieses Lebensmittel als Favorit markiert?
    var isFavorite: Bool = true

    /// Optionaler eigener Name (z.B. "Unser Hausbrot")
    var customName: String?

    /// Zeitpunkt der Erstellung
    var createdAt: Date = Date()

    /// Benutzerdefinierte Einheiten
    @Relationship(deleteRule: .cascade, inverse: \CustomUnit.customization)
    var customUnits: [CustomUnit]?

    /// Sortierte Einheiten
    var sortedUnits: [CustomUnit] {
        (customUnits ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    init(barcode: String? = nil, foodItemId: String = "") {
        self.barcode = barcode
        self.foodItemId = foodItemId
    }
}
