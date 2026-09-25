//
//  FocusLever.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 20.07.26.
//

import Foundation
import SwiftData

/// Der aktuelle Hebel: eine konkrete Verhaltensaenderung, die im
/// woechentlichen OKR-Check-In festgelegt wird.
///
/// Die App **empfaengt** einen Hebel und zeigt ihn im Moment der
/// Entscheidung an, sie erfindet keinen. Es gibt immer hoechstens einen aktiven
/// Hebel (`retiredAt == nil`); ein neuer loest den alten ab, der alte
/// wandert in die Historie.
@Model
public class FocusLever {
    /// Eindeutiger Bezeichner
    var leverId: String = UUID().uuidString

    /// Formulierung des Hebels (aus dem Check-In uebernommen)
    var text: String = ""

    /// Zeitpunkt, ab dem der Hebel gilt
    var createdAt: Date = Date()

    /// Zeitpunkt der Abloesung. `nil` bedeutet: aktiv.
    var retiredAt: Date?

    /// Ab dieser Stunde wird der Hebel hervorgehoben (0 = immer)
    var triggerStartHour: Int = 20

    /// Zusaetzlich hervorheben, wenn gerade ein Snack oder Abendessen gebucht wurde
    var triggerOnSnack: Bool = true

    /// Taegliche Rueckmeldungen zu diesem Hebel
    @Relationship(deleteRule: .cascade, inverse: \FocusLeverCheck.lever)
    var checks: [FocusLeverCheck]? = []

    init(text: String, triggerStartHour: Int = 20, triggerOnSnack: Bool = true) {
        self.text = text
        self.triggerStartHour = triggerStartHour
        self.triggerOnSnack = triggerOnSnack
    }

    /// Ist der Hebel aktuell aktiv?
    var isActive: Bool { retiredAt == nil }

    /// Alter in Tagen seit dem Setzen
    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: createdAt.startOfDay, to: Date().startOfDay).day ?? 0
    }

    /// Rueckmeldungen absteigend nach Datum
    var sortedChecks: [FocusLeverCheck] {
        (checks ?? []).sorted { $0.date > $1.date }
    }

    /// Die geltende Rueckmeldung des Tages, siehe `FocusLeverCheck.effective`.
    /// Reiner Lesepfad: raeumt nichts auf, das passiert in `recordCheck`.
    func check(for date: Date) -> FocusLeverCheck? {
        FocusLeverCheck.effective(among: checks ?? [], on: date)
    }
}

extension FocusLever {

    /// Liefert den aktiven Hebel oder `nil`.
    ///
    /// CloudKit kann pro Geraet ein Duplikat erzeugen, deshalb wird immer
    /// absteigend nach `createdAt` sortiert und nur der juengste Datensatz
    /// zurueckgegeben. Bewusst andersherum als `UserProfile.canonical`, wo das
    /// aelteste Profil gewinnt: ein Hebel wird gesetzt und abgeloest, das
    /// juengste Exemplar ist das gemeinte. Gemeinsam ist beiden, dass der
    /// Lesepfad nichts loescht.
    static func active(in context: ModelContext) -> FocusLever? {
        var descriptor = FetchDescriptor<FocusLever>(
            predicate: #Predicate<FocusLever> { $0.retiredAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// Liefert den Hebel, der an einem bestimmten Tag galt (oder `nil`).
    ///
    /// Ein Hebel gilt fuer Tag D, wenn er an oder vor D gesetzt (`createdAt`) und
    /// nicht vor D abgeloest (`retiredAt`) wurde. Bei mehreren Treffern — etwa wenn
    /// am selben Tag ein Hebel den anderen abgeloest hat — gewinnt der juengste
    /// (spaetestes `createdAt`), dieselbe CloudKit-robuste Sortierung wie `active(in:)`.
    static func lever(on date: Date, in context: ModelContext) -> FocusLever? {
        let day = date.startOfDay
        let descriptor = FetchDescriptor<FocusLever>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return all.first { lever in
            guard lever.createdAt.startOfDay <= day else { return false }
            guard let retired = lever.retiredAt else { return true }
            return retired.startOfDay >= day
        }
    }

    /// Alle abgeloesten Hebel, juengste zuerst.
    static func history(in context: ModelContext) -> [FocusLever] {
        let descriptor = FetchDescriptor<FocusLever>(
            predicate: #Predicate<FocusLever> { $0.retiredAt != nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Setzt einen neuen aktiven Hebel und loest alle bisherigen ab.
    ///
    /// Haelt die Invariante "genau ein aktiver Hebel" auch dann aufrecht,
    /// wenn CloudKit mehrere aktive Datensaetze eingespielt hat.
    @discardableResult
    static func setActive(
        text: String,
        triggerStartHour: Int = 20,
        triggerOnSnack: Bool = true,
        in context: ModelContext
    ) -> FocusLever {
        retireAll(in: context)

        let lever = FocusLever(
            text: text,
            triggerStartHour: triggerStartHour,
            triggerOnSnack: triggerOnSnack
        )
        context.insert(lever)
        try? context.save()
        return lever
    }

    /// Loest alle aktiven Hebel ab (ohne einen neuen zu setzen).
    static func retireAll(in context: ModelContext) {
        let descriptor = FetchDescriptor<FocusLever>(
            predicate: #Predicate<FocusLever> { $0.retiredAt == nil }
        )
        let now = Date()
        for lever in (try? context.fetch(descriptor)) ?? [] {
            lever.retiredAt = now
        }
        try? context.save()
    }

    /// Setzt die Tagesrueckmeldung fuer einen Tag (legt sie an oder korrigiert sie).
    ///
    /// Schreibpfad: raeumt hier auch CloudKit-Duplikate desselben Tages ab, damit
    /// die Adhaerenz-Auswertung nicht zwei Antworten fuer einen Tag sieht.
    @discardableResult
    func recordCheck(kept: Bool, for date: Date = Date(), in context: ModelContext) -> FocusLeverCheck {
        if let existing = check(for: date) {
            existing.kept = kept
            existing.answeredAt = Date()
            for duplicate in FocusLeverCheck.all(among: checks ?? [], on: date) where duplicate !== existing {
                context.delete(duplicate)
            }
            try? context.save()
            return existing
        }

        let check = FocusLeverCheck(date: date, kept: kept)
        check.lever = self
        context.insert(check)
        try? context.save()
        return check
    }
}
