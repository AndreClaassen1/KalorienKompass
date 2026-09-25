//
//  WaterWidget.swift
//  KalorienKompassWidget
//
//  Erstellt von André Claaßen am 05.02.26.
//

import AppIntents
import SwiftUI
import WidgetKit

/// Small Widget: Wasseraufnahme mit interaktiven Buttons
struct WaterWidget: Widget {
    let kind = "WaterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KKTimelineProvider()) { entry in
            WaterWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(Text("widget_water_title"))
        .description(Text("widget_water_description"))
        .supportedFamilies([.systemSmall])
    }
}

/// View fuer das Wasser-Widget
struct WaterWidgetView: View {
    let entry: KKWidgetEntry

    private var liters: String {
        let l = Double(entry.snapshot.waterIntakeMl) / 1000.0
        return String(format: "%.2f", l)
    }

    private var glasses: Int {
        entry.snapshot.waterIntakeMl / 250
    }

    private var goalGlasses: Int {
        entry.snapshot.waterGoalMl / 250
    }

    private var progress: Double {
        guard entry.snapshot.waterGoalMl > 0 else { return 0 }
        return min(Double(entry.snapshot.waterIntakeMl) / Double(entry.snapshot.waterGoalMl), 1.0)
    }

    var body: some View {
        VStack(spacing: 6) {
            // Titel
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.blue)
                Text("widget_water_title")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
            }

            Spacer()

            // Literzahl
            Text("\(liters) L")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.blue)

            // Glaeser-Zaehler
            Text("widget_water_glasses \(glasses) \(goalGlasses)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            // Fortschrittsbalken
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.blue.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.blue)
                        .frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)

            Spacer()

            // Interaktive Buttons
            HStack(spacing: 12) {
                Button(intent: RemoveWaterIntent()) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue.opacity(0.7))
                }
                .buttonStyle(.plain)

                Spacer()

                Button(intent: AddWaterIntent()) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .widgetURL(DeepLink.url("dashboard"))
    }
}

// MARK: - Previews

#Preview("Wasser — Leer", as: .systemSmall) {
    WaterWidget()
} timeline: {
    KKWidgetEntry(date: .now, snapshot: .empty)
}

#Preview("Wasser — Halb voll", as: .systemSmall) {
    WaterWidget()
} timeline: {
    KKWidgetEntry(date: .now, snapshot: DaySnapshot(
        date: .now,
        totalCaloriesConsumed: 0,
        effectiveCalorieGoal: 2000,
        remainingCalories: 2000,
        burnedCalories: 0,
        waterIntakeMl: 1000,
        waterGoalMl: 2000,
        mealCalories: [:],
        mealBudgets: [:]
    ))
}

#Preview("Wasser — Ziel erreicht", as: .systemSmall) {
    WaterWidget()
} timeline: {
    KKWidgetEntry(date: .now, snapshot: DaySnapshot(
        date: .now,
        totalCaloriesConsumed: 0,
        effectiveCalorieGoal: 2000,
        remainingCalories: 2000,
        burnedCalories: 0,
        waterIntakeMl: 2250,
        waterGoalMl: 2000,
        mealCalories: [:],
        mealBudgets: [:]
    ))
}
