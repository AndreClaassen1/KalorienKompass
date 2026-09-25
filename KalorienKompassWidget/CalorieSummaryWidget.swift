//
//  CalorieSummaryWidget.swift
//  KalorienKompassWidget
//
//  Erstellt von André Claaßen am 05.02.26.
//

import SwiftUI
import WidgetKit

/// Kalorien-Widget: Ring mit Bilanz (medium) bzw. reine Restzahl (small)
struct CalorieSummaryWidget: Widget {
    let kind = "CalorieSummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KKTimelineProvider()) { entry in
            CalorieSummaryWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(Text("widget_calories_title"))
        .description(Text("widget_calories_description"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// Waehlt die Darstellung nach Widget-Family
struct CalorieSummaryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: KKWidgetEntry

    @ViewBuilder
    var body: some View {
        switch family {
        case .systemSmall:
            SmallCalorieView(entry: entry)
                .widgetURL(DeepLink.url("dashboard"))
        default:
            CalorieHeroView(
                eaten: Int(entry.snapshot.totalCaloriesConsumed),
                remaining: Int(entry.snapshot.remainingCalories),
                burned: entry.snapshot.burnedCalories,
                goal: entry.snapshot.effectiveCalorieGoal
            )
            .widgetURL(DeepLink.url("dashboard"))
        }
    }
}

/// Restkalorien als grosse Zahl, darunter ein flacher Balken.
///
/// Bewusst ohne Ring, anders als die Medium-Variante: Diese Kachel steht in StandBy
/// quer am Ladegeraet und wird aus Zimmerentfernung gelesen. Nachts dimmt StandBy stark
/// und faerbt rot ein; eine grosse Zahl uebersteht das, feine Ringlinien nicht.
struct SmallCalorieView: View {
    let entry: KKWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label {
                Text("widget_calories_title")
            } icon: {
                Image(systemName: "fork.knife")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            Text(magnitude, format: .number)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(isOverBudget ? .red : .primary)

            Text("kcal \(suffix)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 6)

            ProgressView(value: progress)
                .tint(isOverBudget ? .red : .green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Anzeigewerte

    /// Abgeleitet statt uebergeben, damit Balken und Zahl nicht auseinanderlaufen koennen.
    private var remaining: Int {
        Int(NutrientCalculator.remainingCalories(
            consumed: entry.snapshot.totalCaloriesConsumed,
            goal: entry.snapshot.effectiveCalorieGoal
        ).rounded())
    }

    private var isOverBudget: Bool {
        remaining < 0
    }

    /// Betrag der Restkalorien; das Vorzeichen traegt das Suffix.
    private var magnitude: Int {
        abs(remaining)
    }

    /// "uebrig" bzw. "drueber", je nach Vorzeichen
    private var suffix: String {
        isOverBudget
            ? String(localized: "widget_over")
            : String(localized: "calories_remaining")
    }

    /// Anteil des Tagesziels, gekappt bei 1.0. Um wie viel darueber, sagt die Zahl.
    private var progress: Double {
        min(NutrientCalculator.progress(
            consumed: entry.snapshot.totalCaloriesConsumed,
            goal: entry.snapshot.effectiveCalorieGoal
        ), 1.0)
    }
}

// MARK: - Previews

#Preview("Kalorien — Morgens", as: .systemMedium) {
    CalorieSummaryWidget()
} timeline: {
    KKWidgetEntry(date: .now, snapshot: DaySnapshot(
        date: .now,
        totalCaloriesConsumed: 320,
        effectiveCalorieGoal: 2200,
        remainingCalories: 1880,
        burnedCalories: 180,
        waterIntakeMl: 500,
        waterGoalMl: 2000,
        mealCalories: [:],
        mealBudgets: [:]
    ))
}

#Preview("Kalorien — Nachmittags", as: .systemMedium) {
    CalorieSummaryWidget()
} timeline: {
    KKWidgetEntry(date: .now, snapshot: DaySnapshot(
        date: .now,
        totalCaloriesConsumed: 1450,
        effectiveCalorieGoal: 2200,
        remainingCalories: 750,
        burnedCalories: 520,
        waterIntakeMl: 1250,
        waterGoalMl: 2000,
        mealCalories: [:],
        mealBudgets: [:]
    ))
}

#Preview("Kalorien — Ueberschritten", as: .systemMedium) {
    CalorieSummaryWidget()
} timeline: {
    KKWidgetEntry(date: .now, snapshot: DaySnapshot(
        date: .now,
        totalCaloriesConsumed: 2800,
        effectiveCalorieGoal: 2200,
        remainingCalories: -600,
        burnedCalories: 350,
        waterIntakeMl: 1750,
        waterGoalMl: 2000,
        mealCalories: [:],
        mealBudgets: [:]
    ))
}

#Preview("Klein — Morgens", as: .systemSmall) {
    CalorieSummaryWidget()
} timeline: {
    KKWidgetEntry(date: .now, snapshot: DaySnapshot(
        date: .now,
        totalCaloriesConsumed: 320,
        effectiveCalorieGoal: 2200,
        remainingCalories: 1880,
        burnedCalories: 180,
        waterIntakeMl: 500,
        waterGoalMl: 2000,
        mealCalories: [:],
        mealBudgets: [:]
    ))
}

#Preview("Klein — Ueberschritten", as: .systemSmall) {
    CalorieSummaryWidget()
} timeline: {
    KKWidgetEntry(date: .now, snapshot: DaySnapshot(
        date: .now,
        totalCaloriesConsumed: 2500,
        effectiveCalorieGoal: 2100,
        remainingCalories: -400,
        burnedCalories: 210,
        waterIntakeMl: 1500,
        waterGoalMl: 2000,
        mealCalories: [:],
        mealBudgets: [:]
    ))
}
