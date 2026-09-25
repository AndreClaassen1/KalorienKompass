//
//  WaterWidget.swift
//  KalorienKompassWatch
//
//  Erstellt von André Claaßen am 06.02.26.
//
//  Wasser-Widget fuer watchOS-Komplikationen.
//  Unterstuetzt accessoryCircular und accessoryCorner.
//

#if os(watchOS)
import SwiftUI
import WidgetKit

/// Wasser-Widget fuer Watch-Face
struct WaterWidget: Widget {
    let kind = "WaterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchWidgetProvider()) { entry in
            WaterWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(Text("widget_water_title"))
        .description(Text("widget_water_description"))
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}

/// View fuer das Wasser-Widget (adaptiv je nach Family)
struct WaterWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: WatchWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularWaterView(entry: entry)
        case .accessoryCorner:
            CornerWaterView(entry: entry)
        default:
            CircularWaterView(entry: entry)
        }
    }
}

// MARK: - Circular View

/// Kreisfoermige Wasser-Anzeige mit Fortschrittsring
struct CircularWaterView: View {
    let entry: WatchWidgetEntry

    private var liters: String {
        let l = Double(entry.snapshot.waterIntakeMl) / 1000.0
        return String(format: "%.1f", l)
    }

    private var progress: Double {
        entry.snapshot.waterProgress
    }

    var body: some View {
        Gauge(value: progress) {
            Image(systemName: "drop.fill")
        } currentValueLabel: {
            Text("\(liters)L")
                .font(.system(size: 16, weight: .bold))
                .minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircular)
        .tint(.cyan)
        .widgetAccentable()
    }
}

// MARK: - Corner View

/// Eck-Anzeige fuer Wasser (kompakt)
struct CornerWaterView: View {
    let entry: WatchWidgetEntry

    private var liters: String {
        let l = Double(entry.snapshot.waterIntakeMl) / 1000.0
        return String(format: "%.1f", l)
    }

    private var progress: Double {
        entry.snapshot.waterProgress
    }

    var body: some View {
        Gauge(value: progress) {
            Image(systemName: "drop.fill")
        } currentValueLabel: {
            Text("\(liters)L")
                .font(.system(size: 14, weight: .bold))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(.cyan)
        .widgetAccentable()
    }
}

// MARK: - Previews

#Preview("Circular — Leer", as: .accessoryCircular) {
    WaterWidget()
} timeline: {
    WatchWidgetEntry(date: .now, snapshot: .empty)
}

#Preview("Circular — Halb voll", as: .accessoryCircular) {
    WaterWidget()
} timeline: {
    WatchWidgetEntry(date: .now, snapshot: .preview)
}

#Preview("Circular — Ziel erreicht", as: .accessoryCircular) {
    WaterWidget()
} timeline: {
    WatchWidgetEntry(date: .now, snapshot: WatchDaySnapshot(
        date: .now,
        totalCaloriesConsumed: 0,
        effectiveCalorieGoal: 2000,
        remainingCalories: 2000,
        waterIntakeMl: 2500,
        waterGoalMl: 2500
    ))
}

#Preview("Corner", as: .accessoryCorner) {
    WaterWidget()
} timeline: {
    WatchWidgetEntry(date: .now, snapshot: .preview)
}
#endif
