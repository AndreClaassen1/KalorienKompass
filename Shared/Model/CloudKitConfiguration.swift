//
//  CloudKitConfiguration.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import Foundation
import SwiftData
import CloudKit
import SQLite3
import os

/// Prueft ob der aktuelle Prozess als Widget-Extension laeuft
nonisolated func isRunningAsWidgetExtension() -> Bool {
    Bundle.main.bundleURL.pathExtension == "appex"
}

/// Konfiguration fuer CloudKit-Synchronisation
nonisolated struct CloudKitConfiguration {

    /// Der CloudKit-Container dieses Builds. Debug-Builds nutzen einen eigenen
    /// und koennen die Produktionszone damit nicht anfassen (Issue #64).
    /// Muss zum Build-Setting `ICLOUD_CONTAINER_ID` passen.
    static let containerIdentifier: String = {
        #if DEBUG
        "iCloud.\(BundleIDs.prefix).KalorienKompass.Debug"
        #else
        "iCloud.\(BundleIDs.prefix).KalorienKompass"
        #endif
    }()
    private static let log = Logger(subsystem: "com.andre.claassen.KalorienKompass", category: "CloudKit")

    /// Erkennt automatisch die korrekte CloudKit Environment
    static func detectEnvironment() -> CloudKitEnvironment {
        if let cloudKitEnvironment = Bundle.main.object(forInfoDictionaryKey: "CloudKitEnvironment") as? String {
            return cloudKitEnvironment.lowercased() == "production" ? .production : .development
        }

        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }

    /// Erstellt die passende ModelConfiguration fuer CloudKit
    ///
    /// Verwendet `groupContainer` statt `url`, damit SwiftData den
    /// NSCloudKitMirroringDelegate korrekt initialisiert.
    static func createModelConfiguration() -> ModelConfiguration {
        let environment = detectEnvironment()

        log.info("Environment erkannt: \(environment, privacy: .public)")
        log.info("Container: \(containerIdentifier, privacy: .public)")
        log.info("App Group: \(AppGroupPaths.groupID, privacy: .public)")

        return ModelConfiguration(
            groupContainer: .identifier(AppGroupPaths.groupID),
            cloudKitDatabase: .private(containerIdentifier)
        )
    }

    // MARK: - Sync Repair

    private static let repairFlagKey = "cloudkit_repair_pending"

    /// Prueft ob eine lokale Bereinigung beim naechsten Start ansteht
    static var isRepairPending: Bool {
        UserDefaults(suiteName: AppGroupPaths.groupID)?.bool(forKey: repairFlagKey) ?? false
    }

    /// Loescht die CloudKit-Zone und plant lokale Metadaten-Bereinigung
    ///
    /// Zweistufiger Prozess:
    /// 1. Zone auf dem Server loeschen (sofort)
    /// 2. Lokale CloudKit-Metadaten beim naechsten App-Start bereinigen
    ///
    /// Die eigentlichen Daten (Mahlzeiten, Profil etc.) bleiben erhalten.
    /// Nach Neustart exportiert der Mirroring-Delegate alles neu.
    static func repairSync() async throws {
        // Schritt 1: Zone auf Server loeschen
        let container = CKContainer(identifier: containerIdentifier)
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(
            zoneName: "com.apple.coredata.cloudkit.zone",
            ownerName: CKCurrentUserDefaultName
        )

        log.info("Sync Reparatur: Loesche Zone auf Server...")
        do {
            try await database.deleteRecordZone(withID: zoneID)
            log.info("Sync Reparatur: Zone geloescht.")
        } catch let error as CKError where error.code == .zoneNotFound {
            log.info("Sync Reparatur: Zone existiert nicht (bereits geloescht).")
        }

        // Schritt 2: Flag fuer lokale Bereinigung beim naechsten Start setzen
        UserDefaults(suiteName: AppGroupPaths.groupID)?.set(true, forKey: repairFlagKey)
        log.info("Sync Reparatur: Lokale Bereinigung beim naechsten Start geplant.")
    }

    /// Fuehrt die lokale CloudKit-Metadaten-Bereinigung durch
    ///
    /// Muss VOR dem Erstellen des ModelContainers aufgerufen werden,
    /// da die SQLite-Datei direkt manipuliert wird.
    /// Loescht nur die ANSCK*-Tabellen (CloudKit-Tracking-Daten),
    /// nicht die eigentlichen Daten-Tabellen.
    static func performPendingRepairIfNeeded() {
        guard isRepairPending else { return }

        log.info("Sync Reparatur: Starte lokale Bereinigung...")

        let storeURL = AppGroupPaths.swiftDataStoreURL()
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            log.warning("Sync Reparatur: Keine Datenbank vorhanden, ueberspringe.")
            clearRepairFlag()
            return
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(storeURL.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            log.error("Sync Reparatur: Datenbank konnte nicht geoeffnet werden")
            clearRepairFlag()
            return
        }
        defer { sqlite3_close(db) }

        // WAL-Checkpoint um alle Aenderungen in die Hauptdatei zu schreiben
        sqlite3_exec(db, "PRAGMA wal_checkpoint(TRUNCATE)", nil, nil, nil)

        // CloudKit-Metadaten-Tabellen finden (ANSCK* = Apple NS CloudKit)
        var stmt: OpaquePointer?
        let query = "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'ANSCK%'"
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            log.error("Sync Reparatur: Query fehlgeschlagen")
            clearRepairFlag()
            return
        }

        var tables: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cString = sqlite3_column_text(stmt, 0) {
                tables.append(String(cString: cString))
            }
        }
        sqlite3_finalize(stmt)

        if tables.isEmpty {
            log.info("Sync Reparatur: Keine ANSCK-Tabellen gefunden")
        } else {
            for table in tables {
                if sqlite3_exec(db, "DELETE FROM \"\(table)\"", nil, nil, nil) == SQLITE_OK {
                    log.info("Sync Reparatur: \(table, privacy: .public) bereinigt")
                } else {
                    let error = String(cString: sqlite3_errmsg(db))
                    log.error("Sync Reparatur: Fehler bei \(table, privacy: .public): \(error, privacy: .public)")
                }
            }
        }

        // ckAssets-Cache loeschen (default_ckAssets im selben Verzeichnis)
        let ckAssetsURL = storeURL.deletingLastPathComponent()
            .appendingPathComponent("default_ckAssets")
        if FileManager.default.fileExists(atPath: ckAssetsURL.path) {
            try? FileManager.default.removeItem(at: ckAssetsURL)
            log.info("Sync Reparatur: ckAssets-Cache geloescht")
        }

        clearRepairFlag()
        log.info("Sync Reparatur: Lokale Bereinigung abgeschlossen")
    }

    private static func clearRepairFlag() {
        UserDefaults(suiteName: AppGroupPaths.groupID)?.removeObject(forKey: repairFlagKey)
    }

    // MARK: - Diagnose

    /// Gibt detaillierte Diagnose-Informationen ueber den CloudKit-Sync-Zustand aus
    static func printDiagnostics() async {
        log.info("=== CloudKit Sync Diagnose ===")

        // 1. Store-Pfad und Existenz
        let storeURL = AppGroupPaths.swiftDataStoreURL()
        let storeExists = FileManager.default.fileExists(atPath: storeURL.path)
        log.info("Store-Pfad: \(storeURL.path, privacy: .public)")
        log.info("Store existiert: \(storeExists, privacy: .public)")

        if storeExists {
            let attrs = try? FileManager.default.attributesOfItem(atPath: storeURL.path)
            let size = (attrs?[.size] as? Int64) ?? 0
            log.info("Store-Groesse: \(size, privacy: .public) Bytes")
        }

        // 2. SQLite-Tabellen auflisten
        if storeExists {
            var db: OpaquePointer?
            if sqlite3_open_v2(storeURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK {
                defer { sqlite3_close(db) }

                var stmt: OpaquePointer?
                let query = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
                if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                    log.info("--- Alle Tabellen ---")
                    while sqlite3_step(stmt) == SQLITE_ROW {
                        if let cString = sqlite3_column_text(stmt, 0) {
                            let tableName = String(cString: cString)
                            var countStmt: OpaquePointer?
                            let countQuery = "SELECT COUNT(*) FROM \"\(tableName)\""
                            if sqlite3_prepare_v2(db, countQuery, -1, &countStmt, nil) == SQLITE_OK {
                                sqlite3_step(countStmt)
                                let count = sqlite3_column_int(countStmt, 0)
                                log.info("  \(tableName, privacy: .public): \(count, privacy: .public) Zeilen")
                                sqlite3_finalize(countStmt)
                            }
                        }
                    }
                    sqlite3_finalize(stmt)
                }
            } else {
                log.error("SQLite konnte nicht geoeffnet werden")
            }
        }

        // 3. CloudKit Account Status
        let container = CKContainer(identifier: containerIdentifier)
        do {
            let status = try await container.accountStatus()
            log.info("--- CloudKit Account ---")
            switch status {
            case .available: log.info("Status: verfuegbar")
            case .noAccount: log.error("Status: KEIN ACCOUNT")
            case .restricted: log.warning("Status: eingeschraenkt")
            case .couldNotDetermine: log.warning("Status: unbekannt")
            case .temporarilyUnavailable: log.warning("Status: temporaer nicht verfuegbar")
            @unknown default: log.warning("Status: unbekannt (\(String(describing: status), privacy: .public))")
            }
        } catch {
            log.error("Account-Status-Fehler: \(error, privacy: .public)")
        }

        // 4. CloudKit Zone pruefen
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(
            zoneName: "com.apple.coredata.cloudkit.zone",
            ownerName: CKCurrentUserDefaultName
        )
        log.info("--- CloudKit Zone ---")
        do {
            let zone = try await database.recordZone(for: zoneID)
            log.info("Zone existiert: \(zone.zoneID.zoneName, privacy: .public)")
        } catch let error as CKError where error.code == .zoneNotFound {
            log.warning("Zone existiert NICHT (zoneNotFound)")
        } catch {
            log.error("Zone-Abfrage-Fehler: \(error, privacy: .public)")
        }

        // 5. CloudKit Records zaehlen (Zone-Changes, braucht keine Indexes)
        log.info("--- CloudKit Records ---")
        do {
            var typeCounts: [String: Int] = [:]
            var total = 0
            var moreComing = true
            var token: CKServerChangeToken? = nil
            var pages = 0

            while moreComing && pages < 5 {
                let changes = try await database.recordZoneChanges(
                    inZoneWith: zoneID,
                    since: token
                )
                for (_, result) in changes.modificationResultsByID {
                    if case .success(let modification) = result {
                        typeCounts[modification.record.recordType, default: 0] += 1
                        total += 1
                    }
                }
                token = changes.changeToken
                moreComing = changes.moreComing
                pages += 1
            }

            for (type, count) in typeCounts.sorted(by: { $0.key < $1.key }) {
                log.info("  \(type, privacy: .public): \(count, privacy: .public) Records")
            }
            log.info("  Gesamt: \(total, privacy: .public) Records")
        } catch {
            let ckErr = (error as? CKError)?.code.rawValue ?? -1
            log.error("  Zone-Aenderungen nicht lesbar (CKError \(ckErr, privacy: .public))")
        }

        // 6. Direkter Schreibtest — versucht einen Test-Record zu speichern
        log.info("--- CloudKit Schreibtest ---")
        do {
            let zone = CKRecordZone(zoneID: zoneID)
            do {
                try await database.save(zone)
                log.info("Zone erstellt/bestaetigt")
            } catch let error as CKError where error.code == .serverRejectedRequest {
                log.info("Zone existiert bereits")
            }

            let testRecordID = CKRecord.ID(
                recordName: "DIAG_TEST_\(UUID().uuidString)",
                zoneID: zoneID
            )
            let testRecord = CKRecord(recordType: "CD_DayRecord", recordID: testRecordID)
            testRecord["CD_recordId"] = UUID().uuidString as CKRecordValue
            testRecord["CD_date"] = Date() as CKRecordValue
            testRecord["CD_steps"] = 0 as CKRecordValue
            testRecord["CD_waterIntakeMl"] = 0 as CKRecordValue
            testRecord["CD_activeEnergyKcal"] = 0 as CKRecordValue
            testRecord["CD_workoutCaloriesKcal"] = 0 as CKRecordValue

            try await database.save(testRecord)
            log.info("Schreibtest ERFOLGREICH — CloudKit Production akzeptiert Records")

            _ = try? await database.deleteRecord(withID: testRecordID)
            log.info("Test-Record wieder geloescht")
        } catch {
            log.error("Schreibtest FEHLGESCHLAGEN: \(error, privacy: .public)")
            if let ckError = error as? CKError {
                log.error("CKError Code: \(ckError.code.rawValue, privacy: .public)")
                if let partialErrors = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
                    for (key, partialError) in partialErrors {
                        log.error("Partial Error [\(String(describing: key), privacy: .public)]: \(partialError, privacy: .public)")
                    }
                }
                if let underlying = ckError.userInfo[NSUnderlyingErrorKey] as? Error {
                    log.error("Underlying: \(underlying, privacy: .public)")
                }
            }
        }

        // 7. Repair-Flag Status
        let repairPending = UserDefaults(suiteName: AppGroupPaths.groupID)?.bool(forKey: repairFlagKey) ?? false
        log.info("--- Status ---")
        log.info("Repair-Flag: \(repairPending, privacy: .public)")
        log.info("=== Ende Diagnose ===")
    }

    /// Prueft ob CloudKit korrekt konfiguriert ist
    static func validateCloudKitSetup() {
        guard !isRunningAsWidgetExtension() else {
            log.info("Keine Validierung in App Extension.")
            return
        }

        let container = CKContainer(identifier: containerIdentifier)

        container.accountStatus { status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    log.info("Account verfuegbar")
                case .noAccount:
                    log.error("Kein iCloud Account angemeldet")
                case .restricted:
                    log.warning("iCloud Account eingeschraenkt")
                case .couldNotDetermine:
                    log.warning("iCloud Account Status unbekannt")
                case .temporarilyUnavailable:
                    log.warning("iCloud Account temporaer nicht verfuegbar")
                @unknown default:
                    log.warning("Unbekannter iCloud Account Status")
                }

                if let error {
                    log.error("Setup Fehler: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }
}

/// CloudKit-Umgebungstypen
nonisolated enum CloudKitEnvironment: CustomStringConvertible {
    case development
    case production

    var description: String {
        switch self {
        case .development: "Development"
        case .production: "Production"
        }
    }
}
