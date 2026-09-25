//
//  KalorienKompassWatchApp.swift
//  KalorienKompassWatch
//
//  Erstellt von André Claaßen am 06.02.26.
//

#if os(watchOS)
import SwiftUI
import SwiftData
import WidgetKit
import WatchKit
import os

/// Haupteinstiegspunkt der watchOS Companion App
@main
struct KalorienKompassWatchApp: App {

    private static let log = Logger(
        subsystem: "com.andre.claassen.KalorienKompass",
        category: "WatchApp"
    )

    /// Abstand der Hintergrund-Laeufe. watchOS haelt sich nicht strikt daran,
    /// sondern budgetiert selbst — der Wert ist ein Wunsch, keine Zusage.
    private static let backgroundRefreshInterval: TimeInterval = 30 * 60

    init() {
        // Bewusst hier und nicht in `onAppear`: wird diese Extension durch einen
        // eingehenden Transfer im Hintergrund gestartet, rendert SwiftUI keine
        // View. Haenge die Aktivierung an eine View, wird die Sitzung genau dann
        // nicht aktiv, wenn sie gebraucht wird, und der Stand bleibt in der
        // Warteschlange liegen, bis der Nutzer die App oeffnet (Issue #69).
        WatchSnapshotReceiver.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(DataModel.shared.modelContainer)
                .onAppear {
                    // CloudKit-Sync-Monitor initialisieren (lauscht auf Sync-Events)
                    _ = CloudKitSyncMonitor.shared
                    Self.scheduleBackgroundRefresh()
                }
                .task {
                    // CloudKit-Diagnose beim Start ausgeben
                    await CloudKitConfiguration.printDiagnostics()
                }
        }
        // Deckt die Buchungen ab, die **nicht** vom iPhone kommen: Mac, MenuBar
        // oder die `kk`-CLI. Beim Aufwachen laeuft der CloudKit-Import der App,
        // danach zeigt die Komplikation den frischen Stand.
        .backgroundTask(.appRefresh) { _ in
            await Self.handleBackgroundRefresh()
        }
    }

    /// Nach dem Aufwachen: Komplikation neu laden und den naechsten Lauf planen.
    @MainActor
    private static func handleBackgroundRefresh() {
        WidgetCenter.shared.reloadAllTimelines()
        scheduleBackgroundRefresh()
    }

    @MainActor
    private static func scheduleBackgroundRefresh() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date().addingTimeInterval(backgroundRefreshInterval),
            userInfo: nil
        ) { error in
            if let error {
                log.error("Hintergrund-Aktualisierung nicht geplant: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
#endif
