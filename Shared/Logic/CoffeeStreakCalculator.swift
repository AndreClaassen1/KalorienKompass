//
//  CoffeeStreakCalculator.swift
//  KalorienKompass
//
//  Berechnet aktuelle und laengste Streak fuer das Kaffee-Limit.
//

import Foundation

/// Logik zur Berechnung von Kaffee-Streaks aus DayRecord-Daten.
///
/// Das Tagesziel ist eine **Obergrenze**, keine Sollmenge: ein Tag zaehlt, solange
/// hoechstens `goal` Tassen getrunken wurden — auch bei null. Erst darueber reisst
/// die Serie (Issue #77). Frueher galt `cups >= goal`, uebernommen vom Wasser; damit
/// belohnte der Streak genau das Gegenteil und ging verloren, wer wenig trank.
enum CoffeeStreakCalculator {

    /// Ein Paar aus Datum und Tassenanzahl — entkoppelt die Logik von SwiftData.
    struct DailyCount: Sendable {
        let date: Date
        let cups: Int
    }

    /// Aktuelle Streak mit festem Tageslimit (Wrapper fuer einfachen Fall).
    static func currentStreak(
        counts: [DailyCount],
        goal: Int,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        currentStreak(counts: counts, goalForDay: { _ in goal }, today: today, calendar: calendar)
    }

    /// Aktuelle Streak: die Tage seit der letzten Ueberschreitung, `today` mitgezaehlt.
    /// Unterstuetzt pro Tag unterschiedliche Limits (z.B. Wochenend-Bonus).
    ///
    /// Tage ohne Datensatz gelten als null Tassen und damit als gehalten — nur so
    /// zaehlt ein kaffeefreier Tag mit. Gerechnet wird deshalb nicht Tag fuer Tag
    /// rueckwaerts (das liefe bei lauter gehaltenen Tagen durch das ganze Fenster),
    /// sondern ueber den juengsten Tag, der das Limit gerissen hat. Ohne einen
    /// solchen zaehlt die Serie ab dem aeltesten bekannten Tag: weiter zurueck weiss
    /// die App nichts.
    static func currentStreak(
        counts: [DailyCount],
        goalForDay: (Date) -> Int,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let byDay = groupByDay(counts, calendar: calendar)
        guard let earliest = byDay.keys.min() else { return 0 }

        let heute = calendar.startOfDay(for: today)
        let start: Date
        if let letzterBruch = brokenDays(byDay, goalForDay: goalForDay).max() {
            guard letzterBruch < heute,
                  let tagDanach = calendar.date(byAdding: .day, value: 1, to: letzterBruch)
            else { return 0 }
            start = tagDanach
        } else {
            start = earliest
        }

        return dayCount(from: start, to: heute, calendar: calendar)
    }

    /// Laengste je erreichte Streak (fuer Statistik).
    ///
    /// Betrachtet den Zeitraum zwischen aeltestem und juengstem Datensatz: die
    /// laengste Serie ist der groesste Abstand zwischen zwei Ueberschreitungen. Tage
    /// ohne Datensatz liegen in diesen Abstaenden und zaehlen mit, statt die Serie
    /// abreissen zu lassen.
    static func longestStreak(
        counts: [DailyCount],
        goal: Int,
        calendar: Calendar = .current
    ) -> Int {
        longestStreak(counts: counts, goalForDay: { _ in goal }, calendar: calendar)
    }

    static func longestStreak(
        counts: [DailyCount],
        goalForDay: (Date) -> Int,
        calendar: Calendar = .current
    ) -> Int {
        let byDay = groupByDay(counts, calendar: calendar)
        guard let earliest = byDay.keys.min(), let latest = byDay.keys.max() else { return 0 }

        let brueche = brokenDays(byDay, goalForDay: goalForDay).sorted()
        var longest = 0
        var abschnittsStart = earliest

        for bruch in brueche {
            if let vortag = calendar.date(byAdding: .day, value: -1, to: bruch) {
                longest = max(longest, dayCount(from: abschnittsStart, to: vortag, calendar: calendar))
            }
            guard let tagDanach = calendar.date(byAdding: .day, value: 1, to: bruch) else { break }
            abschnittsStart = tagDanach
        }

        return max(longest, dayCount(from: abschnittsStart, to: latest, calendar: calendar))
    }

    /// Die Tage, an denen mehr getrunken wurde als erlaubt.
    private static func brokenDays(_ byDay: [Date: Int], goalForDay: (Date) -> Int) -> [Date] {
        byDay.compactMap { tag, tassen in
            tassen > max(goalForDay(tag), 0) ? tag : nil
        }
    }

    /// Anzahl der Kalendertage von `from` bis `to`, beide eingeschlossen. 0, wenn
    /// `to` vor `from` liegt.
    private static func dayCount(from: Date, to: Date, calendar: Calendar) -> Int {
        guard from <= to else { return 0 }
        let tage = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        return tage + 1
    }

    /// Ein Wert je Kalendertag. Bei Duplikaten gilt der groessere — dieselbe Regel
    /// wie beim Falten der DayRecords (Issue #67).
    private static func groupByDay(_ counts: [DailyCount], calendar: Calendar) -> [Date: Int] {
        Dictionary(
            counts.map { (calendar.startOfDay(for: $0.date), $0.cups) },
            uniquingKeysWith: max
        )
    }
}
