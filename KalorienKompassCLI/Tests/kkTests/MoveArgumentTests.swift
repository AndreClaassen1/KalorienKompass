import Foundation
import Testing
@testable import kk

@Suite("Commands.parseMoveArgs")
struct MoveArgumentTests {

    // MARK: - Auswahl und Ziel

    @Test("Nummer und Ziel-Mahlzeit")
    func parsesNumberAndMeal() throws {
        let parsed = try Commands.parseMoveArgs(["2", "--meal", "dinner"])

        #expect(parsed.selector == .numbers([2]))
        #expect(parsed.targetMeal == .dinner)
        #expect(parsed.targetDate == nil)
    }

    @Test("Mehrere Nummern und ein Zieltag")
    func parsesSeveralNumbersAndTargetDate() throws {
        let parsed = try Commands.parseMoveArgs(["1", "2", "3", "--to-date", "gestern"])

        #expect(parsed.selector == .numbers([1, 2, 3]))
        #expect(parsed.targetMeal == nil)
        #expect(parsed.targetDate.map(Calendar.current.isDateInYesterday) == true)
    }

    @Test("--from wählt eine ganze Mahlzeit")
    func parsesFromMeal() throws {
        let parsed = try Commands.parseMoveArgs(["--from", "lunch", "--meal", "breakfast"])

        #expect(parsed.selector == .meal(.lunch))
        #expect(parsed.targetMeal == .breakfast)
    }

    @Test("Der Quelltag kommt aus --yesterday, das Ziel bleibt davon unberührt")
    func parsesSourceDay() throws {
        let parsed = try Commands.parseMoveArgs(["--yesterday", "2", "--meal", "dinner"])

        #expect(Calendar.current.isDateInYesterday(parsed.sourceDate))
        #expect(parsed.targetDate == nil)
    }

    @Test("Ohne Argumente wird nur aufgelistet")
    func listsWithoutArguments() throws {
        let parsed = try Commands.parseMoveArgs([])

        #expect(parsed.selector == nil)
        #expect(parsed.hasTarget == false)
        #expect(parsed.sourceDate.isToday)
    }

    // MARK: - Uhrzeit als Ziel

    @Test("Die Uhrzeit bestimmt die Mahlzeit")
    func derivesMealFromTime() throws {
        let parsed = try Commands.parseMoveArgs(["2", "--time", "19:30"])

        #expect(parsed.targetMeal == .dinner)
    }

    @Test("--meal schlägt --time, wie bei kk add")
    func mealBeatsTime() throws {
        let parsed = try Commands.parseMoveArgs(["2", "--meal", "breakfast", "--time", "19:30"])

        #expect(parsed.targetMeal == .breakfast)
    }

    // MARK: - Was abgelehnt wird

    @Test("Nummern und --from zusammen sind mehrdeutig")
    func rejectsMixedSelectors() {
        #expect(throws: KKError.self) {
            try Commands.parseMoveArgs(["--from", "lunch", "2", "--meal", "dinner"])
        }
    }

    @Test("Eine Auswahl ohne Ziel ändert nichts und wird abgelehnt")
    func rejectsSelectionWithoutTarget() {
        #expect(throws: KKError.self) {
            try Commands.parseMoveArgs(["2"])
        }
    }

    @Test("Ein Ziel ohne Auswahl wird abgelehnt")
    func rejectsTargetWithoutSelection() {
        #expect(throws: KKError.self) {
            try Commands.parseMoveArgs(["--meal", "dinner"])
        }
    }

    @Test("Ein Zieltag in der Zukunft wird abgelehnt")
    func rejectsFutureTargetDate() {
        #expect(throws: KKError.self) {
            try Commands.parseMoveArgs(["2", "--to-date", "2099-01-01"])
        }
    }

    @Test("Ein freies Argument, das keine Nummer ist, wird abgelehnt")
    func rejectsNonNumericArgument() {
        #expect(throws: KKError.self) {
            try Commands.parseMoveArgs(["zwei", "--meal", "dinner"])
        }
    }

    @Test("Eine unbekannte Mahlzeit wird abgelehnt")
    func rejectsUnknownMeal() {
        #expect(throws: KKError.self) {
            try Commands.parseMoveArgs(["2", "--meal", "brunch"])
        }
    }

    @Test("Eine Option ohne Wert wird abgelehnt", arguments: [["2", "--meal"], ["2", "--to-date"], ["--from"]])
    func rejectsMissingValue(_ args: [String]) {
        #expect(throws: KKError.self) {
            try Commands.parseMoveArgs(args)
        }
    }
}
