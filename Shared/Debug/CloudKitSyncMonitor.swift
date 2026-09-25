//
//  CloudKitSyncMonitor.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 07.02.26.
//

import Foundation
import CoreData
import CloudKit
import os

/// Beobachtet CloudKit-Sync-Events und stellt den aktuellen Status bereit
@Observable
final class CloudKitSyncMonitor: @unchecked Sendable {
    static let shared = CloudKitSyncMonitor()

    private let log = Logger(subsystem: "com.andre.claassen.KalorienKompass", category: "SyncMonitor")

    // MARK: - Oeffentlicher Status

    enum SyncState: Equatable {
        case unknown
        case syncing
        case upToDate
        case error(String)
    }

    private(set) var syncState: SyncState = .unknown
    private(set) var lastSuccessfulSync: Date?

    /// True solange ein Import oder Export laeuft
    private(set) var isImporting = false
    private(set) var isExporting = false

    // MARK: - Intern

    private var observer: NSObjectProtocol?

    private init() {
        startListening()
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    // MARK: - Event-Beobachtung

    private func startListening() {
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { return }
            self.handleEvent(event)
        }
    }

    private func handleEvent(_ event: NSPersistentCloudKitContainer.Event) {
        let typeName: String
        switch event.type {
        case .setup: typeName = "Setup"
        case .import: typeName = "Import"
        case .export: typeName = "Export"
        @unknown default: typeName = "Unknown"
        }

        if event.endDate == nil {
            // Event gestartet
            switch event.type {
            case .import: isImporting = true
            case .export: isExporting = true
            default: break
            }
            syncState = .syncing
        } else {
            // Event abgeschlossen
            switch event.type {
            case .import: isImporting = false
            case .export: isExporting = false
            default: break
            }

            if let error = event.error {
                log.error("CloudKit \(typeName, privacy: .public) FEHLER: \(error.localizedDescription, privacy: .public)")
                logDetailedError(error, type: typeName)
                syncState = .error(describeError(error))
            } else {
                log.info("CloudKit \(typeName, privacy: .public) erfolgreich")
                lastSuccessfulSync = event.endDate ?? Date()

                // Nur auf upToDate setzen wenn kein anderer Vorgang laeuft
                if !isImporting && !isExporting {
                    syncState = .upToDate
                }
            }
        }
    }

    // MARK: - Fehleraufbereitung

    private func describeError(_ error: Error) -> String {
        guard let ckError = error as? CKError else {
            return error.localizedDescription
        }

        // Partial Failure: tieferen Fehler extrahieren
        if ckError.code == .partialFailure,
           let partials = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
            for (_, partial) in partials {
                if let msg = (partial as? CKError)?.userInfo["ServerErrorDescription"] as? String {
                    return msg
                }
            }
        }

        switch ckError.code {
        case .networkUnavailable, .networkFailure:
            return String(localized: "sync_error_network")
        case .notAuthenticated:
            return String(localized: "sync_error_not_authenticated")
        case .quotaExceeded:
            return String(localized: "sync_error_quota")
        case .invalidArguments:
            return String(localized: "sync_error_schema")
        default:
            return error.localizedDescription
        }
    }

    private func logDetailedError(_ error: Error, type: String) {
        guard let ckError = error as? CKError else { return }

        log.error("CKError Code: \(ckError.code.rawValue, privacy: .public)")

        if let partialErrors = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
            for (key, partialError) in partialErrors {
                log.error("Partial [\(String(describing: key), privacy: .public)]: \(partialError, privacy: .public)")
            }
        }
        if let underlying = ckError.userInfo[NSUnderlyingErrorKey] as? Error {
            log.error("Underlying: \(underlying, privacy: .public)")
        }
    }
}
