//
//  PresetQuickAddWidget.swift
//  KalorienKompassWidget
//
//  Erstellt von André Claaßen am 20.02.26.
//

import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Intent

/// Trägt ein vorkonfiguriertes Lebensmittel direkt ins Tagebuch ein.
struct LogPresetFoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Preset-Lebensmittel eintragen"

    @Parameter(title: "Name") var name: String
    @Parameter(title: "Kalorien") var calories: Int
    @Parameter(title: "Protein") var protein: Double
    @Parameter(title: "Kohlenhydrate") var carbs: Double
    @Parameter(title: "Fett") var fat: Double

    init() {}

    init(name: String, calories: Int, protein: Double, carbs: Double, fat: Double) {
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let container = DataModel.shared.modelContainer
        let context = ModelContext(container)

        let foodItem = FoodItem(
            name: name,
            caloriesPer100g: Double(calories),
            proteinPer100g: protein,
            carbsPer100g: carbs,
            fatPer100g: fat
        )
        foodItem.isQuickEntry = true
        context.insert(foodItem)

        let entry = DiaryEntry(
            date: Date(),
            mealType: MealType.currentBasedOnTime,
            amountGrams: 100,
            foodItem: foodItem
        )
        context.insert(entry)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Konfiguration

/// Widget-Konfiguration: Lebensmittel und Nährwerte festlegen.
struct QuickAddPresetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Preset konfigurieren"
    static var description = IntentDescription("Häufig gegessenes Lebensmittel per Tipp eintragen")

    @Parameter(title: "Lebensmittel", default: "Kaffee")   var foodName: String
    @Parameter(title: "Kalorien (kcal)", default: 50)      var calories: Int
    @Parameter(title: "Protein (g)", default: 0.0)         var protein: Double
    @Parameter(title: "Kohlenhydrate (g)", default: 5.0)   var carbs: Double
    @Parameter(title: "Fett (g)", default: 2.0)            var fat: Double
}

// MARK: - Timeline

struct PresetWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: QuickAddPresetConfiguration
}

struct PresetWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PresetWidgetEntry {
        PresetWidgetEntry(date: Date(), configuration: .init())
    }

    func snapshot(for configuration: QuickAddPresetConfiguration, in context: Context) async -> PresetWidgetEntry {
        PresetWidgetEntry(date: Date(), configuration: configuration)
    }

    func timeline(for configuration: QuickAddPresetConfiguration, in context: Context) async -> Timeline<PresetWidgetEntry> {
        Timeline(
            entries: [PresetWidgetEntry(date: Date(), configuration: configuration)],
            policy: .never
        )
    }
}

// MARK: - Widget

struct PresetQuickAddWidget: Widget {
    let kind = "PresetQuickAddWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: QuickAddPresetConfiguration.self,
            provider: PresetWidgetProvider()
        ) { entry in
            PresetQuickAddWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Schnell-Eintrag")
        .description("Häufig gegessenes Lebensmittel per Tipp eintragen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - View

struct PresetQuickAddWidgetView: View {
    let entry: PresetWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: MealType.currentBasedOnTime.symbolName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.configuration.calories) kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(entry.configuration.foodName)
                .font(.headline)
                .lineLimit(2)
            Spacer()
            Button(intent: LogPresetFoodIntent(
                name: entry.configuration.foodName,
                calories: entry.configuration.calories,
                protein: entry.configuration.protein,
                carbs: entry.configuration.carbs,
                fat: entry.configuration.fat
            )) {
                Label("Eintragen", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(4)
    }
}
