import Foundation
import Testing
@testable import kk

@Suite("Mikrowerte in kk add und kk repair")
struct NutrientArgumentTests {

    // MARK: - kk add, manueller Modus

    @Test("Gesättigte Fettsäuren, Zucker und Salz werden gelesen")
    func parsesMicronutrients() throws {
        let parsed = try Commands.parseAddArgs([
            "--name", "Gouda", "--calories", "356", "--grams", "20", "--fat", "27.4",
            "--saturated-fat", "17.6", "--sugar", "0.1", "--salt", "2",
        ])

        #expect(parsed.saturatedFat == 17.6)
        #expect(parsed.sugar == 0.1)
        #expect(parsed.salt == 2)
    }

    @Test("Ein fehlender Zahlenwert wird abgelehnt")
    func rejectsMissingNumber() {
        #expect(throws: KKError.self) {
            try Commands.parseAddArgs(["--name", "Gouda", "--calories", "356", "--salt"])
        }
    }

    // MARK: - kk repair nutrients

    @Test("Ohne Datum gilt der ganze Bestand")
    func repairWithoutDate() throws {
        let parsed = try Commands.parseRepairArgs(["nutrients", "--apply"])

        #expect(parsed.apply)
        #expect(parsed.date == nil)
    }

    @Test("--date heute schränkt auf den Tag ein, auch hinter anderen Optionen")
    func repairWithDate() throws {
        let parsed = try Commands.parseRepairArgs(["nutrients", "--limit", "3", "--date", "heute"])

        #expect(parsed.date?.isToday == true)
        #expect(parsed.limit == 3)
        #expect(parsed.apply == false)
    }

    @Test("--yesterday wird verstanden")
    func repairYesterday() throws {
        let parsed = try Commands.parseRepairArgs(["nutrients", "--yesterday"])

        #expect(parsed.date.map(Calendar.current.isDateInYesterday) == true)
    }

    @Test("Ein anderes repair-Kommando wird abgelehnt")
    func rejectsUnknownSubcommand() {
        #expect(throws: KKError.self) {
            try Commands.parseRepairArgs(["kalorien"])
        }
    }
}
