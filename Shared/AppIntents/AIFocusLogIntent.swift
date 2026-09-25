//
//  AIFocusLogIntent.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 13.07.26.
//
//  Siri/Shortcuts-Intent des Fokus-Modus: Freitext ("Roter Bulgursalat") wird
//  per KI geschätzt, der Mahlzeit zugeordnet, gebucht — und das Ergebnis als
//  interaktives Snippet direkt in Siri angezeigt, mit Rückgängig und
//  Mahlzeit-Korrektur ohne Umweg über die App.
//

import AppIntents
import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Intent

struct AIFocusLogIntent: AppIntent {
    static var title: LocalizedStringResource = "Essen per Sprache eintragen"
    static var description = IntentDescription(
        "Sag, was du gegessen hast — die KI schätzt die Nährwerte und trägt es ein."
    )

    @Parameter(
        title: "Gegessen",
        description: "Was hast du gegessen oder getrunken?",
        requestValueDialog: "Was hast du gegessen?"
    )
    var foodDescription: String

    /// Optional: legt die Mahlzeit fest. Ohne Angabe wird sie aus der Uhrzeit abgeleitet.
    @Parameter(title: "Mahlzeit")
    var mealType: MealTypeAppEnum?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetIntent {
        let meal = mealType?.mealType ?? MealType.currentBasedOnTime

        // Mehrere Speisen in einem Satz ergeben mehrere Eintraege (Issue #73):
        // "Ruehrei mit Speck und ein Kaffee" ist beim Sprechen der Normalfall.
        let estimates: [AIFoodEstimate]
        do {
            estimates = try await ClaudeAPIService.shared.estimateMeal(description: foodDescription)
        } catch ClaudeAPIService.APIError.noAPIKey {
            throw FocusLogError.noAPIKey
        } catch {
            throw FocusLogError.failed(error.localizedDescription)
        }
        guard !estimates.isEmpty else { throw FocusLogError.failed("Keine Speise erkannt") }

        let context = ModelContext(DataModel.shared.modelContainer)
        let entries = estimates.map {
            FocusBooking.book(estimate: $0, meal: meal, date: Date(), context: context)
        }
        WidgetCenter.shared.reloadAllTimelines()
        #if os(iOS)
        IntentDataAccess.pushComplicationSnapshot(in: context)
        #endif

        let gesamt = Int(entries.reduce(0) { $0 + $1.calories }.rounded())
        let dialog = entries.count == 1
            ? "\(entries[0].foodItem?.name ?? "Eintrag") eingetragen: \(gesamt) kcal."
            : "\(entries.count) Einträge, zusammen \(gesamt) kcal."

        // Das Snippet wird aus den IDs neu aufgebaut, nicht aus diesen Objekten:
        // Apple fuehrt Snippet-Intents mehrfach aus, und nach einem Tipp auf
        // "Rueckgaengig" muss der naechste Durchlauf den neuen Stand zeigen.
        return .result(
            dialog: IntentDialog(stringLiteral: dialog),
            snippetIntent: FocusLogSnippetIntent(
                entryIds: entries.map(\.entryId),
                foodItemIds: entries.compactMap { $0.foodItem?.itemId }
            )
        )
    }
}

// MARK: - Fehler

enum FocusLogError: Error, CustomLocalizedStringResourceConvertible {
    case noAPIKey
    case failed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noAPIKey:
            "Kein Claude API-Key konfiguriert. Bitte in den App-Einstellungen eintragen."
        case .failed(let message):
            "KI-Erkennung fehlgeschlagen: \(message)"
        }
    }
}

// MARK: - Snippet-Intent

/// Zeichnet das Siri-Snippet zur gebuchten Charge.
///
/// **Aendert nichts.** Apple fuehrt Snippet-Intents mehrfach aus (beim Anzeigen und
/// nach jedem Knopfdruck), ein Seiteneffekt liefe also mehrfach. Geschrieben wird
/// ausschliesslich in den Knopf-Intents darunter, die danach `reload()` rufen.
struct FocusLogSnippetIntent: SnippetIntent {
    static var title: LocalizedStringResource = "Eingetragenes Essen"
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Eintraege")
    var entryIds: [String]

    /// Die mitgebuchten Schnell-Lebensmittel, damit Rueckgaengig sie mitloescht.
    @Parameter(title: "Lebensmittel")
    var foodItemIds: [String]

    // Die beiden Initializer sind Pflicht: `@Parameter` kennt fuer Arrays keine
    // Default-Wert-Ueberladung, Swift synthetisiert hier also nichts.
    init() {}

    init(entryIds: [String], foodItemIds: [String]) {
        self.entryIds = entryIds
        self.foodItemIds = foodItemIds
    }

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let context = ModelContext(DataModel.shared.modelContainer)
        let entries = FocusBooking.entries(with: entryIds, context: context)

        let items = entries.map {
            FocusLogResultItem(
                name: $0.foodItem?.name ?? "—",
                mealName: $0.mealType.localizedString,
                kcal: Int($0.calories.rounded())
            )
        }

        return .result(
            view: FocusLogSnippetView(
                items: items,
                currentMeal: entries.first?.mealType,
                entryIds: entryIds,
                foodItemIds: foodItemIds
            )
        )
    }
}

// MARK: - Knopf-Intents des Snippets

/// Nimmt die gerade gebuchte Charge zurueck — ohne die App zu oeffnen.
struct UndoFocusLogIntent: AppIntent {
    static var title: LocalizedStringResource = "Eintrag zurücknehmen"
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Eintraege")
    var entryIds: [String]

    @Parameter(title: "Lebensmittel")
    var foodItemIds: [String]

    init() {}

    init(entryIds: [String], foodItemIds: [String]) {
        self.entryIds = entryIds
        self.foodItemIds = foodItemIds
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = ModelContext(DataModel.shared.modelContainer)
        FocusBooking.undo(entryIds: entryIds, foodItemIds: foodItemIds, context: context)

        WidgetCenter.shared.reloadAllTimelines()
        #if os(iOS)
        IntentDataAccess.pushComplicationSnapshot(in: context)
        #endif

        FocusLogSnippetIntent.reload()
        return .result()
    }
}

/// Ordnet die Charge einer anderen Mahlzeit zu (Fruehstueck statt Snack).
struct MoveFocusLogIntent: AppIntent {
    static var title: LocalizedStringResource = "Mahlzeit ändern"
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Eintraege")
    var entryIds: [String]

    @Parameter(title: "Mahlzeit")
    var meal: MealTypeAppEnum

    init() {}

    init(entryIds: [String], meal: MealTypeAppEnum) {
        self.entryIds = entryIds
        self.meal = meal
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = ModelContext(DataModel.shared.modelContainer)
        FocusBooking.move(entryIds: entryIds, to: meal.mealType, context: context)

        WidgetCenter.shared.reloadAllTimelines()
        FocusLogSnippetIntent.reload()
        return .result()
    }
}

// MARK: - Snippet-Ansicht

/// Ergebnis fuer die Siri-Snippet-Anzeige (plain values, kein SwiftData)
struct FocusLogResultItem: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let mealName: String
    let kcal: Int
}

/// Snippet, das Siri nach dem Eintragen anzeigt.
///
/// Zeigt jede gebuchte Speise einzeln, damit erkennbar ist, wie die Eingabe
/// aufgeteilt wurde (Issue #73). Dazu Rueckgaengig und die Mahlzeit-Korrektur,
/// beides direkt in Siri (Issue #74).
struct FocusLogSnippetView: View {
    let items: [FocusLogResultItem]
    let currentMeal: MealType?
    let entryIds: [String]
    let foodItemIds: [String]

    /// Die Mahlzeiten, die im Snippet zur Korrektur angeboten werden.
    ///
    /// Die vier Hauptmahlzeiten plus die gerade gebuchte, falls es eine Nebenmahlzeit
    /// ist. Ohne sie waere nicht erkennbar, wohin gebucht wurde, und ein Fehltipp
    /// haette keinen Rueckweg — eine Buchung um 16 Uhr landet in der Kaffeepause,
    /// die sonst nirgends in der Leiste steht (Issue #78).
    static func selectableMeals(current: MealType?) -> [MealType] {
        // Dieselbe Regel wie die Mahlzeitenliste im Fokus-Modus: Hauptmahlzeiten
        // immer, Nebenmahlzeiten nur wenn belegt — hier ist "belegt" die gerade
        // gebuchte Mahlzeit.
        MealType.visibleTypes(showAll: false) { $0 == current }
    }

    private var selectableMeals: [MealType] { Self.selectableMeals(current: currentMeal) }

    private var totalKcal: Int { items.reduce(0) { $0 + $1.kcal } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if items.isEmpty {
                Label("Zurückgenommen", systemImage: "arrow.uturn.backward")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.headline)
                            Text(item.mealName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(item.kcal) kcal")
                            .font(.body.weight(.semibold))
                    }
                }

                if items.count > 1 {
                    Divider()
                    HStack {
                        Text("Gesamt")
                            .font(.subheadline)
                        Spacer()
                        Text("\(totalKcal) kcal")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                mealPicker
                Button(intent: UndoFocusLogIntent(entryIds: entryIds, foodItemIds: foodItemIds)) {
                    Label("Rückgängig", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }

    /// Mahlzeit-Korrektur als Symbolreihe: die aktuelle ist gefuellt und ohne Knopf,
    /// weil ein Tipp darauf nichts aendern wuerde.
    ///
    /// Symbole statt Woerter, damit die Reihe einzeilig bleibt — „Fruehstueck" und
    /// „Mittagessen" brachen nebeneinander um (Issue #78). Der Name der gebuchten
    /// Mahlzeit steht ohnehin an jedem Eintrag darueber.
    private var mealPicker: some View {
        HStack(spacing: 8) {
            ForEach(selectableMeals, id: \.self) { meal in
                if meal == currentMeal {
                    icon(for: meal)
                        .background(.tint, in: Circle())
                        .foregroundStyle(.white)
                        .accessibilityLabel(meal.localizedName)
                } else {
                    Button(intent: MoveFocusLogIntent(
                        entryIds: entryIds,
                        meal: MealTypeAppEnum(mealType: meal)
                    )) {
                        icon(for: meal)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel(meal.localizedName)
                }
            }
        }
    }

    private func icon(for meal: MealType) -> some View {
        Image(systemName: meal.symbolName)
            .font(.callout)
            .frame(width: 32, height: 32)
    }
}
