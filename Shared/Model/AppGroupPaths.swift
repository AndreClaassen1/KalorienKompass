//
//  AppGroupPaths.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import Foundation

/// Das URL-Schema dieses Builds.
///
/// Traegt in Debug denselben Zusatz wie Bundle-ID und App Group. Ohne das
/// registrieren Debug- und Release-App dasselbe Schema, und das System waehlt
/// unvorhersehbar, welche einen Widget-Link oder Kurzbefehl bekommt — die Buchung
/// landete dann womoeglich im Debug-Store (Issue #64). Muss zum
/// `CFBundleURLSchemes`-Eintrag in `Secrets.plist` passen.
nonisolated enum DeepLink {
    static let scheme: String = {
        #if DEBUG
        "kalorienkompass.Debug"
        #else
        "kalorienkompass"
        #endif
    }()

    /// `<schema>://<host>` mit optionalem Query-Anhang
    static func url(_ path: String) -> URL? {
        URL(string: "\(scheme)://\(path)")
    }
}

/// Praefix aller Kennungen dieser App (Bundle-ID, App Group, iCloud-Container).
///
/// Muss zum Build-Setting `BUNDLE_ID_PREFIX` auf Projektebene passen. Wer die App
/// unter eigenem Team baut, aendert beide Stellen; `AppGroupPathsTests` meldet,
/// wenn sie auseinanderlaufen. Bewusst eine Konstante statt eines Info.plist-
/// Werts: die App-Group-Kennung entscheidet, welchen Store die App oeffnet, und
/// darf zur Laufzeit nicht von einem fehlenden Plist-Eintrag abhaengen.
nonisolated enum BundleIDs {
    static let prefix = "com.andre.claassen"
}

/// Zentrale Verwaltung der App-Group-Pfade fuer gemeinsamen Datenzugriff
nonisolated enum AppGroupPaths {

    /// Die App Group dieses Builds.
    ///
    /// Debug-Builds arbeiten auf einem **eigenen** Store und koennen die
    /// Produktionsdaten damit weder migrieren noch zuruecksetzen (Issue #64).
    /// Frueher teilten sich beide denselben Container, und ein Debug-Build mit
    /// neuerem Schema konnte den Store so veraendern, dass der Release-Build ihn
    /// nicht mehr oeffnen konnte — einer der Wege in den Datenverlust vom
    /// 24.07.2026.
    ///
    /// Muss zum Build-Setting `APP_GROUP_ID` passen, aus dem die Entitlements
    /// gespeist werden; `AppGroupPathsTests` prueft genau das. Bewusst ueber
    /// `#if DEBUG` statt ueber `BUNDLE_ID_SUFFIX`: die MenuBar-Variante hat zwar
    /// eine eigene Bundle-ID, soll aber denselben Tag zeigen wie die App und
    /// deshalb dieselbe Group nutzen.
    static let groupID: String = {
        #if DEBUG
        "group.\(BundleIDs.prefix).KalorienKompass.Debug"
        #else
        "group.\(BundleIDs.prefix).KalorienKompass"
        #endif
    }()

    static func sharedContainer() -> URL {
        return FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupID
        )!
    }

    /// SwiftData-Store-URL (automatisch von SwiftData bei groupContainer: erstellt)
    static func swiftDataStoreURL() -> URL {
        return sharedContainer()
            .appendingPathComponent("Library/Application Support/default.store")
    }


    /// Alle zum Store gehoerenden Dateien (Hauptdatei plus WAL/SHM).
    static func storeFileURLs() -> [URL] {
        let db = swiftDataStoreURL()
        return [
            db,
            URL(fileURLWithPath: db.path + "-wal"),
            URL(fileURLWithPath: db.path + "-shm")
        ]
    }

    /// Verschiebt die Store-Dateien in einen timestamped Backup-Ordner neben dem
    /// Store und entfernt damit die Originale in einem Schritt. Nichts wird
    /// unwiederbringlich geloescht — der Store kann jederzeit aus dem Backup
    /// wiederhergestellt werden. Gibt den Backup-Ordner zurueck, oder `nil`,
    /// wenn kein Store existierte.
    @discardableResult
    static func backupAndResetStoreFiles() throws -> URL? {
        let fm = FileManager.default
        let db = swiftDataStoreURL()
        guard fm.fileExists(atPath: db.path) else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let stamp = formatter.string(from: Date())

        let backupDir = db.deletingLastPathComponent()
            .appendingPathComponent("store-backup-\(stamp)", isDirectory: true)
        try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)

        for url in storeFileURLs() where fm.fileExists(atPath: url.path) {
            let dest = backupDir.appendingPathComponent(url.lastPathComponent)
            try fm.moveItem(at: url, to: dest)
        }
        return backupDir
    }
}
