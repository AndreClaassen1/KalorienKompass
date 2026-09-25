//
//  FocusLeverCheck.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 20.07.26.
//

import Foundation
import SwiftData

/// Tagesrueckmeldung zu einem Hebel: gehalten oder nicht gehalten.
///
/// Aus diesen Rueckmeldungen entsteht die Adhaerenz-Messung. Erst sie erlaubt es,
/// eine wirksame, aber schlecht umgesetzte Massnahme von einer konsequent
/// umgesetzten, aber wirkungslosen zu unterscheiden.
@Model
public class FocusLeverCheck {
    /// Eindeutiger Bezeichner
    var checkId: String = UUID().uuidString

    /// Tag der Rueckmeldung (normalisiert auf Tagesbeginn)
    var date: Date = Date()

    /// Wurde der Hebel an diesem Tag gehalten?
    var kept: Bool = false

    /// Zeitpunkt der Antwort (auch bei Korrektur aktualisiert)
    var answeredAt: Date = Date()

    /// Zugehoeriger Hebel
    var lever: FocusLever?

    init(date: Date = Date(), kept: Bool) {
        self.date = date.startOfDay
        self.kept = kept
    }
}

extension FocusLeverCheck {

    /// Die geltende Rueckmeldung unter moeglichen CloudKit-Duplikaten **desselben
    /// Tages**: die zuletzt gegebene Antwort, bei Gleichstand die kleinste `checkId`.
    ///
    /// Heisst bewusst nicht `canonical`: dieser Name steht im Projekt fuer den
    /// Schreibpfad, der bereinigt. Hier wird nur ausgewaehlt.
    static func effective(among checks: [FocusLeverCheck]) -> FocusLeverCheck? {
        checks.max { lhs, rhs in
            lhs.answeredAt == rhs.answeredAt
                ? lhs.checkId > rhs.checkId
                : lhs.answeredAt < rhs.answeredAt
        }
    }

    /// Die geltende Rueckmeldung fuer einen bestimmten Tag.
    ///
    /// Steht bewusst nur hier, damit Anzeige (`FocusLever.check(for:)`), Auswertung
    /// (`FocusLeverAdherence.evaluate`) und Korrektur (`recordCheck`) dieselbe
    /// Antwort meinen (Issue #67).
    static func effective(among checks: [FocusLeverCheck], on date: Date) -> FocusLeverCheck? {
        let day = date.startOfDay
        return effective(among: checks.filter { $0.date == day })
    }

    /// Alle Rueckmeldungen eines Tages. Zum Loeschen nur im Schreibpfad verwenden:
    /// ein `delete()` propagiert in die CloudKit-Zone.
    static func all(among checks: [FocusLeverCheck], on date: Date) -> [FocusLeverCheck] {
        let day = date.startOfDay
        return checks.filter { $0.date == day }
    }
}

/// Adhaerenz-Auswertung ueber einen Zeitraum
struct FocusLeverAdherence: Sendable, Equatable {
    /// Erster Tag des Zeitraums (einschliesslich)
    let start: Date
    /// Letzter Tag des Zeitraums (einschliesslich)
    let end: Date
    let kept: Int
    let missed: Int
    let unanswered: Int

    /// Anzahl Tage im Zeitraum
    var totalDays: Int { kept + missed + unanswered }

    /// Quote der gehaltenen Tage, bezogen auf alle Tage des Zeitraums.
    ///
    /// Unbeantwortete Tage zaehlen bewusst als nicht gehalten: eine ausbleibende
    /// Rueckmeldung ist selbst ein Signal und soll die Quote nicht schoenen.
    var rate: Double {
        guard totalDays > 0 else { return 0 }
        return Double(kept) / Double(totalDays)
    }
}

extension FocusLeverAdherence {

    /// Wertet die Rueckmeldungen eines Zeitraums aus.
    /// - Parameters:
    ///   - checks: Rueckmeldungen (duerfen auch ausserhalb des Zeitraums liegen)
    ///   - start: erster Tag (einschliesslich)
    ///   - days: Anzahl Tage ab `start`
    static func evaluate(checks: [FocusLeverCheck], start: Date, days: Int) -> FocusLeverAdherence {
        let calendar = Calendar.current
        let firstDay = start.startOfDay
        let dayCount = max(days, 1)
        let lastDay = calendar.date(byAdding: .day, value: dayCount - 1, to: firstDay) ?? firstDay

        // Einmal nach Tagen gruppieren, dann je Tag die geltende Antwort waehlen:
        // bei Duplikaten zaehlt ein Tag genau einmal (Issue #67).
        let byDay = Dictionary(grouping: checks, by: { $0.date.startOfDay })
            .compactMapValues { FocusLeverCheck.effective(among: $0) }

        var keptCount = 0
        var missedCount = 0

        for offset in 0..<dayCount {
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay),
                  let check = byDay[day.startOfDay] else { continue }
            if check.kept { keptCount += 1 } else { missedCount += 1 }
        }

        return FocusLeverAdherence(
            start: firstDay,
            end: lastDay,
            kept: keptCount,
            missed: missedCount,
            unanswered: dayCount - keptCount - missedCount
        )
    }
}
