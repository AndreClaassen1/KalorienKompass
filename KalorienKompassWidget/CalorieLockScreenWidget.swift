//
//  CalorieLockScreenWidget.swift
//  KalorienKompassWidget
//
//  Erstellt von André Claaßen am 01.09.26.
//
//  Kalorien-Komplikation fuer den iOS-Sperrbildschirm und StandBy.
//  Die Darstellung liefert die geteilte CalorieComplicationView; hier steht nur,
//  woher die Zahlen kommen und wohin ein Tipp fuehrt.
//

// Nur iOS: die accessory-Familien gibt es auf macOS nicht, und die Widget-Extension
// wird beim macOS-Archive mitgebaut. Ohne diese Klammer bricht es dort ab (Issue #105).
#if os(iOS)

import SwiftUI
import WidgetKit

/// Restkalorien auf dem Sperrbildschirm
struct CalorieLockScreenWidget: Widget {
    let kind = "CalorieLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KKTimelineProvider()) { entry in
            CalorieComplicationView(
                eaten: entry.snapshot.totalCaloriesConsumed,
                goal: entry.snapshot.effectiveCalorieGoal,
                tint: .system
            )
            .containerBackground(.clear, for: .widget)
            .widgetURL(DeepLink.url("dashboard"))
        }
        .configurationDisplayName(Text("widget_lockscreen_calories_title"))
        .description(Text("widget_lockscreen_calories_description"))
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Previews

private let morningSnapshot = DaySnapshot(
    date: .now,
    totalCaloriesConsumed: 320,
    effectiveCalorieGoal: 2200,
    remainingCalories: 1880,
    burnedCalories: 180,
    waterIntakeMl: 500,
    waterGoalMl: 2000,
    mealCalories: [:],
    mealBudgets: [:]
)

private let overBudgetSnapshot = DaySnapshot(
    date: .now,
    totalCaloriesConsumed: 2800,
    effectiveCalorieGoal: 2200,
    remainingCalories: -600,
    burnedCalories: 350,
    waterIntakeMl: 1750,
    waterGoalMl: 2000,
    mealCalories: [:],
    mealBudgets: [:]
)

#Preview("Rund — Morgens", as: .accessoryCircular) {
    CalorieLockScreenWidget()
} timeline: {
    KKWidgetEntry(date: .now, snapshot: morningSnapshot)
}

#Preview("Rund — Ueberschritten", as: .accessoryCircular) {
    CalorieLockScreenWidget()
} timeline: {
    KKWidgetEntry(date: .now, snapshot: overBudgetSnapshot)
}

#Preview("Rechteckig — Ueberschritten", as: .accessoryRectangular) {
    CalorieLockScreenWidget()
} timeline: {
    KKWidgetEntry(date: .now, snapshot: overBudgetSnapshot)
}

#Preview("Einzeilig", as: .accessoryInline) {
    CalorieLockScreenWidget()
} timeline: {
    KKWidgetEntry(date: .now, snapshot: morningSnapshot)
}

#endif
