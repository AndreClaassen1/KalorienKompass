//
//  WatchSnapshotReceiver.swift
//  KalorienKompassWatch
//
//  Erstellt von André Claaßen am 26.07.26.
//

#if os(watchOS)
import Foundation
import WatchConnectivity
import WidgetKit
import os

/// Nimmt die Zahlen entgegen, die das iPhone fuer die Komplikation schickt.
///
/// Der Empfang weckt diese Extension im Hintergrund, ohne dass die Watch-App
/// geoeffnet wird — deshalb kann die Komplikation ueberhaupt aktuell sein, obwohl
/// der lokale Store der Uhr noch auf dem alten Stand steht (Issue #69).
///
/// Muss frueh aktiviert werden, damit ausstehende Uebertragungen zugestellt werden:
/// die Watch-App tut das beim Start.
final class WatchSnapshotReceiver: NSObject, WCSessionDelegate {

    static let shared = WatchSnapshotReceiver()

    private static let log = Logger(
        subsystem: "com.andre.claassen.KalorienKompass",
        category: "WatchSnapshot"
    )

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState != .activated else { return }
        session.delegate = self
        session.activate()

        // Ein waehrend der Ruhe gesetzter Anwendungskontext wird nicht zwingend
        // nachgeliefert — deshalb hier einmal aktiv abholen.
        if !session.receivedApplicationContext.isEmpty {
            apply(session.receivedApplicationContext, kanal: "Anwendungskontext (nachgeholt)")
        }
    }

    // MARK: - Empfang

    // WatchConnectivity ruft die Delegates auf einer eigenen Queue. Das Target
    // kompiliert mit `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, also muessen die
    // Callbacks ausdruecklich `nonisolated` sein.
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        apply(userInfo, kanal: "Komplikations-Transfer")
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext, kanal: "Anwendungskontext")
    }

    nonisolated private func apply(_ dict: [String: Any], kanal: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let snapshot = try? JSONDecoder().decode(ComplicationSnapshot.self, from: data) else {
            Self.log.error("Empfangener Stand ist unlesbar (\(kanal, privacy: .public))")
            return
        }

        // Aeltere Staende verwerfen: Uebertragungen koennen sich ueberholen, und die
        // Komplikation darf nie zurueckspringen.
        if let vorhanden = ComplicationSnapshot.stored(.received), vorhanden.updatedAt >= snapshot.updatedAt {
            return
        }

        snapshot.store(as: .received)
        WidgetCenter.shared.reloadAllTimelines()
        Self.log.info("Stand uebernommen (\(kanal, privacy: .public)), Rest: \(Int(snapshot.remainingCalories), privacy: .public) kcal")
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            Self.log.error("WCSession-Aktivierung fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
        }
    }
}
#endif
