//
//  FocusLeverViewModel.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 20.07.26.
//
//  Haelt den aktiven Hebel, die Tagesrueckmeldung und die
//  Wochenauswertung. Der Hebel wird nur empfangen und angezeigt,
//  nie von der App selbst erzeugt.
//

import SwiftUI
import SwiftData
import os

@Observable
@MainActor
final class FocusLeverViewModel {
    private static let logger = Logger(subsystem: "com.andre.claassen.KalorienKompass", category: "FocusLever")

    /// Ab diesem Alter weist die Detailansicht darauf hin, dass laenger kein
    /// neuer Hebel gesetzt wurde. Der alte bleibt aktiv.
    static let staleAfterDays = 7

    private let modelContext: ModelContext

    /// Aktiver Hebel (`nil` = noch keiner gesetzt). Basis fuer die Detail-/Setzen-Ansicht.
    private(set) var activeLever: FocusLever?

    /// Hebel, der am angezeigten Tag (`referenceDate`) galt. Beim Zurueckblaettern kann
    /// das ein bereits abgeloester Hebel sein; fuer heute ist er identisch mit `activeLever`.
    /// Steuert die Anzeige in `FocusLeverBar`.
    private(set) var displayedLever: FocusLever?

    /// Abgeloeste Hebel, juengste zuerst
    private(set) var history: [FocusLever] = []

    /// Tag, auf den sich die Rueckmeldung bezieht
    private(set) var referenceDate: Date = Date().startOfDay

    /// CloudKit-Import-Observer — laedt den Hebel nach eingehendem Sync neu.
    /// Er wird nur empfangen (CLI/anderes Geraet), nicht erzeugt, und soll ohne
    /// Neustart erscheinen.
    @ObservationIgnored private var reloader: RemoteImportReloader?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        load()
        reloader = RemoteImportReloader { [weak self] in
            guard let self else { return }
            self.load(for: self.referenceDate)
        }
    }

    // MARK: - Laden

    func load(for date: Date = Date()) {
        referenceDate = date.startOfDay
        activeLever = FocusLever.active(in: modelContext)
        displayedLever = FocusLever.lever(on: referenceDate, in: modelContext)
        history = FocusLever.history(in: modelContext)
    }

    // MARK: - Abgeleiteter Zustand

    /// Wird gerade der heutige Tag angezeigt? Steuert den Wortlaut der Rueckmeldung
    /// ("Heute gehalten?" vs. das neutrale "Gehalten?" beim Zurueckblaettern).
    var isViewingToday: Bool {
        Calendar.current.isDateInToday(referenceDate)
    }

    /// Rueckmeldung fuer den angezeigten Tag, falls schon beantwortet
    var todaysCheck: FocusLeverCheck? {
        displayedLever?.check(for: referenceDate)
    }

    /// Ist die Rueckmeldung fuer den angezeigten Tag noch offen?
    var needsAnswer: Bool {
        displayedLever != nil && todaysCheck == nil
    }

    /// Laeuft der Hebel schon laenger als eine Woche?
    var isStale: Bool {
        guard let lever = activeLever else { return false }
        return lever.ageInDays >= Self.staleAfterDays
    }

    /// Soll der Hebel gerade hervorgehoben werden? Nur der heutige Hebel wird betont —
    /// beim Zurueckblaettern ist die "jetzt handeln"-Hervorhebung sinnlos.
    func isHighlighted(now: Date = Date(), lastBookedMeal: MealType?) -> Bool {
        guard Calendar.current.isDate(referenceDate, inSameDayAs: now) else { return false }
        guard let lever = displayedLever else { return false }
        return FocusLeverTrigger.isHighlighted(lever: lever, now: now, lastBookedMeal: lastBookedMeal)
    }

    /// Adhaerenz der letzten sieben Tage bis einschliesslich `referenceDate`
    var currentWeekAdherence: FocusLeverAdherence? {
        adherence(for: activeLever, endingAt: referenceDate, days: 7)
    }

    /// Adhaerenz eines Hebels ueber einen Zeitraum, der auf `end` endet.
    func adherence(for lever: FocusLever?, endingAt end: Date, days: Int) -> FocusLeverAdherence? {
        guard let lever else { return nil }
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: end.startOfDay) else { return nil }
        return FocusLeverAdherence.evaluate(checks: lever.checks ?? [], start: start, days: days)
    }

    /// Adhaerenz ueber die gesamte Laufzeit eines (meist abgeloesten) Hebels.
    func lifetimeAdherence(for lever: FocusLever) -> FocusLeverAdherence {
        let calendar = Calendar.current
        let start = lever.createdAt.startOfDay
        let end = (lever.retiredAt ?? Date()).startOfDay
        let days = max((calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1, 1)
        return FocusLeverAdherence.evaluate(checks: lever.checks ?? [], start: start, days: days)
    }

    // MARK: - Mutationen

    /// Setzt einen neuen Hebel; der bisherige wandert in die Historie.
    func setLever(text: String, triggerStartHour: Int, triggerOnSnack: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        FocusLever.setActive(
            text: trimmed,
            triggerStartHour: triggerStartHour,
            triggerOnSnack: triggerOnSnack,
            in: modelContext
        )
        load(for: referenceDate)
        Self.logger.info("Neuer Hebel gesetzt")
    }

    /// Aendert die Trigger-Einstellungen des aktiven Hebels, ohne ihn abzuloesen.
    func updateTrigger(startHour: Int, onSnack: Bool) {
        guard let lever = activeLever else { return }
        lever.triggerStartHour = startHour
        lever.triggerOnSnack = onSnack
        try? modelContext.save()
    }

    /// Beantwortet die Tagesfrage des angezeigten Tages (oder korrigiert eine bestehende
    /// Antwort) — bezogen auf den an diesem Tag gueltigen Hebel, auch beim Zurueckblaettern.
    func answer(kept: Bool) {
        guard let lever = displayedLever else { return }
        lever.recordCheck(kept: kept, for: referenceDate, in: modelContext)
        load(for: referenceDate)
        Self.logger.info("Hebel \(kept ? "gehalten" : "nicht gehalten", privacy: .public)")
    }

    /// Loescht die Antwort des angezeigten Tages (macht die Rueckmeldung wieder offen).
    func clearAnswer() {
        guard let lever = displayedLever else { return }
        // Alle Rueckmeldungen des Tages entfernen, nicht nur die geltende: sonst
        // taucht ein CloudKit-Duplikat beim naechsten Lesen wieder auf (Issue #67).
        let ofDay = FocusLeverCheck.all(among: lever.checks ?? [], on: referenceDate)
        guard !ofDay.isEmpty else { return }
        for check in ofDay {
            modelContext.delete(check)
        }
        try? modelContext.save()
        load(for: referenceDate)
    }
}
