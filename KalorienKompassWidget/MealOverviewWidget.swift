//
//  MealOverviewWidget.swift
//  KalorienKompassWidget
//
//  Erstellt von André Claaßen am 05.02.26.
//

import SwiftUI
import WidgetKit

/// Large Widget: Alle 6 Mahlzeiten mit Fortschrittsringen (2 Reihen × 3 Spalten)
struct MealOverviewWidget: Widget {
    let kind = "MealOverviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KKTimelineProvider()) { entry in
            MealOverviewWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(Text("widget_meals_title"))
        .description(Text("widget_meals_description"))
        .supportedFamilies([.systemLarge])
    }
}

/// View fuer das Mahlzeiten-Widget
struct MealOverviewWidgetView: View {
    let entry: KKWidgetEntry

    /// Alle 6 Mahlzeiten sortiert nach Tagesablauf
    private let meals = MealType.allCases.sorted { $0.sortOrder < $1.sortOrder }

    /// Obere Reihe: Fruehstueck, 2. Fruehstueck, Mittagessen
    private var topRow: [MealType] { Array(meals.prefix(3)) }
    /// Untere Reihe: Kaffeepause, Abendessen, Snack
    private var bottomRow: [MealType] { Array(meals.suffix(3)) }

    var body: some View {
        VStack(spacing: 32) {
            // Titel
            HStack {
                Text("widget_meals_title")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }

            // Obere Reihe
            HStack(spacing: 0) {
                ForEach(topRow) { meal in
                    Link(destination: DeepLink.url("addFood?meal=\(meal.rawValue)")!) {
                        mealColumn(meal: meal)
                    }
                }
            }

            // Untere Reihe
            HStack(spacing: 0) {
                ForEach(bottomRow) { meal in
                    Link(destination: DeepLink.url("addFood?meal=\(meal.rawValue)")!) {
                        mealColumn(meal: meal)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func mealColumn(meal: MealType) -> some View {
        let consumed = entry.snapshot.mealCalories[meal] ?? 0
        let budget = entry.snapshot.mealBudgets[meal] ?? 500
        let progress = budget > 0 ? min(consumed / Double(budget), 1.0) : 0
        let isOver = consumed > Double(budget)

        VStack(spacing: 4) {
            // Fortschrittsring mit SF-Symbol
            ZStack {
                Circle()
                    .stroke(.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isOver ? .red : .green,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 44, height: 44)

                Image(systemName: meal.symbolName)
                    .font(.system(size: 16))
                    .foregroundStyle(isOver ? .red : .primary)
            }

            // Mahlzeiten-Name
            Text(meal.localizedName)
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(.secondary)

            // Kalorien
            Text("\(Int(consumed)) kcal")
                .font(.caption2.weight(.medium))
                .foregroundStyle(isOver ? .red : .primary)
                .lineLimit(1)

            // Plus-Icon
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.tint)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Previews

#Preview("Mahlzeiten — Leer", as: .systemLarge) {
    MealOverviewWidget()
} timeline: {
    KKWidgetEntry(date: .now, snapshot: .empty)
}

#Preview("Mahlzeiten — Teils gefuellt", as: .systemLarge) {
    MealOverviewWidget()
} timeline: {
    KKWidgetEntry(date: .now, snapshot: DaySnapshot(
        date: .now,
        totalCaloriesConsumed: 1155,
        effectiveCalorieGoal: 2200,
        remainingCalories: 1045,
        burnedCalories: 300,
        waterIntakeMl: 1000,
        waterGoalMl: 2000,
        mealCalories: [
            .breakfast: 420, .secondBreakfast: 120,
            .lunch: 650, .coffeeBreak: 45,
            .dinner: 0, .snack: 85
        ],
        mealBudgets: [
            .breakfast: 550, .secondBreakfast: 220,
            .lunch: 660, .coffeeBreak: 110,
            .dinner: 550, .snack: 110
        ]
    ))
}

#Preview("Mahlzeiten — Ueberschritten", as: .systemLarge) {
    MealOverviewWidget()
} timeline: {
    KKWidgetEntry(date: .now, snapshot: DaySnapshot(
        date: .now,
        totalCaloriesConsumed: 2800,
        effectiveCalorieGoal: 2200,
        remainingCalories: -600,
        burnedCalories: 400,
        waterIntakeMl: 1500,
        waterGoalMl: 2000,
        mealCalories: [
            .breakfast: 700, .secondBreakfast: 250,
            .lunch: 850, .coffeeBreak: 150,
            .dinner: 600, .snack: 250
        ],
        mealBudgets: [
            .breakfast: 550, .secondBreakfast: 220,
            .lunch: 660, .coffeeBreak: 110,
            .dinner: 550, .snack: 110
        ]
    ))
}
