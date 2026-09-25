//
//  CurrentDayProvider.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import SwiftUI

/// Verwaltet das aktuell ausgewaehlte Datum in der App
@Observable
final class CurrentDayProvider {
    /// Globale Instanz fuer App-weite Datumssynchronisation
    static let shared = CurrentDayProvider()

    /// Aktuell ausgewaehltes Datum
    var selectedDate: Date = Date().startOfDay

    /// Wechselt zum vorherigen Tag
    func previousDay() {
        selectedDate = selectedDate.addingDays(-1)
    }

    /// Wechselt zum naechsten Tag
    func nextDay() {
        selectedDate = selectedDate.addingDays(1)
    }

    /// Wechselt zum heutigen Tag
    func goToToday() {
        selectedDate = Date().startOfDay
    }

    /// Prueft ob der ausgewaehlte Tag heute ist
    var isToday: Bool {
        selectedDate.isToday
    }

    /// Prueft ob der naechste Tag in der Zukunft liegt (ueber heute hinaus)
    var canGoForward: Bool {
        !selectedDate.isToday
    }
}
