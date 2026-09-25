import Foundation
import SwiftData

struct Store {
    let container: ModelContainer

    /// Alle Modelltypen des Stores — geteilt von Produktiv- und Testpfad. Das Schema
    /// wird einmal aufgebaut: es ist unveraenderlich, und der Aufbau laeuft ueber
    /// Reflection auf alle Properties von neun Modellen.
    static let schema = Schema([
        FoodItem.self, DiaryEntry.self, DayRecord.self,
        UserProfile.self, FoodCustomization.self, CustomUnit.self,
        FocusLever.self, FocusLeverCheck.self, PlannedEntry.self,
    ])

    /// Oeffnet den App-Group-SwiftData-Store ohne CloudKit.
    /// Schreibt werden beim naechsten App-Start automatisch via CloudKit synchronisiert.
    init() throws {
        try self.init(url: Self.storeURL())
    }

    /// Oeffnet den Store an einem bestimmten Ort (Kopie, Migrationspruefung).
    init(url storeURL: URL) throws {
        // Verzeichnis anlegen falls noch nicht vorhanden (App noch nie gestartet)
        let dir = storeURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            let ueberschrieben = ProcessInfo.processInfo.environment["KK_STORE_PATH"] != nil
            throw KKError("""
                KalorienKompass-Datenbank nicht gefunden: \(storeURL.path)
                \(ueberschrieben
                    ? "KK_STORE_PATH zeigt auf eine Datei, die es nicht gibt."
                    : "Stelle sicher, dass die KalorienKompass-App mindestens einmal gestartet wurde.")
                """)
        }

        let config = ModelConfiguration(url: storeURL)
        container = try ModelContainer(for: Self.schema, configurations: config)
    }

    /// Uebernimmt einen fertigen Container. Der Weg fuer Tests: dort entsteht er
    /// im Arbeitsspeicher, damit kein Test je den Produktivstore sehen kann.
    init(container: ModelContainer) {
        self.container = container
    }

    /// Pfad zum SwiftData-Store im App-Group-Container.
    ///
    /// `KK_STORE_PATH` ueberschreibt ihn. Das ist der einzige gangbare Weg, eine
    /// Schema-Migration gegen eine **Kopie** des Produktivstores zu pruefen:
    /// `HOME` zu setzen wirkt nicht, weil `homeDirectoryForCurrentUser` den Pfad
    /// aus der Passwortdatenbank liest und die Umgebungsvariable ignoriert. Genau
    /// daran ist beim Umbau in #66 ein Test unbemerkt auf dem echten Store gelandet.
    ///
    ///     KK_STORE_PATH=/pfad/zur/kopie/default.store kk today
    static func storeURL() -> URL {
        if let override = ProcessInfo.processInfo.environment["KK_STORE_PATH"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers")
            .appendingPathComponent("group.com.andre.claassen.KalorienKompass")
            .appendingPathComponent("Library/Application Support/default.store")
    }

    // MARK: - Schreiben

    /// Legt einen neuen Lebensmitteleintrag an (FoodItem + DiaryEntry).
    func addEntry(
        name: String,
        caloriesPer100g: Double,
        proteinPer100g: Double  = 0,
        carbsPer100g: Double    = 0,
        fatPer100g: Double      = 0,
        fiberPer100g: Double    = 0,
        sugarPer100g: Double    = 0,
        saturatedFatPer100g: Double = 0,
        saltPer100g: Double     = 0,
        amountGrams: Double     = 100,
        mealType: MealType      = .snack,
        date: Date              = Date(),
        createdAt: Date?        = nil
    ) throws -> DiaryEntry {
        let context = ModelContext(container)

        let foodItem = FoodItem(
            name: name,
            caloriesPer100g:     caloriesPer100g,
            proteinPer100g:      proteinPer100g,
            carbsPer100g:        carbsPer100g,
            fatPer100g:          fatPer100g,
            fiberPer100g:        fiberPer100g,
            sugarPer100g:        sugarPer100g,
            saturatedFatPer100g: saturatedFatPer100g,
            saltPer100g:         saltPer100g,
            defaultServingSizeGrams: amountGrams
        )
        foodItem.isQuickEntry   = true
        foodItem.isUserCreated  = true

        let entry = DiaryEntry(
            date:        date,
            mealType:    mealType,
            amountGrams: amountGrams,
            foodItem:    foodItem
        )

        // Nur Tests setzen createdAt: sie brauchen eine feste Reihenfolge der
        // Tagesliste, die sonst an der Systemuhr haengt.
        if let createdAt { entry.createdAt = createdAt }

        context.insert(foodItem)
        context.insert(entry)
        try context.save()

        return entry
    }

    // MARK: - Lesen

    /// Alle Eintraege eines bestimmten Kalendertages, sortiert nach Erstellungszeit.
    func entries(on date: Date) throws -> [DiaryEntry] {
        try ModelContext(container).fetch(Self.dayDescriptor(for: date))
    }

    /// FetchDescriptor fuer alle DiaryEntries eines Kalendertages (sortiert nach Erstellungszeit).
    private static func dayDescriptor(for date: Date) -> FetchDescriptor<DiaryEntry> {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay   = Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay)!
        var descriptor = FetchDescriptor<DiaryEntry>(
            predicate: #Predicate { entry in
                entry.date >= startOfDay && entry.date <= endOfDay
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.foodItem]
        return descriptor
    }

    /// Kalorienziel aus dem kanonischen UserProfile (0 wenn kein Profil vorhanden).
    func calorieGoal() throws -> Int {
        let context = ModelContext(container)
        return UserProfile.existing(in: context)?.dailyCalorieGoal ?? 0
    }

    /// Alle Eintraege in einem Datumsbereich.
    func entriesInRange(from startDate: Date, to endDate: Date) throws -> [DiaryEntry] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<DiaryEntry>(
            predicate: #Predicate { entry in
                entry.date >= startDate && entry.date <= endDate
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return try context.fetch(descriptor)
    }

    // MARK: - Naehrwert-Reparatur

    /// Lebensmittel, deren Ampel auf einer zu duennen Basis steht
    /// (`FoodItem.needsNutrientRepair`), nach Name sortiert.
    ///
    /// Der Filter laeuft im Speicher statt als Praedikat: die Regel steht in
    /// Shared und wird dort getestet, eine zweite Fassung als `#Predicate`
    /// koennte davon abweichen. Der Bestand ist dreistellig, das traegt sich.
    ///
    /// Mit `date` nur die Lebensmittel an Eintraegen dieses Tages. Geschrieben wird
    /// trotzdem ins Lebensmittel, nicht in den Eintrag: haengt es auch an anderen
    /// Tagen, bekommen die dieselben Mikrowerte. Kalorien und Makros bleiben dabei
    /// unberuehrt, die Tagessummen also auch.
    func itemsNeedingNutrientRepair(on date: Date? = nil) throws -> [FoodItem] {
        let items: [FoodItem]
        if let date {
            // Dasselbe Lebensmittel kann an mehreren Eintraegen des Tages haengen.
            var seen = Set<String>()
            items = try entries(on: date)
                .compactMap(\.foodItem)
                .filter { seen.insert($0.itemId).inserted }
        } else {
            items = try ModelContext(container).fetch(FetchDescriptor<FoodItem>())
        }
        return items.filter(\.needsNutrientRepair).sorted { $0.name < $1.name }
    }

    /// Traegt die drei Mikrowerte eines Lebensmittels nach.
    ///
    /// Ruehrt Kalorien und Makros bewusst nicht an — sie stecken in den
    /// Tagessummen vergangener Tage (Issue #98).
    func applyMicronutrients(_ values: Micronutrients, toItemWith itemId: String) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate<FoodItem> { $0.itemId == itemId }
        )
        guard let item = try context.fetch(descriptor).first else {
            throw KKError("Lebensmittel nicht mehr vorhanden: \(itemId)")
        }
        item.saturatedFatPer100g = values.saturatedFatPer100g
        item.sugarPer100g = values.sugarPer100g
        item.saltPer100g = values.saltPer100g
        try context.save()
    }

    // MARK: - Verbrauchsseite (HealthKit-Werte aus dem DayRecord)

    /// Die Tageswerte eines Kalendertages, oder `nil`, wenn es fuer den Tag keinen
    /// Datensatz gibt (kein Geraet hat etwas geliefert).
    func day(on date: Date) throws -> DayRecord.Day? {
        try days(from: date, to: date).first
    }

    /// Ein Wert je Kalendertag im Zeitraum, aufsteigend sortiert.
    ///
    /// Bewusst ueber `DayRecord.days(in:from:to:)` statt ueber einen eigenen
    /// Bereichs-Fetch: die Methode faltet CloudKit-Duplikate zu einem Tag
    /// zusammen. Wer die Records selbst zaehlt, zaehlt Zeilen statt Tage und
    /// bekommt Wochenschnitte, die pro Geraet einen Datenpunkt mehr haben
    /// (Issue #67).
    func days(from startDate: Date, to endDate: Date) throws -> [DayRecord.Day] {
        DayRecord.days(in: ModelContext(container), from: startDate, to: endDate)
    }

    // MARK: - Kaffee

    /// Kaffee-Stand eines Tages: Tassen, Tagesziel, Koffein pro Tasse, Wochenendtag.
    struct CoffeeStatus {
        let cups: Int
        let goal: Int
        let mgPerCup: Int
        let isWeekend: Bool

        /// Geschaetzte Koffeinaufnahme des Tages.
        var caffeineMg: Int { cups * mgPerCup }
    }

    /// Liefert den Kaffee-Stand am `date`.
    /// Liest den kanonischen DayRecord, ohne anzulegen oder zu bereinigen.
    func coffeeStatus(on date: Date) throws -> CoffeeStatus {
        let context = ModelContext(container)
        let profile = UserProfile.existing(in: context)
        let isWeekend = profile.map { p in
            (p.weekendCoffeeDaysRaw & (1 << Calendar.current.component(.weekday, from: date))) != 0
        } ?? false
        let goal = isWeekend
            ? (profile?.weekendCoffeeGoal ?? 6)
            : (profile?.dailyCoffeeGoal ?? 3)
        let mgPerCup = profile?.caffeineMgPerCup ?? UserProfile.defaultCaffeineMgPerCup

        // Lesepfad: kanonischer Record, ohne anzulegen oder zu bereinigen (Issue #65)
        let cups = DayRecord.existing(in: context, for: date)?.coffeeCups ?? 0
        return CoffeeStatus(cups: cups, goal: goal, mgPerCup: mgPerCup, isWeekend: isWeekend)
    }

    /// Passt die Kaffee-Tassen am `date` um `delta` an (negativ = entfernen).
    /// Erzeugt einen DayRecord, falls keiner existiert. Nicht unter 0.
    @discardableResult
    func adjustCoffee(by delta: Int, on date: Date) throws -> Int {
        let context = ModelContext(container)
        let mgPerCup = UserProfile.existing(in: context)?.caffeineMgPerCup ?? UserProfile.defaultCaffeineMgPerCup

        // Schreibpfad: legt bei Bedarf an und fuehrt CloudKit-Duplikate zusammen
        let record = DayRecord.canonical(in: context, for: date)
        record.bookCoffee(cups: delta, caffeineMgPerCup: mgPerCup)
        try context.save()
        return record.coffeeCups
    }

    // MARK: - Hebel

    /// Aktiver Hebel (oder nil, wenn keiner gesetzt ist).
    func activeLever() throws -> FocusLever? {
        FocusLever.active(in: ModelContext(container))
    }

    /// Setzt einen neuen Hebel; der bisherige wandert in die Historie.
    @discardableResult
    func setLever(text: String, triggerStartHour: Int, triggerOnSnack: Bool) throws -> FocusLever {
        FocusLever.setActive(
            text: text,
            triggerStartHour: triggerStartHour,
            triggerOnSnack: triggerOnSnack,
            in: ModelContext(container)
        )
    }

    /// Setzt die Tagesrueckmeldung. Wirft, wenn kein Hebel aktiv ist.
    func recordLeverCheck(kept: Bool, on date: Date) throws -> FocusLever {
        let context = ModelContext(container)
        guard let lever = FocusLever.active(in: context) else {
            throw KKError("Kein aktiver Hebel. Setze zuerst einen mit: kk focus set \"…\"")
        }
        lever.recordCheck(kept: kept, for: date, in: context)
        return lever
    }

    // MARK: - Loeschen

    /// Loescht den zuletzt erstellten DiaryEntry (und das zugehoerige QuickEntry-FoodItem).
    ///
    /// Bewusst ueber `createdAt` ohne Datumsfilter: damit trifft `kk undo` auch eine
    /// rueckwirkende Buchung. Das setzt voraus, dass `createdAt` immer die echte
    /// Eingabezeit bleibt und nie zurueckdatiert wird (siehe `Commands.resolveMeal`).
    func deleteLastEntry() throws -> (name: String, calories: Double)? {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<DiaryEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        descriptor.relationshipKeyPathsForPrefetching = [\.foodItem]

        guard let entry = try context.fetch(descriptor).first else { return nil }
        let info = stageDelete(entry, in: context)
        try context.save()
        return info
    }

    /// Loescht den Eintrag mit 1-basiertem `index` am Tag `date`.
    /// Der Index bezieht sich auf die Reihenfolge aus `entries(on:)` (= die `delete`-Liste).
    func deleteEntry(on date: Date, index: Int) throws -> (name: String, calories: Double)? {
        let context = ModelContext(container)
        let entries = try context.fetch(Self.dayDescriptor(for: date))
        guard index >= 1, index <= entries.count else { return nil }
        let info = stageDelete(entries[index - 1], in: context)
        try context.save()
        return info
    }

    /// Markiert einen Eintrag samt verknuepftem QuickEntry-FoodItem zum Loeschen
    /// (ohne zu speichern) und liefert Name + Kalorien zurueck.
    private func stageDelete(_ entry: DiaryEntry, in context: ModelContext) -> (name: String, calories: Double) {
        let name     = entry.foodItem?.name ?? "Unbekannt"
        let calories = entry.calories
        if let food = entry.foodItem, food.isQuickEntry {
            context.delete(food)
        }
        context.delete(entry)
        return (name: name, calories: calories)
    }

    // MARK: - Umhaengen

    /// Auswahl der umzuhaengenden Eintraege eines Quelltages.
    enum MoveSelector: Equatable {
        /// 1-basierte Nummern aus der Liste von `entries(on:)`.
        /// Reihenfolge und Duplikate spielen keine Rolle.
        case numbers([Int])
        /// Alle Eintraege dieser Mahlzeit am Quelltag.
        case meal(MealType)
    }

    /// Was ein Umhaengen bewirkt hat — eine Zeile Ausgabe je Eintrag.
    struct MovedEntry {
        let name: String
        let calories: Double
        let fromMeal: MealType
        let toMeal: MealType
        let fromDate: Date
        let toDate: Date

        var changedMeal: Bool { fromMeal != toMeal }
        /// Ueber den Kalendertag, nicht ueber exakte Gleichheit: ein per CloudKit
        /// importierter Eintrag traegt nicht zwingend den Tagesbeginn (siehe
        /// `mergePlannedEntries`) und wuerde sonst als verschoben gemeldet.
        var changedDate: Bool { !fromDate.isSameDay(as: toDate) }
        var changedAnything: Bool { changedMeal || changedDate }
    }

    enum MoveError: Error, Equatable {
        /// Der Quelltag hat ueberhaupt keine Eintraege.
        case emptyDay
        /// Diese Nummern gibt es am Quelltag nicht (aufsteigend, ohne Duplikate).
        case unknownNumbers([Int], available: Int)
        /// Am Quelltag liegt kein Eintrag dieser Mahlzeit.
        case noEntriesInMeal(MealType)
    }

    /// Ordnet Eintraege des Tages `date` einer anderen Mahlzeit und/oder einem
    /// anderen Tag zu. Alles oder nichts: erst wird die komplette Auswahl gegen den
    /// Bestand geprueft, erst danach wird ueberhaupt etwas geaendert.
    ///
    /// `createdAt` bleibt unangetastet — es ist die echte Eingabezeit, steuert die
    /// Sortierung der Tagesliste und `kk undo` (siehe `deleteLastEntry`). Ein auf
    /// einen anderen Tag umgehaengter Eintrag sortiert sich dort deshalb nach seiner
    /// Erfassungszeit ein, genau wie eine Buchung mit `kk add --yesterday`.
    ///
    /// Das verknuepfte FoodItem wird nicht angefasst: Naehrwerte und Menge aendern
    /// sich beim Umhaengen nicht. Genau das ist der Unterschied zu loeschen und neu
    /// erfassen, wo die KI die Werte neu schaetzt.
    ///
    /// - Parameters:
    ///   - meal: neue Mahlzeit, `nil` laesst sie unveraendert
    ///   - targetDate: neuer Tag (wird auf den Tagesbeginn normalisiert), `nil` laesst ihn unveraendert
    /// - Returns: die umgehaengten Eintraege in der Reihenfolge der Tagesliste
    @discardableResult
    func moveEntries(
        on date: Date,
        selecting selector: MoveSelector,
        toMeal meal: MealType? = nil,
        toDate targetDate: Date? = nil
    ) throws -> [MovedEntry] {
        let context = ModelContext(container)
        let all = try context.fetch(Self.dayDescriptor(for: date))
        guard !all.isEmpty else { throw MoveError.emptyDay }

        // Auswahl vollstaendig aufloesen und pruefen, bevor irgendetwas mutiert wird.
        // Dass ein ModelContext ohne save() nichts persistiert, reicht als Begruendung
        // nicht: die Garantie soll im Code stehen und nicht aus einem Default folgen.
        let selected: [DiaryEntry]
        switch selector {
        case .numbers(let raw):
            let wanted  = Set(raw).sorted()
            let unknown = wanted.filter { $0 < 1 || $0 > all.count }
            guard unknown.isEmpty else {
                throw MoveError.unknownNumbers(unknown, available: all.count)
            }
            selected = wanted.map { all[$0 - 1] }
        case .meal(let sourceMeal):
            selected = all.filter { $0.mealType == sourceMeal }
            guard !selected.isEmpty else { throw MoveError.noEntriesInMeal(sourceMeal) }
        }

        // Der Tagesbeginn muss hier selbst gesetzt werden: die Normalisierung steckt
        // im DiaryEntry-Initializer, eine direkte Zuweisung umgeht sie.
        let target = targetDate?.startOfDay

        var moved: [MovedEntry] = []
        for entry in selected {
            moved.append(MovedEntry(
                name:     entry.foodItem?.name ?? "Unbekannt",
                calories: entry.calories,
                fromMeal: entry.mealType,
                toMeal:   meal ?? entry.mealType,
                fromDate: entry.date,
                toDate:   target ?? entry.date
            ))
            if let meal   { entry.mealType = meal }
            if let target { entry.date = target }
        }

        try context.save()
        return moved
    }
}
