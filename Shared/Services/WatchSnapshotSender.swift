//
//  WatchSnapshotSender.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 26.07.26.
//

#if os(iOS)
import Foundation
import WatchConnectivity
import os

/// Schickt der Uhr die Zahlen fuer ihre Komplikation.
///
/// `transferCurrentComplicationUserInfo` ist der von Apple fuer Komplikationen
/// vorgesehene Kanal: er weckt die Watch-Extension **im Hintergrund**, ohne dass
/// die Watch-App geoeffnet wird. Genau das fehlte bisher — die Komplikation hing
/// am lokalen Store der Uhr, den nur die Watch-App fuellt (Issue #69).
///
/// Das Kontingent liegt bei rund 50 Uebertragungen pro Tag. Deshalb wird nur
/// gesendet, wenn sich die Zahlen tatsaechlich geaendert haben, und bei
/// erschoepftem Kontingent auf `updateApplicationContext` ausgewichen: der weckt
/// die Uhr nicht, kommt aber ohne Budget aus und liegt bereit, sobald sie ohnehin
/// aufwacht.
final class WatchSnapshotSender: NSObject, WCSessionDelegate {

    static let shared = WatchSnapshotSender()

    private static let log = Logger(
        subsystem: "com.andre.claassen.KalorienKompass",
        category: "WatchSnapshot"
    )

    /// Zuletzt uebertragener Stand — Grundlage der Aenderungspruefung.
    private var lastSent: ComplicationSnapshot?

    /// Zeitpunkt der letzten Uebertragung.
    private var lastSentAt: Date?

    /// Mindestabstand zwischen zwei Uebertragungen.
    ///
    /// Der Inhaltsvergleich allein reicht nicht: `effectiveCalorieGoal` enthaelt die
    /// aktive Energie aus HealthKit und wandert mit jedem Schritt. Ohne Zeitbremse
    /// waere das Kontingent von rund 50 Transfers taeglich in einer Stunde weg, und
    /// danach greift nur noch der Kanal, der die Uhr **nicht** weckt.
    private static let minimumInterval: TimeInterval = 5 * 60

    /// Aenderung, die auch innerhalb der Sperrfrist eine Uebertragung wert ist.
    private static let significantCalorieChange: Double = 50

    /// Stand, der auf die fertige Aktivierung wartet.
    ///
    /// Die Aktivierung laeuft asynchron, der erste Sendeversuch nach dem App-Start
    /// trifft die Sitzung also regelmaessig im Zustand `.inactive`. Ohne dieses
    /// Zwischenlager ginge genau der Push verloren, der nach dem Start am
    /// wichtigsten ist (Issue #69).
    private var pending: ComplicationSnapshot?

    private var session: WCSession? {
        guard WCSession.isSupported() else { return nil }
        return WCSession.default
    }

    private override init() {
        super.init()
    }

    /// Aktiviert die Sitzung. Mehrfachaufruf ist unschaedlich.
    func activate() {
        guard let session, session.activationState != .activated else { return }
        session.delegate = self
        session.activate()
    }

    /// Uebertraegt den Stand, falls er sich geaendert hat.
    /// - Returns: `true`, wenn tatsaechlich uebertragen wurde.
    @discardableResult
    func send(_ snapshot: ComplicationSnapshot) -> Bool {
        guard let session else { return false }

        if let lastSent, lastSent.hasSameValues(as: snapshot) {
            return false
        }
        if let lastSent, let lastSentAt,
           Date().timeIntervalSince(lastSentAt) < Self.minimumInterval,
           abs(lastSent.remainingCalories - snapshot.remainingCalories) < Self.significantCalorieChange,
           lastSent.waterIntakeMl == snapshot.waterIntakeMl {
            return false
        }
        guard session.activationState == .activated else {
            pending = snapshot
            activate()
            return false
        }
        guard session.isPaired, session.isWatchAppInstalled else { return false }

        guard let payload = try? JSONEncoder().encode(snapshot),
              let dict = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            Self.log.error("Snapshot nicht serialisierbar")
            return false
        }

        // Das Kontingent gilt nur fuer den weckenden Kanal. Ist es aufgebraucht,
        // ist der Anwendungskontext besser als nichts: er ueberschreibt sich selbst
        // und liegt bereit, sobald die Uhr das naechste Mal laeuft.
        if session.isComplicationEnabled && session.remainingComplicationUserInfoTransfers > 0 {
            session.transferCurrentComplicationUserInfo(dict)
            Self.log.info("Komplikations-Transfer, verbleibend: \(session.remainingComplicationUserInfoTransfers, privacy: .public)")
        } else {
            try? session.updateApplicationContext(dict)
            Self.log.info("Kontingent erschoepft, Stand ueber den Anwendungskontext geschickt")
        }

        lastSent = snapshot
        lastSentAt = Date()
        return true
    }

    // MARK: - WCSessionDelegate

    // WatchConnectivity ruft die Delegates auf einer eigenen Queue (siehe
    // WatchSnapshotReceiver).
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            Self.log.error("WCSession-Aktivierung fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard activationState == .activated else { return }

        Task { @MainActor in
            Self.shared.sendPending()
        }
    }

    /// Holt den waehrend der Aktivierung zurueckgestellten Stand nach.
    private func sendPending() {
        guard let pending else { return }
        self.pending = nil
        send(pending)
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Nach einem Uhrenwechsel neu aktivieren, sonst laeuft nichts mehr.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
#endif
