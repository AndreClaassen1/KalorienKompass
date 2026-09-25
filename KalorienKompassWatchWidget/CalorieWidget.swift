//
//  CalorieWidget.swift
//  KalorienKompassWatch
//
//  Erstellt von André Claaßen am 06.02.26.
//
//  Kalorien-Widget fuer watchOS-Komplikationen.
//  Die Darstellung liefert die geteilte CalorieComplicationView; hier steht nur,
//  woher die Zahlen kommen.
//

#if os(watchOS)
import SwiftUI
import WidgetKit

/// Kalorien-Widget fuer Watch-Face
struct CalorieWidget: Widget {
    let kind = "CalorieWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchWidgetProvider()) { entry in
            CalorieComplicationView(
                eaten: entry.snapshot.totalCaloriesConsumed,
                goal: entry.snapshot.effectiveCalorieGoal,
                tint: .status
            )
            .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(Text("widget_calories_title"))
        .description(Text("widget_calories_description"))
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Previews

#Preview("Circular — Normal", as: .accessoryCircular) {
    CalorieWidget()
} timeline: {
    WatchWidgetEntry(date: .now, snapshot: .preview)
}

#Preview("Circular — Ueberschritten", as: .accessoryCircular) {
    CalorieWidget()
} timeline: {
    WatchWidgetEntry(date: .now, snapshot: .overBudgetPreview)
}

#Preview("Rectangular", as: .accessoryRectangular) {
    CalorieWidget()
} timeline: {
    WatchWidgetEntry(date: .now, snapshot: .preview)
}

#Preview("Rectangular — Ueberschritten", as: .accessoryRectangular) {
    CalorieWidget()
} timeline: {
    WatchWidgetEntry(date: .now, snapshot: .overBudgetPreview)
}

#Preview("Inline", as: .accessoryInline) {
    CalorieWidget()
} timeline: {
    WatchWidgetEntry(date: .now, snapshot: .preview)
}

#Preview("Inline — Ueberschritten", as: .accessoryInline) {
    CalorieWidget()
} timeline: {
    WatchWidgetEntry(date: .now, snapshot: .overBudgetPreview)
}
#endif
