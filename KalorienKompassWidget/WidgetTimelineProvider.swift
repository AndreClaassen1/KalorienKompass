//
//  WidgetTimelineProvider.swift
//  KalorienKompassWidget
//
//  Erstellt von André Claaßen am 05.02.26.
//

import WidgetKit

/// Timeline-Entry mit Tages-Snapshot
struct KKWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: DaySnapshot
}

/// Gemeinsamer TimelineProvider fuer alle KalorienKompass-Widgets
struct KKTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> KKWidgetEntry {
        KKWidgetEntry(date: .now, snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (KKWidgetEntry) -> Void) {
        let snapshot = WidgetDataProvider.loadTodaySnapshot()
        completion(KKWidgetEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KKWidgetEntry>) -> Void) {
        let snapshot = WidgetDataProvider.loadTodaySnapshot()
        let entry = KKWidgetEntry(date: .now, snapshot: snapshot)

        // Naechstes Update in 15 Minuten oder um Mitternacht
        let now = Date()
        let tomorrow = Calendar.current.startOfDay(for: now.addingTimeInterval(86400))
        let fifteenMinutes = now.addingTimeInterval(15 * 60)
        let nextUpdate = min(fifteenMinutes, tomorrow)

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}
