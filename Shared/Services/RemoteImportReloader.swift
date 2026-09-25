//
//  RemoteImportReloader.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 21.07.26.
//
//  Kapselt das mehrfach kopierte CloudKit-Import-Observer-Muster: beobachtet
//  `NSPersistentCloudKitContainer.eventChangedNotification`, filtert auf
//  abgeschlossene, fehlerfreie `.import`-Events und loest nach einem kurzen
//  Debounce genau einen Reload aus. Ersetzt die handkopierten
//  setupCloudKitObserver/debouncedLoadToday-Bloecke in den ViewModels.
//
//  Notification-Auswertung analog zu `CloudKitSyncMonitor` (Shared/Debug/),
//  hier aber produktiv fuer den Auto-Refresh der Ansichten.
//

import Foundation
import CoreData
import os

/// Loest einen debounced Reload aus, sobald ein CloudKit-Import abgeschlossen ist.
///
/// Verwendung: als gehaltene Property im ViewModel anlegen, der Closure bekommt
/// den eigentlichen Reload:
/// ```swift
/// reloader = RemoteImportReloader { [weak self] in self?.load() }
/// ```
/// Die Registrierung passiert im Initializer, der Cleanup im deinit.
@MainActor
final class RemoteImportReloader {
    private static let logger = Logger(subsystem: "com.andre.claassen.KalorienKompass", category: "RemoteImportReloader")

    /// Einheitlicher Debounce fuer alle Aufrufer: gebuendelte Import-Events
    /// loesen nur einen Reload aus.
    private static let debounce: Duration = .seconds(1.5)

    private let onReload: @MainActor () async -> Void
    private var observer: NSObjectProtocol?
    private var debounceTask: Task<Void, Never>?

    /// - Parameter onReload: wird auf dem MainActor ausgefuehrt, nachdem ein
    ///   CloudKit-Import abgeschlossen ist und der Debounce abgelaufen ist.
    ///   Darf synchron oder `async` sein — der async-Reload laeuft dann noch
    ///   innerhalb des Debounce-Tasks.
    init(onReload: @escaping @MainActor () async -> Void) {
        self.onReload = onReload
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                  event.type == .import,
                  event.endDate != nil,
                  event.error == nil else { return }
            self.scheduleReload()
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        debounceTask?.cancel()
    }

    /// Bricht einen laufenden Debounce ab und plant den Reload neu.
    private func scheduleReload() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled, let self else { return }
            Self.logger.info("CloudKit-Import abgeschlossen, loese Reload aus")
            await self.onReload()
        }
    }
}
