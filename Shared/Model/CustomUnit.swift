//
//  CustomUnit.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 05.02.26.
//

import Foundation
import SwiftData

/// Benutzerdefinierte Einheit fuer ein Lebensmittel (z.B. "Scheibe" = 45g)
@Model
public class CustomUnit {
    /// Name der Einheit (z.B. "Scheibe", "Packung", "Stueck")
    var name: String = ""

    /// Gramm pro Einheit
    var gramsPerUnit: Double = 100

    /// Sortierreihenfolge
    var sortOrder: Int = 0

    /// Zugehoerige Anpassung
    var customization: FoodCustomization?

    init(name: String, gramsPerUnit: Double, sortOrder: Int = 0) {
        self.name = name
        self.gramsPerUnit = gramsPerUnit
        self.sortOrder = sortOrder
    }
}
