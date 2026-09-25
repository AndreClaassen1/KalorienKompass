//
//  Date+Extensions.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import Foundation

extension Date {
    /// Gibt den Tagesbeginn (00:00:00) fuer das aktuelle Datum zurueck
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Gibt das Ende des Tages (23:59:59) zurueck
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay)!
    }

    /// Gibt den Wochentag als kurzen String zurueck (z.B. "Mo", "Di")
    var shortWeekdayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EE"
        return formatter.string(from: self)
    }

    /// Tag des Monats als Zahl
    var dayOfMonth: Int {
        Calendar.current.component(.day, from: self)
    }

    /// Prueft ob das Datum heute ist
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Prueft ob das Datum in der Zukunft liegt
    var isFuture: Bool {
        self > Date()
    }

    /// Datum um n Tage verschieben
    func addingDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self)!
    }

    /// Prueft ob zwei Daten am selben Tag liegen
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    /// Formatiertes Datum fuer Anzeige (z.B. "4. Feb. 2026")
    var formattedMedium: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    /// Die sieben Tage der Kalenderwoche, in der dieses Datum liegt.
    ///
    /// Der Wochenbeginn richtet sich nach dem Kalender des Systems (in
    /// Deutschland Montag, in den USA Sonntag) — die Wochenleiste im Fokus-Modus
    /// soll dieselbe Woche zeigen wie der Systemkalender.
    var weekDays: [Date] {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: self) else {
            return [startOfDay]
        }
        let start = interval.start.startOfDay
        return (0..<7).map { start.addingDays($0) }
    }

    /// Array der letzten n Tage (inklusive heute)
    static func lastDays(_ count: Int) -> [Date] {
        let today = Date().startOfDay
        return (0..<count).map { today.addingDays(-$0) }.reversed()
    }
}
