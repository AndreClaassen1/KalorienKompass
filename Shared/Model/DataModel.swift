//
//  DataModel.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//
//  Actor-basiertes Singleton fuer thread-sicheren Zugriff auf den
//  SwiftData ModelContainer. Muster aus AboveAndBeyond uebernommen.
//

import SwiftUI
import SwiftData
import os

/// Actor fuer thread-sicheren Zugriff auf das Datenmodell
actor DataModel {

    private static let log = Logger(subsystem: "com.andre.claassen.KalorienKompass", category: "DataModel")

    /// Transaktions-Autoren zur Identifikation von Aenderungsquellen
    struct TransactionAuthor {
        static let widget = "widget"
    }

    /// Singleton-Instanz
    static let shared = DataModel()

    /// Konstanter ModelContainer, ausserhalb der Actor-Isolation erstellt
    nonisolated let modelContainer: ModelContainer = DataModel.makeContainer()

    private init() {}

    /// Erstellt den ModelContainer mit CloudKit-Konfiguration.
    ///
    /// Gestaffelte Recovery, damit ein kaputter oder inkompatibler Store die
    /// ausgelieferte App **nicht** beim Start crasht (frueher `fatalError`,
    /// nur im DEBUG gab es einen Fallback). Die Stufen von schonend nach hart:
    /// 1. Normaler Container (App: CloudKit, Widget: lokal)
    /// 2. Lokal-only ohne CloudKit — rettet alle Daten, falls CloudKit die
    ///    Ursache war (Sync ist bis zum naechsten Start deaktiviert)
    /// 3. Store sichern und frisch aufbauen — CloudKit synct die Daten zurueck
    /// 4. Letzter Ausweg: In-Memory-Container, damit die App ueberhaupt startet
    private static func makeContainer() -> ModelContainer {
        let isWidget = isRunningAsWidgetExtension()

        // Ausstehende CloudKit-Sync-Reparatur durchfuehren (vor Container-Erstellung!)
        if !isWidget {
            CloudKitConfiguration.performPendingRepairIfNeeded()
        }

        let schema = Schema([
            FoodItem.self,
            DiaryEntry.self,
            DayRecord.self,
            UserProfile.self,
            FoodCustomization.self,
            CustomUnit.self,
            FocusLever.self,
            FocusLeverCheck.self,
            PlannedEntry.self
        ])

        // Lokale (CloudKit-freie) Konfiguration auf demselben App-Group-Store
        let localConfig = ModelConfiguration(
            groupContainer: .identifier(AppGroupPaths.groupID)
        )

        // Primaere Konfiguration: App nutzt CloudKit, Widget bleibt lokal
        func primaryConfig() -> ModelConfiguration {
            isWidget ? localConfig : CloudKitConfiguration.createModelConfiguration()
        }

        // Stufe 1: Normaler Versuch
        do {
            if !isWidget {
                CloudKitConfiguration.validateCloudKitSetup()
            }
            let container = try ModelContainer(for: schema, configurations: primaryConfig())
            for storeDesc in container.configurations {
                log.info("ModelContainer Config: \(storeDesc.name, privacy: .public)")
                log.info("CloudKit Database: \(String(describing: storeDesc.cloudKitDatabase), privacy: .public)")
                log.info("Group Container: \(String(describing: storeDesc.groupContainer), privacy: .public)")
            }
            return container
        } catch {
            log.error("ModelContainer-Init fehlgeschlagen: \(error, privacy: .public)")
        }

        // Stufen 2 und 3 nur aus der App, nie aus einer Extension — sonst
        // koennte ein Widget den geteilten Store der App unter den Fuessen wegziehen.
        if !isWidget {
            // Stufe 2: Lokal-only ohne CloudKit — rettet alle Daten, falls
            // CloudKit die Ursache war (Sync bis zum naechsten Start deaktiviert)
            do {
                let container = try ModelContainer(for: schema, configurations: localConfig)
                log.warning("Fallback: lokaler Container ohne CloudKit — Sync bis zum Neustart deaktiviert")
                return container
            } catch {
                log.error("Lokaler Fallback-Container fehlgeschlagen: \(error, privacy: .public)")
            }

            // Stufe 3: Store sichern und frisch aufbauen — CloudKit synct zurueck
            do {
                if let backup = try AppGroupPaths.backupAndResetStoreFiles() {
                    log.warning("Store gesichert nach \(backup.path, privacy: .public) und zurueckgesetzt")
                }
                return try ModelContainer(for: schema, configurations: primaryConfig())
            } catch {
                log.error("Neuaufbau nach Store-Reset fehlgeschlagen: \(error, privacy: .public)")
            }
        }

        // Stufe 4: Letzter Ausweg — In-Memory, damit die App startet statt zu crashen
        do {
            let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: memoryConfig)
            log.fault("Letzter Ausweg: In-Memory-Container — Daten werden nicht persistiert")
            return container
        } catch {
            fatalError("ModelContainer konnte auf keinem Weg erstellt werden: \(error)")
        }
    }
}

// MARK: - Duplikat-Bereinigung nach CloudKit-Import

/// Raeumt CloudKit-Duplikate auf, und zwar genau dann, wenn sie entstehen:
/// nach einem abgeschlossenen Import.
///
/// Bis Issue #67 wurden Duplikate nur nebenbei bereinigt, wenn zufaellig jemand
/// denselben Tag beschrieb. Vergangene Tage blieben damit dauerhaft doppelt, und
/// die Bereichs-Auswertungen lasen sie. Der Anzeigepfad ist aber der falsche Ort
/// dafuer (Issues #63 und #65): dort kann ein gerade eintreffender Datensatz wie
/// ein Duplikat aussehen. Nach abgeschlossenem Import ist beides erfuellt — die
/// Duplikate sind da, und nichts ist mehr unterwegs.
///
/// Anders als die `canonical`-Methoden der Modelle, die im Schreibpfad einen
/// einzelnen Tag bereinigen, geht dieser Durchlauf ueber den gesamten Bestand.
/// Deshalb laeuft er nur in der App, nie in Widget oder Watch, hoechstens einmal
/// je `throttle`-Fenster, und auf einem eigenen Kontext: ein Fehlschlag darf
/// keine ungespeicherten Eingaben aus dem `mainContext` verwerfen.
@MainActor
enum DuplicateCleanup {

    private static let log = Logger(
        subsystem: "com.andre.claassen.KalorienKompass",
        category: "DuplicateCleanup"
    )

    /// Mindestabstand zwischen zwei Durchlaeufen. CloudKit meldet auch nach jedem
    /// eigenen Export einen Import, sonst liefe der Sweep bei jeder Buchung.
    private static let throttle: TimeInterval = 600

    /// Zeitstempel in der App Group: drosselt auch ueber Prozessgrenzen hinweg,
    /// weil regulaere App und MenuBar-Variante denselben Store teilen.
    private static let lastRunKey = "duplicateCleanup.lastRun"

    /// Gedrosselte Variante fuer den Import-Hook. Die Drosselung sitzt bewusst
    /// hier und nicht in `run`: so bleibt der eigentliche Durchlauf frei von
    /// verstecktem Zustand und ist ohne Umwege testbar.
    @discardableResult
    static func runIfDue(in context: ModelContext) -> Int {
        if let last = defaults.object(forKey: lastRunKey) as? Date,
           Date().timeIntervalSince(last) < throttle {
            return 0
        }
        defaults.set(Date(), forKey: lastRunKey)
        return run(in: context)
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroupPaths.groupID) ?? .standard
    }

    /// Fuehrt Duplikate von `DayRecord`, `UserProfile`, `FocusLeverCheck`,
    /// `PlannedEntry` und mehrfach aktiven `FocusLever` zusammen.
    ///
    /// Verlustfrei: Zaehlwerte werden per `max` gefaltet, optionale Felder
    /// uebernehmen den Wert des kanonischen Datensatzes, ein Profil mit echten
    /// Werten gewinnt gegen ein unberuehrtes Default-Profil, und ueberzaehlige
    /// Hebel werden abgeloest statt geloescht.
    ///
    /// Die Verdrahtung an den CloudKit-Import steht in `CaloryGuardApp`: diese
    /// Datei wird auch von Widget und Watch kompiliert, die weder den
    /// `RemoteImportReloader` kennen noch bereinigen duerfen.
    ///
    /// - Returns: Anzahl der entfernten Datensaetze.
    @discardableResult
    static func run(in context: ModelContext) -> Int {
        var removed = 0
        removed += mergeDayRecords(in: context)
        removed += mergeProfiles(in: context)
        removed += mergeLeverChecks(in: context)
        removed += mergePlannedEntries(in: context)
        let retired = retireSurplusLevers(in: context)

        guard removed > 0 || retired > 0 else { return 0 }

        do {
            try context.save()
            log.info("Bereinigt: \(removed, privacy: .public) Duplikate entfernt, \(retired, privacy: .public) Hebel abgeloest")
        } catch {
            log.error("Bereinigung fehlgeschlagen: \(error, privacy: .public)")
            context.rollback()
            return 0
        }
        return removed
    }

    /// Ein Record je Kalendertag, gefaltet ueber `DayRecord.mergeDuplicates`.
    private static func mergeDayRecords(in context: ModelContext) -> Int {
        let records = (try? context.fetch(FetchDescriptor<DayRecord>())) ?? []
        var removed = 0

        for (_, sameDay) in Dictionary(grouping: records, by: { $0.date.startOfDay }) {
            guard sameDay.count > 1, let primary = DayRecord.primary(of: sameDay) else { continue }
            removed += DayRecord.mergeDuplicates(sameDay, into: primary, in: context)
        }
        return removed
    }

    /// Genau ein Profil, siehe `UserProfile.canonical(in:)`.
    private static func mergeProfiles(in context: ModelContext) -> Int {
        let vorher = (try? context.fetchCount(FetchDescriptor<UserProfile>())) ?? 0
        guard vorher > 1 else { return 0 }
        _ = UserProfile.canonical(in: context)
        let nachher = (try? context.fetchCount(FetchDescriptor<UserProfile>())) ?? vorher
        return max(vorher - nachher, 0)
    }

    /// Gemeinsame Faltung: gruppiert nach Schluessel, behaelt je Gruppe die
    /// Auswahl von `keep` und entfernt den Rest ueber `delete` (dort kann ein
    /// Modell seine Anhaengsel mit abraeumen).
    private static func mergeGrouped<M: PersistentModel, K: Hashable>(
        _ models: [M],
        key: (M) -> K,
        keep: ([M]) -> M?,
        delete: (M) -> Void
    ) -> Int {
        var removed = 0
        for (_, group) in Dictionary(grouping: models, by: key) {
            guard group.count > 1, let winner = keep(group) else { continue }
            for duplicate in group where duplicate !== winner {
                delete(duplicate)
                removed += 1
            }
        }
        return removed
    }

    /// Eine Rueckmeldung je Hebel und Tag, es gilt die zuletzt gegebene Antwort.
    private static func mergeLeverChecks(in context: ModelContext) -> Int {
        struct LeverDay: Hashable {
            let leverId: String
            let day: Date
        }

        let checks = (try? context.fetch(FetchDescriptor<FocusLeverCheck>())) ?? []
        return mergeGrouped(
            checks,
            key: { LeverDay(leverId: $0.lever?.leverId ?? "", day: $0.date.startOfDay) },
            keep: FocusLeverCheck.effective(among:),
            delete: { context.delete($0) }
        )
    }

    /// Ein Plan je Mahlzeit und Tag, es gilt der zuletzt angelegte. Abgelaufene
    /// Plaene (vor heute) verfallen ganz: ein nicht eingeloester Plan soll
    /// nirgends auftauchen (Issue #99), und ohne Verfall wuechse der Bestand
    /// mit jedem liegengebliebenen Plan unbegrenzt.
    private static func mergePlannedEntries(in context: ModelContext) -> Int {
        struct MealDay: Hashable {
            let mealTypeRaw: String
            let day: Date
        }

        let plans = (try? context.fetch(FetchDescriptor<PlannedEntry>())) ?? []
        var removed = 0

        // startOfDay defensiv: importierte Datensaetze laufen nicht durch den Init.
        let today = Date().startOfDay
        var current: [PlannedEntry] = []
        for plan in plans {
            if plan.date.startOfDay < today {
                plan.discard(in: context)
                removed += 1
            } else {
                current.append(plan)
            }
        }

        removed += mergeGrouped(
            current,
            key: { MealDay(mealTypeRaw: $0.mealTypeRaw, day: $0.date.startOfDay) },
            keep: PlannedEntry.effective(among:),
            delete: { $0.discard(in: context) }
        )
        return removed
    }

    /// Haelt die Invariante „genau ein aktiver Hebel" auch nach einem Import.
    ///
    /// Loest ueberzaehlige Hebel ab, statt sie zu loeschen: an ihnen haengen
    /// Rueckmeldungen, und die Historie ist die Datenbasis der Wochenroutine.
    /// Ohne das teilen zwei aktive Hebel die Rueckmeldungen unter sich auf und
    /// die Adhaerenz-Quote faellt zu niedrig aus.
    private static func retireSurplusLevers(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<FocusLever>(
            predicate: #Predicate<FocusLever> { $0.retiredAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let active = (try? context.fetch(descriptor)) ?? []
        guard active.count > 1 else { return 0 }

        let now = Date()
        for lever in active.dropFirst() {
            lever.retiredAt = now
        }
        return active.count - 1
    }
}
