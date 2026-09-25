//
//  WatchWidgetProvider.swift
//  KalorienKompassWatch
//
//  Erstellt von André Claaßen am 06.02.26.
//
//  TimelineProvider fuer watchOS-Widgets.
//  Laedt Tagesdaten aus SwiftData fuer Komplikationen.
//

#if os(watchOS)
import SwiftData
import WidgetKit

/// Snapshot der Tagesdaten fuer Watch-Widget-Anzeige
struct WatchDaySnapshot: Sendable {
    let date: Date
    let totalCaloriesConsumed: Double
    let effectiveCalorieGoal: Int
    let remainingCalories: Double
    let waterIntakeMl: Int
    let waterGoalMl: Int

    var waterProgress: Double {
        guard waterGoalMl > 0 else { return 0 }
        return min(Double(waterIntakeMl) / Double(waterGoalMl), 1.0)
    }

    static let empty = WatchDaySnapshot(
        date: Date(),
        totalCaloriesConsumed: 0,
        effectiveCalorieGoal: 2000,
        remainingCalories: 2000,
        waterIntakeMl: 0,
        waterGoalMl: 2000
    )

    /// Beispieldaten fuer Previews
    static let preview = WatchDaySnapshot(
        date: Date(),
        totalCaloriesConsumed: 1240,
        effectiveCalorieGoal: 2100,
        remainingCalories: 860,
        waterIntakeMl: 1500,
        waterGoalMl: 2500
    )

    /// Beispieldaten mit ueberschrittenem Ziel
    static let overBudgetPreview = WatchDaySnapshot(
        date: Date(),
        totalCaloriesConsumed: 2500,
        effectiveCalorieGoal: 2100,
        remainingCalories: -400,
        waterIntakeMl: 1500,
        waterGoalMl: 2500
    )
}

/// Timeline-Entry fuer Watch-Widgets
struct WatchWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchDaySnapshot
}

/// TimelineProvider fuer Watch-Widgets
struct WatchWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> WatchWidgetEntry {
        WatchWidgetEntry(date: .now, snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchWidgetEntry) -> Void) {
        let snapshot = currentSnapshot()
        completion(WatchWidgetEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchWidgetEntry>) -> Void) {
        let snapshot = currentSnapshot()
        let entry = WatchWidgetEntry(date: .now, snapshot: snapshot)

        // Naechstes Update in 15 Minuten oder um Mitternacht
        let now = Date()
        let tomorrow = Calendar.current.startOfDay(for: now.addingTimeInterval(86400))
        let fifteenMinutes = now.addingTimeInterval(15 * 60)
        let nextUpdate = min(fifteenMinutes, tomorrow)

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    // MARK: - Private

    /// Der Stand, den die Komplikation zeigt: der **neuere** aus lokalem Store und
    /// dem, was das iPhone geschickt hat.
    ///
    /// Der lokale Store der Uhr wird nur gefuellt, wenn die Watch-App laeuft — ohne
    /// den uebertragenen Stand zeigte die Komplikation die Zahlen des letzten
    /// App-Besuchs (Issue #69).
    private func currentSnapshot() -> WatchDaySnapshot {
        // Beide Seiten stempeln ihren Stand selbst ab (siehe ComplicationSnapshot).
        guard let gewinner = ComplicationSnapshot.newer(
            local: ComplicationSnapshot.stored(.local),
            received: ComplicationSnapshot.stored(.received)
        ) else {
            // Noch kein Stand abgelegt: der Store ist die einzige Quelle.
            return loadTodaySnapshot()
        }

        return WatchDaySnapshot(
            date: gewinner.day,
            totalCaloriesConsumed: gewinner.totalCaloriesConsumed,
            effectiveCalorieGoal: gewinner.effectiveCalorieGoal,
            remainingCalories: gewinner.remainingCalories,
            waterIntakeMl: gewinner.waterIntakeMl,
            waterGoalMl: gewinner.waterGoalMl
        )
    }

    /// Laedt den heutigen Tages-Snapshot aus SwiftData
    private func loadTodaySnapshot() -> WatchDaySnapshot {
        let container = DataModel.shared.modelContainer
        let context = ModelContext(container)
        let today = Date().startOfDay
        let endOfDay = today.endOfDay

        // Profil laden — kanonisch nach createdAt, ohne Bereinigung (Issue #63)
        let profile = UserProfile.existing(in: context)

        // DayRecord kanonisch lesen (Issue #65)
        let dayRecord = DayRecord.existing(in: context, for: today)

        // Tagebucheintraege laden
        let entryDescriptor = FetchDescriptor<DiaryEntry>(
            predicate: #Predicate<DiaryEntry> { entry in
                entry.date >= today && entry.date <= endOfDay
            }
        )
        let entries = (try? context.fetch(entryDescriptor)) ?? []

        // Effektives Kalorienziel — einheitliche Berechnung
        let nonWorkoutActive = dayRecord.nonWorkoutActiveEnergy

        let effectiveGoal = NutrientCalculator.effectiveCalorieGoal(
            profile: profile,
            dayRecord: dayRecord,
            nonWorkoutActiveEnergy: nonWorkoutActive
        )

        // Gesamtkalorien
        let totalConsumed = entries.reduce(0.0) { $0 + $1.calories }
        let remaining = Double(effectiveGoal) - totalConsumed

        return WatchDaySnapshot(
            date: today,
            totalCaloriesConsumed: totalConsumed,
            effectiveCalorieGoal: effectiveGoal,
            remainingCalories: remaining,
            waterIntakeMl: dayRecord?.waterIntakeMl ?? 0,
            waterGoalMl: profile?.dailyWaterGoalMl ?? 2000
        )
    }
}
#endif
