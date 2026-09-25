import Foundation
import Testing
@testable import kk

@Suite("Store.itemsNeedingNutrientRepair")
struct StoreRepairTests {

    private let day   = noon("2026-09-05")
    private let other = noon("2026-09-04")

    @Test("Mit Datum nur die lückenhaften Lebensmittel dieses Tages")
    func restrictsToDay() throws {
        let store = try Store.inMemory()
        _ = try store.addEntry(name: "Gouda", caloriesPer100g: 356, fatPer100g: 27.4, date: day)
        _ = try store.addEntry(name: "Skyr", caloriesPer100g: 63, proteinPer100g: 11,
                               sugarPer100g: 4, saturatedFatPer100g: 0.1, saltPer100g: 0.1, date: day)
        _ = try store.addEntry(name: "Chips", caloriesPer100g: 540, fatPer100g: 34, date: other)

        #expect(try store.itemsNeedingNutrientRepair(on: day).map(\.name) == ["Gouda"])
        #expect(try store.itemsNeedingNutrientRepair().map(\.name) == ["Chips", "Gouda"])
    }

    @Test("Ein Tag ohne Lücken liefert nichts, auch wenn andere Tage welche haben")
    func dayWithoutGaps() throws {
        let store = try Store.inMemory()
        _ = try store.addEntry(name: "Skyr", caloriesPer100g: 63, proteinPer100g: 11,
                               sugarPer100g: 4, saturatedFatPer100g: 0.1, saltPer100g: 0.1, date: day)
        _ = try store.addEntry(name: "Chips", caloriesPer100g: 540, fatPer100g: 34, date: other)

        #expect(try store.itemsNeedingNutrientRepair(on: day).isEmpty)
    }
}
