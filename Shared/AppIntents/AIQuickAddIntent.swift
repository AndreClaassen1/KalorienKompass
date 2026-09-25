//
//  AIQuickAddIntent.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 20.02.26.
//

import AppIntents
import SwiftData
import WidgetKit

// MARK: - KI-Schnelleintrag

/// App Intent: Freitext-Lebensmitteleingabe mit KI-Naehrwertschaetzung
struct AIQuickAddIntent: AppIntent {
    static var title: LocalizedStringResource = "KI Schnelleintrag"
    static var description = IntentDescription(
        "Lebensmittel per Freitext eingeben — KI schätzt Kalorien automatisch."
    )

    @Parameter(title: "Lebensmittel", description: "Was hast du gegessen?")
    var foodDescription: String

    @Parameter(title: "Mahlzeit", default: .snack)
    var mealType: MealTypeAppEnum

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            // Mehrere Speisen in einer Eingabe werden einzeln gebucht (Issue #73)
            let estimates = try await ClaudeAPIService.shared.estimateMeal(
                description: foodDescription
            )
            guard let first = estimates.first else {
                return .result(dialog: "Keine Speise erkannt.")
            }
            let context = ModelContext(DataModel.shared.modelContainer)
            for estimate in estimates {
                FocusBooking.book(
                    estimate: estimate,
                    meal: mealType.mealType,
                    date: Date(),
                    context: context
                )
            }
            WidgetCenter.shared.reloadAllTimelines()
        // Nur iOS: die Datei liegt auch im Watch-Target, das keinen Sender hat
        // (und auch keinen braucht — dort ist der Store direkt zur Hand).
        #if os(iOS)
        IntentDataAccess.pushComplicationSnapshot(in: context)
        #endif

            let mealName = mealType.mealType.localizedString
            if estimates.count == 1 {
                let kcal = Int(first.portionCalories)
                let protein = Int(first.portionProtein)
                return .result(dialog: "\(first.name): \(kcal) kcal, \(protein)g Protein – zum \(mealName) eingetragen.")
            }
            let gesamt = Int(estimates.reduce(0) { $0 + $1.portionCalories })
            let namen = estimates.map(\.name).joined(separator: ", ")
            return .result(dialog: "\(namen) – zusammen \(gesamt) kcal zum \(mealName) eingetragen.")
        } catch ClaudeAPIService.APIError.noAPIKey {
            return .result(dialog: "Kein Claude API-Key konfiguriert. Bitte in den App-Einstellungen eintragen.")
        } catch {
            return .result(dialog: "KI-Schätzung fehlgeschlagen: \(error.localizedDescription)")
        }
    }
}
