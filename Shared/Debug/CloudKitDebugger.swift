//
//  CloudKitDebugger.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 06.02.26.
//

import Foundation
import CloudKit
import SQLite3
import os

/// In-App CloudKit Diagnose — sammelt Log-Eintraege fuer die Debug-UI
@Observable
final class CloudKitDebugger: @unchecked Sendable {
    static let shared = CloudKitDebugger()

    private(set) var logEntries: [LogEntry] = []
    private(set) var isRunning = false

    /// Zaehler fuer Diagnose-Ergebnisse (Reset bei jedem Lauf)
    private var invalidArgErrors = 0
    private var exportCount: Int32 = 0
    private var importCount: Int32 = 0
    private var cloudRecordTotal = 0
    private var ansckRecordMetadataCount: Int32 = 0

    private let log = Logger(subsystem: "com.andre.claassen.KalorienKompass", category: "CloudKitDebug")

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let level: Level
        let message: String

        enum Level: String {
            case info, success, warning, error
        }
    }

    private init() {}

    // MARK: - Logging

    private func append(_ message: String, level: LogEntry.Level = .info) {
        let entry = LogEntry(timestamp: Date(), level: level, message: message)
        Task { @MainActor in
            self.logEntries.append(entry)
        }

        switch level {
        case .info, .success: log.info("\(message, privacy: .public)")
        case .warning: log.warning("\(message, privacy: .public)")
        case .error: log.error("\(message, privacy: .public)")
        }
    }

    func clear() {
        logEntries.removeAll()
    }

    // MARK: - Alle Diagnosen ausfuehren

    func runAllDiagnostics() async {
        guard !isRunning else { return }
        await MainActor.run { isRunning = true }
        clear()

        invalidArgErrors = 0
        exportCount = 0
        importCount = 0
        cloudRecordTotal = 0
        ansckRecordMetadataCount = 0

        append("=== CloudKit Diagnose ===")
        checkBuildInfo()
        checkFileSystem()
        checkANSCKTables()
        await checkAccountStatus()
        await checkZone()
        await checkRecords()
        await checkWriteTest()
        checkRepairFlag()
        checkSummary()
        append("=== Ende Diagnose ===")

        await MainActor.run { isRunning = false }
    }

    // MARK: - Einzelne Checks

    func checkBuildInfo() {
        #if DEBUG
        append("Build: DEBUG")
        #else
        append("Build: RELEASE")
        #endif

        let env = CloudKitConfiguration.detectEnvironment()
        append("Environment: \(env.description)")
        append("Container: \(CloudKitConfiguration.containerIdentifier)")
        append("App Group: \(AppGroupPaths.groupID)")

        if let infoPlist = Bundle.main.object(forInfoDictionaryKey: "CloudKitEnvironment") as? String {
            append("Info.plist CloudKitEnvironment: \(infoPlist)")
        } else {
            append("Info.plist CloudKitEnvironment: nicht gesetzt", level: .warning)
        }
    }

    func checkFileSystem() {
        let storeURL = AppGroupPaths.swiftDataStoreURL()
        let exists = FileManager.default.fileExists(atPath: storeURL.path)
        append("Store-Pfad: \(storeURL.path)")

        if exists {
            let attrs = try? FileManager.default.attributesOfItem(atPath: storeURL.path)
            let size = (attrs?[.size] as? Int64) ?? 0
            let modified = (attrs?[.modificationDate] as? Date)
            append("Store-Groesse: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))", level: .success)
            if let modified {
                append("Zuletzt geaendert: \(formatted(modified))")
            }
        } else {
            append("Store existiert NICHT", level: .warning)
        }

        // ckAssets pruefen
        let ckAssetsURL = storeURL.deletingLastPathComponent()
            .appendingPathComponent("default_ckAssets")
        if FileManager.default.fileExists(atPath: ckAssetsURL.path) {
            append("ckAssets-Cache vorhanden")
        }
    }

    func checkANSCKTables() {
        let storeURL = AppGroupPaths.swiftDataStoreURL()
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }

        var db: OpaquePointer?
        guard sqlite3_open_v2(storeURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            append("SQLite konnte nicht geoeffnet werden", level: .error)
            return
        }
        defer { sqlite3_close(db) }

        // Alle Tabellen auflisten
        var stmt: OpaquePointer?
        let query = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return }

        var dataTables: [(String, Int32)] = []
        var ansckTables: [(String, Int32)] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cString = sqlite3_column_text(stmt, 0) {
                let name = String(cString: cString)
                var countStmt: OpaquePointer?
                let countQuery = "SELECT COUNT(*) FROM \"\(name)\""
                var count: Int32 = 0
                if sqlite3_prepare_v2(db, countQuery, -1, &countStmt, nil) == SQLITE_OK {
                    sqlite3_step(countStmt)
                    count = sqlite3_column_int(countStmt, 0)
                    sqlite3_finalize(countStmt)
                }

                if name.hasPrefix("ANSCK") || name.hasPrefix("Z_CLOUD") {
                    ansckTables.append((name, count))
                } else if name.hasPrefix("Z") && !name.hasPrefix("Z_") {
                    dataTables.append((name, count))
                }
            }
        }
        sqlite3_finalize(stmt)

        if !dataTables.isEmpty {
            append("--- Daten-Tabellen ---")
            for (name, count) in dataTables {
                append("  \(name): \(count) Zeilen")
            }
        }

        if !ansckTables.isEmpty {
            append("--- CloudKit-Metadaten ---")
            for (name, count) in ansckTables {
                let level: LogEntry.Level = count > 0 ? .info : .warning
                append("  \(name): \(count) Zeilen", level: level)

                // Export/Import-Zaehler fuer Zusammenfassung merken
                if name == "ANSCKEXPORTOPERATION" { exportCount = count }
                if name == "ANSCKIMPORTOPERATION" { importCount = count }
                if name == "ANSCKRECORDMETADATA" { ansckRecordMetadataCount = count }
            }
        } else {
            append("Keine ANSCK-Tabellen gefunden", level: .warning)
        }
    }

    func checkAccountStatus() async {
        let container = CKContainer(identifier: CloudKitConfiguration.containerIdentifier)
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                append("iCloud Account: verfuegbar", level: .success)
            case .noAccount:
                append("iCloud Account: NICHT ANGEMELDET", level: .error)
            case .restricted:
                append("iCloud Account: eingeschraenkt", level: .warning)
            case .couldNotDetermine:
                append("iCloud Account: unbekannt", level: .warning)
            case .temporarilyUnavailable:
                append("iCloud Account: temporaer nicht verfuegbar", level: .warning)
            @unknown default:
                append("iCloud Account: unbekannt (\(status))", level: .warning)
            }
        } catch {
            append("Account-Status-Fehler: \(error.localizedDescription)", level: .error)
        }
    }

    func checkZone() async {
        let container = CKContainer(identifier: CloudKitConfiguration.containerIdentifier)
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(
            zoneName: "com.apple.coredata.cloudkit.zone",
            ownerName: CKCurrentUserDefaultName
        )

        do {
            let zone = try await database.recordZone(for: zoneID)
            append("Zone vorhanden: \(zone.zoneID.zoneName)", level: .success)
        } catch let error as CKError where error.code == .zoneNotFound {
            append("Zone existiert NICHT (zoneNotFound)", level: .warning)
        } catch {
            append("Zone-Fehler: \(error.localizedDescription)", level: .error)
            analyzeError(error)
        }
    }

    /// Liest Records ueber Zone-Changes (braucht keine queryable Indexes)
    func checkRecords() async {
        let container = CKContainer(identifier: CloudKitConfiguration.containerIdentifier)
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(
            zoneName: "com.apple.coredata.cloudkit.zone",
            ownerName: CKCurrentUserDefaultName
        )

        append("--- CloudKit Records ---")
        let expectedTypes = [
            "CD_FoodItem", "CD_DiaryEntry", "CD_DayRecord",
            "CD_UserProfile", "CD_FoodCustomization", "CD_CustomUnit"
        ]

        do {
            var typeCounts: [String: Int] = [:]
            var totalRecords = 0
            var moreComing = true
            var changeToken: CKServerChangeToken? = nil
            var pages = 0

            while moreComing && pages < 5 {
                let changes = try await database.recordZoneChanges(
                    inZoneWith: zoneID,
                    since: changeToken
                )

                for (_, result) in changes.modificationResultsByID {
                    if case .success(let modification) = result {
                        typeCounts[modification.record.recordType, default: 0] += 1
                        totalRecords += 1
                    }
                }

                changeToken = changes.changeToken
                moreComing = changes.moreComing
                pages += 1
            }

            if moreComing {
                append("  (Weitere Records vorhanden, nur erste \(pages) Seiten geladen)")
            }

            for recordType in expectedTypes {
                let count = typeCounts[recordType] ?? 0
                let level: LogEntry.Level = count > 0 ? .success : .warning
                append("  \(recordType): \(count) Records", level: level)
            }

            cloudRecordTotal = totalRecords

            if totalRecords == 0 {
                append("  Keine Records in CloudKit gefunden", level: .warning)
            } else {
                append("  Gesamt: \(totalRecords) Records", level: .success)
            }
        } catch {
            let ckCode = (error as? CKError)?.code ?? .internalError
            append("  Zone-Aenderungen nicht lesbar (CKError \(ckCode.rawValue))", level: .error)
            analyzeError(error)

            if ckCode == .invalidArguments {
                invalidArgErrors += 1
            }
        }
    }

    func checkWriteTest() async {
        let container = CKContainer(identifier: CloudKitConfiguration.containerIdentifier)
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(
            zoneName: "com.apple.coredata.cloudkit.zone",
            ownerName: CKCurrentUserDefaultName
        )

        append("--- Schreibtest ---")
        do {
            // Zone erstellen falls noetig
            let zone = CKRecordZone(zoneID: zoneID)
            do {
                try await database.save(zone)
                append("Zone erstellt/bestaetigt", level: .success)
            } catch let error as CKError where error.code == .serverRejectedRequest {
                append("Zone existiert bereits")
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
            append("Schreibtest ERFOLGREICH", level: .success)

            _ = try? await database.deleteRecord(withID: testRecordID)
            append("Test-Record geloescht")
        } catch {
            append("Schreibtest FEHLGESCHLAGEN: \(error.localizedDescription)", level: .error)
            analyzeError(error)
        }
    }

    func checkRepairFlag() {
        let pending = CloudKitConfiguration.isRepairPending
        append("Repair-Flag: \(pending ? "AKTIV" : "inaktiv")", level: pending ? .warning : .info)
    }

    // MARK: - Fehleranalyse

    private func analyzeError(_ error: Error) {
        guard let ckError = error as? CKError else { return }

        append("  CKError Code: \(ckError.code.rawValue)", level: .error)

        switch ckError.code {
        case .notAuthenticated:
            append("  Benutzer nicht authentifiziert", level: .error)
        case .networkUnavailable:
            append("  Netzwerk nicht verfuegbar", level: .error)
        case .quotaExceeded:
            append("  iCloud Speicher voll", level: .error)
        case .badContainer:
            append("  Ungueltiger CloudKit Container", level: .error)
        case .missingEntitlement:
            append("  Fehlende CloudKit Entitlements", level: .error)
        case .zoneNotFound:
            append("  Zone nicht gefunden", level: .warning)
        case .serverRejectedRequest:
            append("  Server hat Anfrage abgelehnt", level: .error)
        case .invalidArguments:
            append("  Fehlende Felder/Indexes im Production-Schema", level: .error)
            append("  -> Schema im CloudKit Dashboard von Development nach Production deployen", level: .error)
        default:
            break
        }

        if let partialErrors = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
            for (key, partialError) in partialErrors {
                append("  Partial [\(key)]: \(partialError.localizedDescription)", level: .error)
            }
        }
        if let underlying = ckError.userInfo[NSUnderlyingErrorKey] as? Error {
            append("  Underlying: \(underlying.localizedDescription)", level: .error)
        }
    }

    // MARK: - Zusammenfassung

    private func checkSummary() {
        append("--- Zusammenfassung ---")

        if invalidArgErrors > 0 {
            append("PROBLEM: CKError 12 (invalidArguments) bei \(invalidArgErrors) Record-Typen", level: .error)
            append("URSACHE: Das Production-CloudKit-Schema kennt neue Felder nicht.", level: .error)
            append("LOESUNG:", level: .warning)
            append("  1. App im DEBUG-Modus starten (nutzt Development-Schema)", level: .warning)
            append("  2. CloudKit Dashboard oeffnen", level: .warning)
            append("  3. Schema von Development nach Production deployen", level: .warning)
            append("  4. Auf dem Geraet: Sync Reparatur ausloesen", level: .warning)
        }

        // ANSCKEXPORTOPERATION/ANSCKIMPORTOPERATION sind transiente Tabellen:
        // Sie sind 0 wenn Sync idle/fertig ist — NICHT nur wenn er nie lief.
        // Massgeblich ist: Wie viele Records sind in CloudKit vorhanden?
        if cloudRecordTotal > 0 {
            append("Sync funktioniert: \(cloudRecordTotal) Records in CloudKit", level: .success)
            if exportCount > 0 || importCount > 0 {
                append("Sync-Engine gerade aktiv (Exports: \(exportCount), Imports: \(importCount))", level: .success)
            } else {
                append("Sync-Engine idle (kein aktiver Export/Import — normal nach abgeschlossenem Sync)")
            }
        } else if invalidArgErrors == 0 {
            // Keine Records in CloudKit UND kein Schema-Fehler → Sync blockiert oder nie gestartet
            if ansckRecordMetadataCount > 0 {
                append("PROBLEM: \(ansckRecordMetadataCount) Records lokal vorhanden, aber 0 in CloudKit", level: .error)
                append("  Moegliche Ursachen:", level: .warning)
                append("  - Production-Schema nicht deployed (CloudKit Dashboard)", level: .warning)
                append("  - NSPersistentCloudKitContainer Initialisierungsfehler", level: .warning)
                append("  -> Pruefe Console.app fuer NSCloudKitMirroringDelegate-Fehler", level: .warning)
                append("  -> Sync Reparatur ausfuehren und App neu starten", level: .warning)
            } else {
                append("Keine lokalen Records und keine CloudKit-Records — leere Datenbank", level: .info)
            }
        }
    }

    // MARK: - Hilfsfunktionen

    private func formatted(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .medium)
    }

    /// Alle Log-Eintraege als Text (fuer Copy/Paste)
    var allLogsAsText: String {
        logEntries.map { entry in
            let ts = formatted(entry.timestamp)
            let prefix: String
            switch entry.level {
            case .success: prefix = "OK"
            case .info: prefix = "INFO"
            case .warning: prefix = "WARN"
            case .error: prefix = "ERR"
            }
            return "[\(ts)] [\(prefix)] \(entry.message)"
        }.joined(separator: "\n")
    }
}
