import Foundation
import SwiftData
import Testing
@testable import kk

@Suite("Store.moveEntries")
struct StoreMoveTests {

    private let day    = noon("2026-09-05")
    private let target = noon("2026-09-04")

    /// Drei Eintraege am Quelltag, in der Reihenfolge Brot, Kaese, Butter.
    private func storeWithThreeLunchEntries() throws -> Store {
        let store = try Store.inMemory()
        try store.addTestEntries([
            (name: "Roggenbrot", calories: 215, grams: 80, meal: .lunch),
            (name: "Rohkäse",    calories: 355, grams: 40, meal: .lunch),
            (name: "Butter",     calories: 713, grams: 15, meal: .lunch),
        ], on: day)
        return store
    }

    // MARK: - Mahlzeit wechseln

    @Test("Eine Nummer bekommt die neue Mahlzeit, die uebrigen bleiben unberuehrt")
    func movesSingleNumber() throws {
        let store = try storeWithThreeLunchEntries()

        let moved = try store.moveEntries(on: day, selecting: .numbers([2]), toMeal: .breakfast)

        #expect(moved.count == 1)
        #expect(moved[0].name == "Rohkäse")
        #expect(moved[0].fromMeal == .lunch)
        #expect(moved[0].toMeal == .breakfast)

        let meals = try store.entries(on: day).map(\.mealType)
        #expect(meals == [.lunch, .breakfast, .lunch])
    }

    @Test("Mehrere Nummern auf einmal")
    func movesSeveralNumbers() throws {
        let store = try storeWithThreeLunchEntries()

        let moved = try store.moveEntries(on: day, selecting: .numbers([1, 2, 3]), toMeal: .breakfast)

        #expect(moved.count == 3)
        #expect(try store.entries(on: day).allSatisfy { $0.mealType == .breakfast })
    }

    @Test("Auswahl ueber die Mahlzeit trifft genau deren Eintraege")
    func movesWholeMeal() throws {
        let store = try storeWithThreeLunchEntries()
        try store.addTestEntries([(name: "Apfel", calories: 52, grams: 150, meal: .snack)],
                                 on: day, startingAt: 3)

        let moved = try store.moveEntries(on: day, selecting: .meal(.lunch), toMeal: .breakfast)

        #expect(moved.count == 3)
        let entries = try store.entries(on: day)
        #expect(entries.filter { $0.mealType == .breakfast }.count == 3)
        #expect(entries.last?.mealType == .snack)
    }

    // MARK: - Tag wechseln

    @Test("Ein Eintrag verschwindet aus dem Quelltag und liegt am Zieltag")
    func movesToAnotherDay() throws {
        let store = try storeWithThreeLunchEntries()
        let moved = try store.moveEntries(on: day, selecting: .numbers([1]), toDate: target)

        #expect(moved[0].changedDate)
        #expect(moved[0].changedMeal == false)
        #expect(try store.entries(on: day).count == 2)
        #expect(try store.entries(on: target).map { $0.foodItem?.name } == ["Roggenbrot"])
    }

    @Test("Das Zieldatum wird auf den Tagesbeginn normalisiert")
    func normalizesTargetDateToStartOfDay() throws {
        let store = try storeWithThreeLunchEntries()
        try store.moveEntries(on: day, selecting: .numbers([1]), toDate: target)

        let movedEntry = try #require(try store.entries(on: target).first)
        #expect(movedEntry.date == target.startOfDay)
    }

    @Test("Mahlzeit und Tag lassen sich in einem Zug aendern")
    func movesMealAndDayTogether() throws {
        let store = try storeWithThreeLunchEntries()
        let moved = try store.moveEntries(on: day, selecting: .numbers([3]),
                                          toMeal: .dinner, toDate: target)

        #expect(moved[0].changedMeal)
        #expect(moved[0].changedDate)
        let movedEntry = try #require(try store.entries(on: target).first)
        #expect(movedEntry.mealType == .dinner)
    }

    @Test("Ein Zieltag ohne Eintraege bekommt genau diesen einen")
    func fillsEmptyTargetDay() throws {
        let store = try storeWithThreeLunchEntries()
        let empty = noon("2026-09-03")

        try store.moveEntries(on: day, selecting: .numbers([2]), toMeal: .dinner, toDate: empty)

        #expect(try store.entries(on: empty).count == 1)
    }

    // MARK: - Was unangetastet bleibt

    @Test("createdAt bleibt unveraendert, sonst zeigt kk undo auf einen fremden Eintrag")
    func keepsCreatedAt() throws {
        let store = try storeWithThreeLunchEntries()
        let before = try store.entries(on: day).map(\.createdAt)

        try store.moveEntries(on: day, selecting: .numbers([1, 2, 3]),
                              toMeal: .dinner, toDate: target)

        let after = try store.entries(on: target).map(\.createdAt)
        #expect(after == before)
    }

    @Test("kk undo trifft nach einem Umhaengen weiterhin den zuletzt erfassten Eintrag")
    func undoStillHitsTheNewestEntry() throws {
        let store = try storeWithThreeLunchEntries()

        try store.moveEntries(on: day, selecting: .numbers([1]), toDate: target)
        let deleted = try store.deleteLastEntry()

        #expect(deleted?.name == "Butter")
    }

    @Test("Naehrwerte und Menge bleiben, wo loeschen und neu erfassen sie neu schaetzen wuerde")
    func keepsFoodItemAndAmount() throws {
        let store = try storeWithThreeLunchEntries()

        try store.moveEntries(on: day, selecting: .numbers([2]), toMeal: .breakfast)

        let entry = try #require(try store.entries(on: day).first { $0.foodItem?.name == "Rohkäse" })
        #expect(entry.amountGrams == 40)
        #expect(entry.foodItem?.caloriesPer100g == 355)
        #expect(Int(entry.calories) == 142)
    }

    // MARK: - Fehlerfaelle, jeweils ohne Nebenwirkung

    @Test("Ein leerer Quelltag meldet sich, statt still nichts zu tun")
    func rejectsEmptyDay() throws {
        let store = try Store.inMemory()

        #expect(throws: Store.MoveError.emptyDay) {
            try store.moveEntries(on: day, selecting: .numbers([1]), toMeal: .dinner)
        }
    }

    @Test("Unbekannte Nummern werden gemeldet", arguments: [0, -1, 4, 99])
    func rejectsUnknownNumber(_ number: Int) throws {
        let store = try storeWithThreeLunchEntries()

        #expect(throws: Store.MoveError.unknownNumbers([number], available: 3)) {
            try store.moveEntries(on: day, selecting: .numbers([number]), toMeal: .dinner)
        }
    }

    @Test("Eine Mahlzeit ohne Eintraege wird gemeldet")
    func rejectsEmptyMeal() throws {
        let store = try storeWithThreeLunchEntries()

        #expect(throws: Store.MoveError.noEntriesInMeal(.dinner)) {
            try store.moveEntries(on: day, selecting: .meal(.dinner), toMeal: .breakfast)
        }
    }

    @Test("Eine falsche Nummer laesst auch die gueltigen Eintraege unberuehrt")
    func isAllOrNothing() throws {
        let store = try storeWithThreeLunchEntries()
        let before = try store.entries(on: day).map { ($0.mealType, $0.date) }

        #expect(throws: Store.MoveError.self) {
            try store.moveEntries(on: day, selecting: .numbers([1, 99]), toMeal: .breakfast)
        }

        let after = try store.entries(on: day).map { ($0.mealType, $0.date) }
        #expect(after.map(\.0) == before.map(\.0))
        #expect(after.map(\.1) == before.map(\.1))
    }

    // MARK: - Robustheit der Auswahl

    @Test("Eine doppelt genannte Nummer wird einmal umgehaengt")
    func ignoresDuplicateNumbers() throws {
        let store = try storeWithThreeLunchEntries()

        let moved = try store.moveEntries(on: day, selecting: .numbers([2, 2]), toMeal: .breakfast)

        #expect(moved.count == 1)
    }

    @Test("Die Ausgabe folgt der Tagesliste, nicht der Eingabereihenfolge")
    func returnsInDayListOrder() throws {
        let store = try storeWithThreeLunchEntries()

        let moved = try store.moveEntries(on: day, selecting: .numbers([3, 1]), toMeal: .breakfast)

        #expect(moved.map(\.name) == ["Roggenbrot", "Butter"])
    }

    @Test("Die alte Mahlzeit noch einmal setzen ist kein Fehler, aendert aber nichts")
    func reportsNoOp() throws {
        let store = try storeWithThreeLunchEntries()

        let moved = try store.moveEntries(on: day, selecting: .numbers([1]), toMeal: .lunch)

        #expect(moved[0].changedAnything == false)
    }
}

@Suite("Store-Initialisierung")
struct StoreInitTests {

    @Test("Ein Pfad ins Leere meldet die fehlende Datenbank, statt sie anzulegen")
    func rejectsMissingStoreFile() throws {
        let missing = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kk-tests-\(UUID().uuidString)")
            .appendingPathComponent("default.store")

        #expect(throws: KKError.self) {
            _ = try Store(url: missing)
        }
    }
}
