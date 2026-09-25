import Foundation
import SwiftData
import Testing
@testable import kk

// MARK: - Store im Arbeitsspeicher

extension Store {
    /// Frischer, leerer Store im Arbeitsspeicher. Jeder Test bekommt seinen eigenen,
    /// darum sind parallele Testlaeufe unkritisch und kein Test kann je den
    /// Produktivstore sehen (anders als bei einem Umweg ueber KK_STORE_PATH).
    static func inMemory() throws -> Store {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return Store(container: try ModelContainer(for: Store.schema, configurations: config))
    }

    /// Legt Eintraege eines Tages in fester Reihenfolge an. `createdAt` bekommt einen
    /// festen Abstand, damit die Nummerierung der Tagesliste eindeutig ist; ohne das
    /// haengt sie an der Systemuhr und zwei Eintraege koennen im selben Augenblick
    /// entstehen.
    func addTestEntries(
        _ items: [(name: String, calories: Double, grams: Double, meal: MealType)],
        on date: Date,
        startingAt offset: Int = 0
    ) throws {
        for (n, item) in items.enumerated() {
            _ = try addEntry(
                name: item.name,
                caloriesPer100g: item.calories,
                amountGrams: item.grams,
                mealType: item.meal,
                date: date,
                createdAt: Self.testEpoch.addingTimeInterval(Double(offset + n) * 60)
            )
        }
    }

    /// Fester Bezugspunkt fuer `createdAt` in Tests.
    static let testEpoch = Date(timeIntervalSince1970: 1_750_000_000)
}

// MARK: - Datumshelfer

/// Tagesmitte, genau wie `Commands.parseDate` sie aus einer Nutzereingabe macht.
/// Bewusst ueber die Produktivfunktion, damit die Tests nicht gegen eine Nachbildung laufen.
func noon(_ iso: String) -> Date {
    let f = DateFormatter()
    f.locale     = Locale(identifier: "en_US_POSIX")
    f.timeZone   = .current
    f.dateFormat = "yyyy-MM-dd"
    return Commands.dayNoon(f.date(from: iso)!)
}
