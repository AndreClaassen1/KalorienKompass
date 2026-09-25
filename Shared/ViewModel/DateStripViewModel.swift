//
//  DateStripViewModel.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import SwiftUI

/// ViewModel fuer den horizontalen Datums-Strip (iPhone)
@Observable
final class DateStripViewModel {
    /// Generiert eine ungerade Anzahl Tage rund um ein Referenzdatum
    func daysAround(date: Date, count: Int) -> [Date] {
        let center = date.startOfDay
        let halfRange = count / 2
        return (-halfRange...halfRange).map { center.addingDays($0) }
    }
}
