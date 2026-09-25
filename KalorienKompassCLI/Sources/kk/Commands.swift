import Foundation

enum Commands {

    // MARK: - kk add

    static func add(args: [String]) async throws {
        let parsed = try parseAddArgs(args)

        let meal     = try resolveMeal(parsed)
        let date     = parsed.date
        let dateStr  = formattedDate(date)

        if let name = parsed.name, let calories = parsed.calories {
            // Manueller Modus: direkte Nährwert-Eingabe
            let store = try Store()
            let entry = try store.addEntry(
                name:            name,
                caloriesPer100g: calories,
                proteinPer100g:  parsed.protein,
                carbsPer100g:    parsed.carbs,
                fatPer100g:      parsed.fat,
                sugarPer100g:    parsed.sugar,
                saturatedFatPer100g: parsed.saturatedFat,
                saltPer100g:     parsed.salt,
                amountGrams:     parsed.grams,
                mealType:        meal,
                date:            date
            )
            printEntryLine(name: name, entry: entry, meal: meal, dateStr: dateStr, confidence: nil)
            print(green("✓") + " Gespeichert in KalorienKompass")
            if entry.foodItem?.needsNutrientRepair == true {
                print(dim("Ampel unsicher, gesättigte Fettsäuren, Zucker und Salz fehlen. "
                    + "Nachtragen mit: kk repair nutrients --date \(isoDay(date)) --apply"))
            }

        } else if let description = parsed.description {
            // KI-Modus: Freitext → Claude API
            guard let apiKey = Config.resolveAPIKey() else {
                throw ClaudeServiceError.noAPIKey
            }

            print(dim("Analysiere \"\(description)\"..."))

            // Mehrere Speisen ergeben mehrere Eintraege (Issue #73)
            let estimates = try await estimateMeal(description: description, apiKey: apiKey)
            guard !estimates.isEmpty else { throw KKError("Keine Speise erkannt.") }

            let store = try Store()
            for estimate in estimates {
                // Eine ausdrueckliche Grammangabe gilt nur bei genau einer Speise —
                // sonst waere unklar, worauf sie sich bezieht.
                let grams = (parsed.grams == 100 || estimates.count > 1)
                    ? estimate.estimatedWeightGrams
                    : parsed.grams

                let entry = try store.addEntry(
                    name:                estimate.name,
                    caloriesPer100g:     estimate.caloriesPer100g,
                    proteinPer100g:      estimate.proteinPer100g,
                    carbsPer100g:        estimate.carbsPer100g,
                    fatPer100g:          estimate.fatPer100g,
                    fiberPer100g:        estimate.fiberPer100g,
                    sugarPer100g:        estimate.sugarPer100g,
                    saturatedFatPer100g: estimate.saturatedFatPer100g,
                    saltPer100g:         estimate.saltPer100g,
                    amountGrams:         grams,
                    mealType:            meal,
                    date:                date
                )
                printEntryLine(
                    name:       estimate.name,
                    entry:      entry,
                    meal:       meal,
                    dateStr:    dateStr,
                    confidence: estimate.confidence
                )
            }
            print(green("✓") + " Gespeichert in KalorienKompass")

        } else {
            throw KKError("""
                Bitte eine Beschreibung oder manuelle Nährwerte angeben.
                Beispiele:
                  kk add "2 Scheiben Toast mit Butter"
                  kk add --name "Apfel" --calories 52 --grams 150
                """)
        }
    }

    /// Mahlzeit bestimmen: `--meal` vor `--time` vor aktueller Uhrzeit.
    ///
    /// Die aktuelle Uhrzeit greift nur für heute. Bei einem vergangenen Tag sagt sie
    /// nichts über die Mahlzeit aus (das Abendessen von gestern morgens nachgetragen
    /// wäre sonst still ein Frühstück), deshalb wird dort eine Angabe verlangt.
    ///
    /// `--time` fließt bewusst nicht in `DiaryEntry.createdAt`: das steuert die
    /// Sortierung innerhalb des Tages und `kk undo` (jüngster `createdAt`), ein
    /// zurückdatierter Wert würde `undo` auf einen fremden Eintrag zeigen lassen.
    private static func resolveMeal(_ parsed: AddArgs) throws -> MealType {
        if let meal = parsed.meal { return meal }
        if let hour = parsed.timeHour { return MealType.forHour(hour) }

        guard parsed.date.isToday else {
            throw KKError("""
                Für einen vergangenen Tag muss die Mahlzeit angegeben werden.
                Beispiele:
                  kk add --yesterday --time 19:30 "Pizza"
                  kk add --yesterday --meal dinner "Pizza"
                Mahlzeiten: \(MealType.cliNameHint)
                """)
        }
        return MealType.currentBasedOnTime
    }

    // MARK: - kk today

    static func today(args: [String]) async throws {
        let (date, rest) = try extractDateOptions(args)
        if let unexpected = rest.first(where: { $0 != "--json" }) {
            throw KKError("Unerwartetes Argument: \(unexpected). Nutze 'kk help' für Hilfe.")
        }
        let asJSON = rest.contains("--json")

        let store   = try Store()
        let entries = try store.entries(on: date)
        let goal    = try store.calorieGoal()
        let day     = try store.day(on: date)
        let coffee  = try? store.coffeeStatus(on: date)

        // Ganzzahlig abgeschnitten, und beide Ausgaben rechnen ueber denselben
        // Wert: derselbe Befehl darf nicht zwei Zahlen fuer denselben Tag nennen.
        let totalCalories = Int(entries.reduce(0) { $0 + $1.calories })
        let summary = TrafficLightSummary(entries: entries)

        if asJSON {
            print(todayJSON(
                date: date,
                entries: entries,
                goal: goal,
                totalCalories: totalCalories,
                day: day,
                coffee: coffee,
                summary: summary
            ))
            return
        }

        let dateStr = formattedDate(date)
        let isToday = date.isToday
        let header = isToday ? "Heute, \(dateStr)" : dateStr
        print(bold(header) + (goal > 0 ? " — Ziel: \(Int(goal)) kcal" : ""))
        print(String(repeating: "─", count: 50))

        if entries.isEmpty {
            print(dim(isToday ? "Noch keine Einträge heute." : "Keine Einträge am \(dateStr)."))
        } else {
            // Einträge nach Mahlzeitstyp gruppieren
            let grouped = Dictionary(grouping: entries) { $0.mealType }
            let sortedMeals = MealType.allCases.filter { grouped[$0] != nil }

            for meal in sortedMeals {
                let mealEntries = grouped[meal] ?? []
                let mealCals    = mealEntries.reduce(0) { $0 + $1.calories }
                print(bold(meal.displayName) + dim("  \(Int(mealCals)) kcal"))
                for entry in mealEntries {
                    print("  " + entryLine(entry))
                }
            }
        }

        print(String(repeating: "─", count: 50))

        let totalStr = bold("Gesamt: \(totalCalories) kcal")
        if goal > 0 {
            let remaining = goal - totalCalories
            let remainStr = remaining >= 0
                ? green("\(remaining) kcal verbleibend")
                : yellow("\(abs(remaining)) kcal überschritten")
            print(totalStr + "  |  " + remainStr)
        } else {
            print(totalStr)
        }

        // Verbrauchsseite — nur an Tagen, an denen die Uhr etwas geliefert hat
        if let line = energyLine(day) { print(line) }

        // Ampel-Zusammenfassung des Tages
        if let line = summary.line { print(line) }

        // Kaffee-Zeile
        if let coffee, coffee.goal > 0 {
            let bar = coffeeBar(cups: coffee.cups, goal: coffee.goal)
            let we = coffee.isWeekend ? dim(" ★") : ""
            print("☕ " + bar + dim("  \(coffee.cups) / \(coffee.goal) Tassen") + we)
        }
    }

    /// Eine Eintragszeile: Name, Kalorien, Menge, Ampelpunkt.
    ///
    /// Die Ampel steht am Zeilenende und nicht vorn, damit die Spaltenbreite
    /// nicht leidet; fehlt sie, bleibt die Stelle leer statt geraten (Issue #92).
    private static func entryLine(_ entry: DiaryEntry) -> String {
        let name  = (entry.foodItem?.name ?? "Unbekannt").padding(toLength: 36, withPad: " ", startingAt: 0)
        let cals  = String(Int(entry.calories)).leftPad(5)
        let grams = "\(Int(entry.amountGrams))g".leftPad(6)
        let dot   = entry.foodItem?.trafficLight.map { "  " + $0.rating.dot } ?? ""
        return "\(name)\(cals) kcal \(dim(grams))\(dot)"
    }

    /// `🔥 417 kcal aktiv, davon 0 kcal Training  |  1280 Schritte`
    ///
    /// `nil`, wenn weder Kalorien noch Schritte vorliegen: ein Tag ohne Uhr soll
    /// nicht mit Nullen zugestellt werden (Issue #91).
    private static func energyLine(_ day: DayRecord.Day?) -> String? {
        guard let day, day.activeEnergyKcal > 0 || day.steps > 0 else { return nil }
        var line = "🔥 " + bold("\(day.activeEnergyKcal) kcal") + " aktiv"
        line += dim(", davon \(day.workoutCaloriesKcal) kcal Training")
        if day.steps > 0 { line += dim("  |  \(day.steps) Schritte") }
        return line
    }

    // MARK: - kk energy

    /// Verbrauchsseite: Aktivkalorien, Trainingsanteil, Schritte, Gewicht.
    ///
    /// Liest nur, was HealthKit auf dem iPhone laengst in den `DayRecord`
    /// geschrieben hat — auf dem Mac gibt es kein HealthKit, und einen eigenen
    /// Sync braucht es dafuer auch nicht.
    static func energy(args: [String]) async throws {
        let (date, rest) = try extractDateOptions(args)
        var sub = "status"
        var weeks = 4
        var asJSON = false

        var i = 0
        while i < rest.count {
            switch rest[i] {
            case "--json":
                asJSON = true
            case "--weeks":
                i += 1
                guard i < rest.count, let v = Int(rest[i]), v > 0 else {
                    throw KKError("--weeks braucht eine Zahl größer als 0")
                }
                weeks = v
            default:
                guard !rest[i].hasPrefix("-") else {
                    throw KKError("Unbekannte Option: \(rest[i]). Nutze 'kk help' für Hilfe.")
                }
                sub = rest[i]
            }
            i += 1
        }

        let store = try Store()

        switch sub {
        case "status":
            try energyStatus(store, date: date, asJSON: asJSON)

        case "report":
            try energyReport(store, weeks: weeks, asJSON: asJSON)

        default:
            throw KKError("""
                Unbekanntes energy-Kommando: \(sub)
                Verfuegbar: status, report [--weeks N]
                """)
        }
    }

    private static func energyStatus(_ store: Store, date: Date, asJSON: Bool) throws {
        let day = try store.day(on: date)

        if asJSON {
            print(jsonString(["date": isoDay(date), "energy": energyJSON(day)]))
            return
        }

        print(bold("🔥 Energie — \(formattedDate(date))"))
        print(String(repeating: "─", count: 50))

        guard let day, day.activeEnergyKcal > 0 || day.steps > 0 || day.weight != nil else {
            print(dim("Keine Aktivitätsdaten für diesen Tag."))
            return
        }

        print("  Aktiv           " + bold("\(day.activeEnergyKcal) kcal".leftPad(9)))
        print("  davon Training  " + "\(day.workoutCaloriesKcal) kcal".leftPad(9))
        print("  ohne Training   " + "\(day.nonWorkoutActiveEnergy) kcal".leftPad(9))
        print("  Schritte        " + "\(day.steps)".leftPad(9))
        if let weight = day.weight {
            let kg = String(format: "%.1f kg", locale: Locale(identifier: "de_DE"), weight)
            print("  Gewicht         " + kg.leftPad(9))
        }
    }

    private static func energyReport(_ store: Store, weeks: Int, asJSON: Bool) throws {
        let calendar = Calendar.current
        let today = Date().startOfDay

        // Wochenfenster rueckwaerts, juengste Woche zuerst — dasselbe Raster wie
        // bei `kk focus report`, damit sich beide Auswertungen nebeneinander lesen.
        // Die Tage kommen aus **einem** Fetch ueber den ganzen Zeitraum und werden
        // hier verteilt: die Fenster grenzen lueckenlos aneinander, ein Fetch je
        // Woche waere derselbe Zeitraum in Scheiben.
        guard let firstDay = calendar.date(byAdding: .day, value: -(weeks * 7 - 1), to: today) else { return }
        let byWeek = Dictionary(grouping: try store.days(from: firstDay, to: today)) { day in
            (calendar.dateComponents([.day], from: day.date.startOfDay, to: today).day ?? 0) / 7
        }

        let windows: [EnergyWeek] = (0..<weeks).compactMap { index in
            guard let end = calendar.date(byAdding: .day, value: -(index * 7), to: today),
                  let start = calendar.date(byAdding: .day, value: -6, to: end) else { return nil }
            return EnergyWeek(start: start, end: end, days: byWeek[index] ?? [])
        }

        if asJSON {
            print(jsonString(["weeks": windows.map(\.json)]))
            return
        }

        print(bold("🔥 Energie") + dim("  (letzte \(weeks) Wochen)"))
        print(String(repeating: "─", count: 50))
        for window in windows {
            let label = isoDay(window.start) + " bis " + isoDay(window.end)
            guard !window.days.isEmpty else {
                print("  \(label): " + dim("keine Daten"))
                continue
            }
            print("  \(label): " + bold("⌀ \(window.averageActive) kcal")
                + dim(" aktiv, ⌀ \(window.averageSteps) Schritte, \(window.days.count) Tage"))
        }
    }

    /// Ein Wochenfenster der Verbrauchsauswertung.
    ///
    /// Gemittelt wird ueber die Tage **mit** Datensatz, nicht ueber sieben: ein
    /// Tag ohne Uhr ist kein Tag mit null Kalorien, und als solcher gezaehlt
    /// zoege er den Schnitt grundlos nach unten. Wie viele Tage es waren, steht
    /// deshalb in der Ausgabe.
    private struct EnergyWeek {
        let start: Date
        let end: Date
        let days: [DayRecord.Day]

        var averageActive: Int { average(\.activeEnergyKcal) }
        var averageWorkout: Int { average(\.workoutCaloriesKcal) }
        var averageSteps: Int { average(\.steps) }

        private func average(_ keyPath: KeyPath<DayRecord.Day, Int>) -> Int {
            guard !days.isEmpty else { return 0 }
            return days.reduce(0) { $0 + $1[keyPath: keyPath] } / days.count
        }

        var json: [String: Any] {
            [
                "start": isoDay(start),
                "end": isoDay(end),
                "days": days.count,
                "averageActiveEnergyKcal": averageActive,
                "averageWorkoutCaloriesKcal": averageWorkout,
                "averageSteps": averageSteps
            ]
        }
    }

    // MARK: - kk coffee

    static func coffee(args: [String]) async throws {
        let (date, rest) = try extractDateOptions(args)
        let sub = rest.first ?? "status"
        let store = try Store()

        func report() throws {
            printCoffee(try store.coffeeStatus(on: date), date: date)
        }

        switch sub {
        case "status", "":
            try report()

        case "add", "+":
            let count = parseCountArg(rest.dropFirst()) ?? 1
            try store.adjustCoffee(by: count, on: date)
            print(green("✓") + " \(count) Tasse\(count == 1 ? "" : "n") Kaffee hinzugefuegt")
            try report()

        case "remove", "rm", "-":
            let count = parseCountArg(rest.dropFirst()) ?? 1
            try store.adjustCoffee(by: -count, on: date)
            print(green("✓") + " \(count) Tasse\(count == 1 ? "" : "n") Kaffee entfernt")
            try report()

        default:
            throw KKError("""
                Unbekanntes coffee-Kommando: \(sub)
                Verfuegbar: status, add [N], remove [N]
                """)
        }
    }

    private static func parseCountArg(_ args: ArraySlice<String>) -> Int? {
        guard let first = args.first, let n = Int(first), n > 0 else { return nil }
        return n
    }

    private static func printCoffee(_ status: Store.CoffeeStatus, date: Date) {
        let (cups, goal, mgPerCup) = (status.cups, status.goal, status.mgPerCup)
        let dateStr = formattedDate(date)
        let suffix = status.isWeekend ? dim(" (Wochenende)") : ""
        print(bold("☕ Kaffee — \(dateStr)") + suffix)
        print(String(repeating: "─", count: 50))

        let progressBar = coffeeBar(cups: cups, goal: goal)
        print("  \(progressBar)  \(bold("\(cups) / \(goal)")) Tassen")

        // Das Tagesziel ist eine Obergrenze, keine Sollmenge (Issue #77): darunter
        // zu bleiben ist der gute Fall, nicht der unerledigte.
        let remaining = goal - cups
        if remaining > 0 {
            print("  " + green("noch \(remaining) Tasse\(remaining == 1 ? "" : "n") moeglich"))
        } else if remaining == 0 {
            print("  " + green("Limit ausgeschoepft ✓"))
        } else {
            print("  " + yellow("\(abs(remaining)) Tasse\(abs(remaining) == 1 ? "" : "n") ueber dem Limit"))
        }

        print("  " + dim("~\(status.caffeineMg) mg Koffein (\(mgPerCup) mg pro Tasse)"))
    }

    private static func coffeeBar(cups: Int, goal: Int) -> String {
        guard goal > 0 else { return "" }
        let filled = min(cups, goal)
        let empty  = max(goal - cups, 0)
        let over   = max(cups - goal, 0)
        return String(repeating: "●", count: filled)
             + String(repeating: "○", count: empty)
             + (over > 0 ? dim(" +" + String(repeating: "●", count: over)) : "")
    }

    // MARK: - kk repair

    /// Traegt fehlende Mikrowerte in Altbestaenden nach (Issue #98).
    ///
    /// Trockenlauf ist der Standard: ohne `--apply` wird nur aufgelistet. Es geht
    /// um den Produktivstore, und die Aenderung ist ueber CloudKit sofort auf
    /// allen Geraeten.
    static func repair(args: [String]) async throws {
        let parsed = try parseRepairArgs(args)
        let dayLabel = parsed.date.map { " am \(formattedDate($0))" } ?? ""

        let store = try Store()
        let candidates = Array(try store.itemsNeedingNutrientRepair(on: parsed.date).prefix(parsed.limit))

        guard !candidates.isEmpty else {
            print(dim("Keine Lebensmittel mit fehlenden Nährwerten\(dayLabel)."))
            return
        }

        print(bold("🔧 Nährwerte nachtragen") + dim("  (\(candidates.count) Lebensmittel\(dayLabel))"))
        print(String(repeating: "─", count: 50))

        guard parsed.apply else {
            for item in candidates {
                print("  \(item.name.padding(toLength: 38, withPad: " ", startingAt: 0))"
                    + String(Int(item.caloriesPer100g)).leftPad(5) + " kcal/100g"
                    + dim("  \(currentLight(item))"))
            }
            print(String(repeating: "─", count: 50))
            // Nicht dateFlag(for:): das laesst heute weg.
            let repairDateFlag = parsed.date.map { " --date \(isoDay($0))" } ?? ""
            print(dim("Trockenlauf. Nachtragen mit: kk repair nutrients\(repairDateFlag) --apply"))
            print(dim("Kalorien und Makros bleiben unangetastet, nur die drei fehlenden Werte kommen dazu."))
            return
        }

        guard let apiKey = Config.resolveAPIKey() else { throw ClaudeServiceError.noAPIKey }

        var repaired = 0
        for item in candidates {
            do {
                let values = try await estimateMicronutrients(
                    name: item.name,
                    caloriesPer100g: item.caloriesPer100g,
                    proteinPer100g: item.proteinPer100g,
                    carbsPer100g: item.carbsPer100g,
                    fatPer100g: item.fatPer100g,
                    apiKey: apiKey
                )
                // Beide Ampeln vor dem Schreiben bilden: der Schreibpfad nutzt
                // einen eigenen ModelContext, das hier gehaltene Objekt bliebe
                // danach auf dem alten Stand und zeigte zweimal dasselbe.
                let vorher = currentLight(item)
                let nachher = lightAfterRepair(item, values)
                try store.applyMicronutrients(values, toItemWith: item.itemId)
                repaired += 1
                print("  " + green("✓") + " \(item.name.padding(toLength: 36, withPad: " ", startingAt: 0))"
                    + dim(String(format: "ges.F %.1f  Zucker %.1f  Salz %.2f",
                                 values.saturatedFatPer100g, values.sugarPer100g, values.saltPer100g))
                    + "  \(vorher) → \(nachher)")
            } catch {
                // Ein Ausfall darf den Rest nicht aufhalten: die uebrigen
                // Lebensmittel sind unabhaengig voneinander.
                print("  " + yellow("✗") + " \(item.name): \(error.localizedDescription)")
            }
        }

        print(String(repeating: "─", count: 50))
        print(bold("\(repaired) von \(candidates.count) nachgetragen"))
        print(dim("Die App übernimmt die Werte beim nächsten CloudKit-Abgleich."))
    }

    /// Ergebnis des Argument-Parsens von `kk repair nutrients`.
    struct RepairArgs {
        var apply = false
        var limit = Int.max
        /// Nur Lebensmittel an Eintraegen dieses Tages; `nil` heisst der ganze Bestand.
        var date: Date?
    }

    static func parseRepairArgs(_ args: [String]) throws -> RepairArgs {
        guard args.first == "nutrients" else {
            throw KKError("""
                Unbekanntes repair-Kommando: \(args.first ?? "(keins)")
                Verfuegbar: nutrients [--apply] [--limit N] [--date DATUM | --yesterday]
                """)
        }

        var result = RepairArgs()
        let options = Array(args.dropFirst())
        let (day, rest) = try extractDateOptions(options)
        if rest.count < options.count { result.date = day }

        var i = 0
        while i < rest.count {
            switch rest[i] {
            case "--apply":
                result.apply = true
            case "--limit":
                i += 1
                guard i < rest.count, let v = Int(rest[i]), v > 0 else {
                    throw KKError("--limit braucht eine Zahl größer als 0")
                }
                result.limit = v
            default:
                throw KKError("Unbekannte Option: \(rest[i]). Nutze 'kk help' für Hilfe.")
            }
            i += 1
        }
        return result
    }

    /// Ampelpunkt des aktuellen Standes, oder ein Platzhalter ohne Naehrwerte.
    private static func currentLight(_ item: FoodItem) -> String {
        item.trafficLight.map(\.rating.dot) ?? dim("○")
    }

    /// Ampelpunkt, den das Lebensmittel mit den nachgetragenen Werten bekommt.
    private static func lightAfterRepair(_ item: FoodItem, _ values: Micronutrients) -> String {
        NutrientTrafficLight.trafficLight(
            fat: item.fatPer100g,
            saturatedFat: values.saturatedFatPer100g,
            sugar: values.sugarPer100g,
            salt: values.saltPer100g,
            calories: item.caloriesPer100g
        ).map(\.rating.dot) ?? dim("○")
    }

    // MARK: - kk undo

    static func undo() async throws {
        let store = try Store()
        guard let deleted = try store.deleteLastEntry() else {
            print(dim("Keine Einträge zum Löschen vorhanden."))
            return
        }
        print(green("✓") + " Gelöscht: \(deleted.name) (\(Int(deleted.calories)) kcal)")
    }

    // MARK: - kk delete

    static func delete(args: [String]) async throws {
        let (date, rest) = try extractDateOptions(args)
        let index = try rest.first.map { arg -> Int in
            guard let n = Int(arg) else {
                throw KKError("Erwartet eine Eintrags-Nummer. Nutze 'kk delete' für die nummerierte Liste.")
            }
            return n
        }

        let store    = try Store()
        let dateStr  = formattedDate(date)
        let dateFlag = dateFlag(for: date)

        // Ohne Nummer: nummerierte Liste anzeigen
        guard let index else {
            try printNumberedDayList(on: date, in: store,
                                     hint: "Löschen mit: kk delete <Nr>\(dateFlag)")
            return
        }

        // Mit Nummer: löschen
        guard let deleted = try store.deleteEntry(on: date, index: index) else {
            throw KKError("Kein Eintrag mit Nummer \(index) am \(dateStr). Nutze 'kk delete\(dateFlag)' für die Liste.")
        }
        print(green("✓") + " Gelöscht: \(deleted.name) (\(Int(deleted.calories)) kcal)" + dim("  —  \(dateStr)"))
    }

    /// Die nummerierte Tagesliste, geteilt von `delete` und `move`. Die Nummern
    /// stammen aus `Store.entries(on:)` (Reihenfolge der Erfassung) und gelten nur
    /// fuer diesen Aufruf; `kk today` gruppiert dagegen nach Mahlzeit.
    private static func printNumberedDayList(on date: Date, in store: Store, hint: String) throws {
        let dateStr = formattedDate(date)
        let entries = try store.entries(on: date)
        guard !entries.isEmpty else {
            print(dim("Keine Einträge am \(dateStr)."))
            return
        }
        print(bold("Einträge am \(dateStr)"))
        print(String(repeating: "─", count: 50))
        for (n, entry) in entries.enumerated() {
            let name = (entry.foodItem?.name ?? "Unbekannt").padding(toLength: 32, withPad: " ", startingAt: 0)
            let cals = String(Int(entry.calories)).leftPad(5)
            print("  \(String(n + 1).leftPad(2))  \(name)\(cals) kcal  \(dim(entry.mealType.displayName))")
        }
        print(String(repeating: "─", count: 50))
        print(dim(hint))
    }

    private static func isoDay(_ date: Date) -> String {
        isoDayFormatter.string(from: date)
    }

    /// Der `--date`-Zusatz fuer Hinweistexte: leer fuer heute, sonst die Option,
    /// mit der man denselben Tag wieder erreicht.
    private static func dateFlag(for date: Date) -> String {
        date.isToday ? "" : " --date \(isoDay(date))"
    }

    // MARK: - kk move

    /// Ergebnis des Argument-Parsens von `kk move`. Eigener Typ, damit die Regeln
    /// ohne Store und ohne Ausgabe pruefbar sind.
    struct MoveArgs {
        var sourceDate: Date = Date()
        /// `nil` heisst: kein Selektor angegeben, also nur auflisten.
        var selector: Store.MoveSelector?
        var targetMeal: MealType?
        var targetDate: Date?

        var hasTarget: Bool { targetMeal != nil || targetDate != nil }
    }

    /// Haengt bestehende Eintraege an eine andere Mahlzeit oder einen anderen Tag.
    ///
    /// Bewusst kein Loeschen und Neuerfassen: dabei schaetzt die KI die Naehrwerte
    /// neu, und eine reine Zuordnungskorrektur wuerde die Tagessumme verschieben.
    static func move(args: [String]) async throws {
        let parsed   = try parseMoveArgs(args)
        let store    = try Store()
        let dateFlag = dateFlag(for: parsed.sourceDate)

        guard let selector = parsed.selector else {
            try printNumberedDayList(on: parsed.sourceDate, in: store,
                                     hint: "Umhängen mit: kk move <Nr…> --meal <Mahlzeit>\(dateFlag)")
            return
        }

        let moved: [Store.MovedEntry]
        do {
            moved = try store.moveEntries(
                on: parsed.sourceDate,
                selecting: selector,
                toMeal: parsed.targetMeal,
                toDate: parsed.targetDate
            )
        } catch let error as Store.MoveError {
            throw KKError(describe(error, source: parsed.sourceDate))
        }

        for entry in moved {
            print(line(for: entry))
        }

        // Beide Tage sind danach neu nummeriert, die Nummern von vorhin gelten nicht mehr.
        if moved.contains(where: \.changedDate), let target = parsed.targetDate {
            print(dim("Neue Nummern: kk move --date \(isoDay(target)) bzw. kk move\(dateFlag)"))
        }
    }

    /// Eine Ausgabezeile je Eintrag, im Stil von `kk delete`.
    private static func line(for entry: Store.MovedEntry) -> String {
        let head = " \(entry.name) (\(Int(entry.calories)) kcal)"

        guard entry.changedAnything else {
            return dim("·") + head + dim("  liegt bereits im \(entry.toMeal.displayName)"
                                        + " am \(formattedDate(entry.toDate))")
        }

        var changes: [String] = []
        if entry.changedMeal {
            changes.append("\(entry.fromMeal.displayName) → \(entry.toMeal.displayName)")
        }
        if entry.changedDate {
            changes.append("\(formattedDate(entry.fromDate)) → \(formattedDate(entry.toDate))")
        }
        return green("✓") + " Umgehängt:" + head + dim("  " + changes.joined(separator: ", "))
    }

    private static func describe(_ error: Store.MoveError, source date: Date) -> String {
        let dateStr = formattedDate(date)
        switch error {
        case .emptyDay:
            return "Keine Einträge am \(dateStr)."
        case .unknownNumbers(let numbers, let available):
            let list = numbers.map(String.init).joined(separator: ", ")
            let plural = numbers.count == 1 ? "Nummer" : "Nummern"
            return """
                Kein Eintrag mit \(plural) \(list) am \(dateStr) (vorhanden: 1 bis \(available)).
                Nutze 'kk move\(dateFlag(for: date))' für die Liste.
                """
        case .noEntriesInMeal(let meal):
            return "Am \(dateStr) liegt kein Eintrag im \(meal.displayName)."
        }
    }

    /// Parst die Argumente von `kk move`. Quelltag über `--date`/`--yesterday`,
    /// Ziel über `--meal`/`--time` und `--to-date`, Auswahl über Nummern oder `--from`.
    static func parseMoveArgs(_ args: [String]) throws -> MoveArgs {
        let (sourceDate, rest) = try extractDateOptions(args)
        var result = MoveArgs(sourceDate: sourceDate)
        var numbers: [Int] = []
        var fromMeal: MealType?
        var targetHour: Int?

        /// Der Wert hinter einer Option, mit der Option aus dem Argument selbst in
        /// der Fehlermeldung.
        func value(at i: Int) throws -> String {
            guard i + 1 < rest.count else { throw KKError("\(rest[i]) braucht einen Wert.") }
            return rest[i + 1]
        }

        var i = 0
        while i < rest.count {
            switch rest[i] {
            case "--meal":
                result.targetMeal = try MealType.from(string: value(at: i))
                i += 2
            case "--time":
                targetHour = try parseTimeHour(value(at: i))
                i += 2
            case "--to-date":
                result.targetDate = try parseDate(value(at: i))
                i += 2
            case "--from":
                fromMeal = try MealType.from(string: value(at: i))
                i += 2
            default:
                guard let number = Int(rest[i]) else {
                    throw KKError("""
                        Unerwartetes Argument: \(rest[i]). Erwartet werden Eintrags-Nummern.
                        Nutze 'kk move' für die nummerierte Liste.
                        """)
                }
                numbers.append(number)
                i += 1
            }
        }

        // Mahlzeit aus der Uhrzeit, aber `--meal` hat Vorrang — dieselbe Rangfolge
        // wie bei `kk add` (siehe `resolveMeal`).
        if result.targetMeal == nil, let targetHour {
            result.targetMeal = MealType.forHour(targetHour)
        }

        if let fromMeal {
            guard numbers.isEmpty else {
                throw KKError("Entweder Nummern oder --from, nicht beides.")
            }
            result.selector = .meal(fromMeal)
        } else if !numbers.isEmpty {
            result.selector = .numbers(numbers)
        }

        if result.selector != nil, !result.hasTarget {
            throw KKError("""
                Nichts zu ändern. Gib das Ziel an:
                  --meal \(MealType.cliNameHint)
                  --time HH:MM      Mahlzeit über die Uhrzeit
                  --to-date DATUM   auf einen anderen Tag buchen
                """)
        }

        if result.selector == nil, result.hasTarget {
            throw KKError("""
                Es fehlt die Auswahl: Eintrags-Nummern oder --from <Mahlzeit>.
                Nutze 'kk move' für die nummerierte Liste.
                """)
        }

        return result
    }

    // MARK: - kk focus

    /// Hebel lesen, setzen und die Tagesrueckmeldung erfassen.
    ///
    /// Bewusst als CLI: der Hebel entsteht im OKR-Check-In, nicht in der App.
    /// Die Montagsroutine setzt sie hier und liest per `report --json` die Adhaerenz
    /// der Vorwoche zurueck.
    static func focus(args: [String]) async throws {
        let sub = args.first ?? "status"
        let rest = Array(args.dropFirst())
        let store = try Store()

        switch sub {
        case "status", "":
            try printFocusStatus(store)

        case "set":
            try focusSet(store, args: rest)

        case "kept", "gehalten":
            let date = try focusDate(rest)
            let lever = try store.recordLeverCheck(kept: true, on: date)
            print(green("✓") + " Gehalten am \(formattedDate(date)): \(lever.text)")

        case "missed", "nicht-gehalten":
            let date = try focusDate(rest)
            let lever = try store.recordLeverCheck(kept: false, on: date)
            print(yellow("✗") + " Nicht gehalten am \(formattedDate(date)): \(lever.text)")

        case "report":
            try focusReport(store, args: rest)

        default:
            throw KKError("""
                Unbekanntes focus-Kommando: \(sub)
                Verfuegbar: status, set "…", kept, missed, report
                """)
        }
    }

    private static func focusSet(_ store: Store, args: [String]) throws {
        var text: String?
        var fromHour = 20
        var onSnack = true

        var i = 0
        while i < args.count {
            switch args[i] {
            case "--from-hour":
                i += 1
                guard i < args.count, let v = Int(args[i]), (0...23).contains(v) else {
                    throw KKError("--from-hour braucht eine Stunde zwischen 0 und 23")
                }
                fromHour = v
            case "--no-snack":
                onSnack = false
            default:
                text = args[i]
            }
            i += 1
        }

        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw KKError("Text fehlt. Beispiel: kk focus set \"Nuesse abwiegen, Tuete zurueck in den Schrank\"")
        }

        let lever = try store.setLever(text: text, triggerStartHour: fromHour, triggerOnSnack: onSnack)
        print(green("✓") + " Neuer Hebel gesetzt")
        print("  " + lever.text)
        let hourInfo = fromHour == 0 ? "immer sichtbar" : "hervorgehoben ab \(String(format: "%02d:00", fromHour))"
        print("  " + dim(hourInfo + (onSnack ? ", auch nach Snack/Abendessen" : "")))
    }

    /// Optionales `--date` fuer die Rueckmeldung (Standard: heute).
    private static func focusDate(_ args: [String]) throws -> Date {
        try extractDateOptions(args).date
    }

    private static func printFocusStatus(_ store: Store) throws {
        guard let lever = try store.activeLever() else {
            print(dim("Kein aktiver Hebel. Setzen mit: kk focus set \"…\""))
            return
        }

        print(bold("🎯 Hebel") + dim("  (seit \(formattedDate(lever.createdAt)), \(lever.ageInDays) Tage)"))
        print(String(repeating: "─", count: 50))
        print("  " + lever.text)

        let adherence = weekAdherence(for: lever, endingAt: Date(), days: 7)
        print("")
        print("  " + adherenceBar(adherence, lever: lever))
        print("  " + dim("\(adherence.kept) von \(adherence.totalDays) Tagen gehalten"))

        if let check = lever.check(for: Date()) {
            print("  " + (check.kept ? green("Heute: gehalten") : yellow("Heute: nicht gehalten")))
        } else {
            print("  " + dim("Heute noch offen — kk focus kept / kk focus missed"))
        }
    }

    /// Siebentage-Streifen: ● gehalten, ○ nicht gehalten, · unbeantwortet
    private static func adherenceBar(_ adherence: FocusLeverAdherence, lever: FocusLever) -> String {
        let calendar = Calendar.current
        return (0..<adherence.totalDays).map { offset -> String in
            guard let day = calendar.date(byAdding: .day, value: offset, to: adherence.start) else { return "·" }
            guard let check = lever.check(for: day) else { return dim("·") }
            return check.kept ? green("●") : yellow("○")
        }.joined(separator: " ")
    }

    private static func weekAdherence(for lever: FocusLever, endingAt end: Date, days: Int) -> FocusLeverAdherence {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: end.startOfDay) ?? end.startOfDay
        return FocusLeverAdherence.evaluate(checks: lever.checks ?? [], start: start, days: days)
    }

    private static func focusReport(_ store: Store, args: [String]) throws {
        var weeks = 4
        var asJSON = false

        var i = 0
        while i < args.count {
            switch args[i] {
            case "--weeks":
                i += 1
                if i < args.count, let v = Int(args[i]), v > 0 { weeks = v }
            case "--json":
                asJSON = true
            default:
                break
            }
            i += 1
        }

        let lever = try store.activeLever()
        let calendar = Calendar.current
        let today = Date().startOfDay

        // Wochenfenster rueckwaerts, juengste Woche zuerst
        let windows: [FocusLeverAdherence] = (0..<weeks).compactMap { index in
            guard let lever else { return nil }
            guard let end = calendar.date(byAdding: .day, value: -(index * 7), to: today) else { return nil }
            return weekAdherence(for: lever, endingAt: end, days: 7)
        }

        if asJSON {
            print(focusReportJSON(lever: lever, windows: windows))
            return
        }

        guard let lever else {
            print(dim("Kein aktiver Hebel."))
            return
        }

        print(bold("🎯 Adhaerenz") + dim("  (letzte \(weeks) Wochen)"))
        print(String(repeating: "─", count: 50))
        print("  " + lever.text)
        print("")
        for window in windows {
            let label = isoDay(window.start) + " bis " + isoDay(window.end)
            print("  \(label): " + bold("\(window.kept) / \(window.totalDays)") + dim(" gehalten"))
        }
    }

    /// Stabile JSON-Schnittstelle fuer die OKR-Check-In-Routine.
    private static func focusReportJSON(lever: FocusLever?, windows: [FocusLeverAdherence]) -> String {
        var root: [String: Any] = [:]

        if let lever {
            root["lever"] = [
                "text": lever.text,
                "createdAt": isoDay(lever.createdAt),
                "ageDays": lever.ageInDays
            ]
        } else {
            root["lever"] = NSNull()
        }

        root["weeks"] = windows.map { window in
            [
                "start": isoDay(window.start),
                "end": isoDay(window.end),
                "kept": window.kept,
                "missed": window.missed,
                "unanswered": window.unanswered,
                "rate": (window.rate * 100).rounded() / 100
            ] as [String: Any]
        }

        return jsonString(root)
    }

    // MARK: - kk stats

    static func stats(args: [String]) async throws {
        let parsed = parseStatsArgs(args)
        let store  = try Store()
        let weeks  = parsed.weeks
        let minEntries = parsed.minEntries

        let calendar = Calendar.current
        let today = Date()
        let startDate = calendar.date(byAdding: .weekOfYear, value: -weeks, to: calendar.startOfDay(for: today))!

        let entries = try store.entriesInRange(from: startDate, to: today)

        // Gruppiere nach ISO-Kalenderwoche
        var weekCounts: [String: Int] = [:]
        for entry in entries {
            let year = calendar.component(.yearForWeekOfYear, from: entry.date)
            let week = calendar.component(.weekOfYear, from: entry.date)
            let key  = "\(year)-W\(String(format: "%02d", week))"
            weekCounts[key, default: 0] += 1
        }

        let qualifyingWeeks = weekCounts.filter { $0.value >= minEntries }
        let count = qualifyingWeeks.count

        if parsed.format == "count" {
            print("\(count)")
            return
        }

        // Detaillierte Ausgabe
        print(bold("Tracking-Statistik") + dim("  (letzte \(weeks) Wochen, mind. \(minEntries) Eintraege/Woche)"))
        print(String(repeating: "─", count: 50))

        let sortedWeeks = weekCounts.keys.sorted()
        for weekKey in sortedWeeks {
            let c = weekCounts[weekKey]!
            let ok = c >= minEntries
            let marker = ok ? green("✓") : yellow("✗")
            print("  \(marker) \(weekKey): \(c) Eintraege")
        }

        print(String(repeating: "─", count: 50))
        print(bold("\(count) / \(weeks)") + " Wochen mit mind. \(minEntries) Eintraegen")
    }

    private struct StatsArgs {
        var weeks: Int      = 13
        var minEntries: Int = 5
        var format: String  = "table"
    }

    private static func parseStatsArgs(_ args: [String]) -> StatsArgs {
        var result = StatsArgs()
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--weeks":
                i += 1
                if i < args.count, let v = Int(args[i]) { result.weeks = v }
            case "--min-entries", "--min-entries-per-week":
                i += 1
                if i < args.count, let v = Int(args[i]) { result.minEntries = v }
            case "--format":
                i += 1
                if i < args.count { result.format = args[i] }
            default:
                break
            }
            i += 1
        }
        return result
    }

    // MARK: - Argument-Parser

    struct AddArgs {
        var meal: MealType?
        var description: String?
        var name: String?
        var calories: Double?
        var grams: Double   = 100
        var protein: Double = 0
        var carbs: Double   = 0
        var fat: Double     = 0
        /// Ohne diese drei zaehlen sie in der Ampel als 0, sobald Makros angegeben
        /// sind, und die Ampel faellt zu guenstig aus (Issue #98).
        var saturatedFat: Double = 0
        var sugar: Double   = 0
        var salt: Double    = 0
        var date: Date      = Date()
        /// Stunde aus `--time`, dient allein der Mahlzeit-Ableitung (siehe `resolveMeal`).
        var timeHour: Int?
    }

    /// Beschreibung der akzeptierten Datumsangaben, geteilt von allen Fehlermeldungen.
    private static let dateHint = "YYYY-MM-DD, 'heute', 'gestern' oder 'vorgestern'"

    /// Verarbeitet `--date <wert>`, `--yesterday` und `--gestern` an Position `i`.
    ///
    /// Rückgabe: Anzahl der verbrauchten Argumente, 0 wenn die Option nicht hierher
    /// gehört. Nur für `add` gedacht, das die Optionen zwischen seinen eigenen
    /// wertnehmenden Optionen erkennen muss; alle anderen Befehle nutzen
    /// `extractDateOptions(_:)`.
    private static func consumeDateOption(_ args: [String], at i: Int, into date: inout Date) throws -> Int {
        switch args[i] {
        case "--date":
            guard i + 1 < args.count else { throw KKError("--date braucht einen Wert (\(dateHint))") }
            date = try parseDate(args[i + 1])
            return 2
        case "--yesterday", "--gestern":
            date = try parseDate("gestern")
            return 1
        default:
            return 0
        }
    }

    /// Zieht die Datums-Optionen heraus und gibt die übrigen Argumente zurück.
    /// Standard ist heute. Die Optionen dürfen an beliebiger Stelle stehen
    /// (`kk coffee add 2 --yesterday` ebenso wie `kk coffee --yesterday add 2`).
    private static func extractDateOptions(_ args: [String]) throws -> (date: Date, rest: [String]) {
        var date = Date()
        var rest: [String] = []
        var i = 0
        while i < args.count {
            let consumed = try consumeDateOption(args, at: i, into: &date)
            if consumed > 0 {
                i += consumed
            } else {
                rest.append(args[i])
                i += 1
            }
        }
        return (date, rest)
    }

    /// Parst eine Datumsangabe: YYYY-MM-DD oder die Schlüsselwörter
    /// 'heute'/'today', 'gestern'/'yesterday', 'vorgestern'. Rückwirkende
    /// Tage werden auf 12:00 Uhr gesetzt, damit sie zuverlässig im Tagesbereich liegen.
    /// Zukünftige Tage werden abgelehnt: ein Tippfehler im Monat würde sonst still
    /// einen Eintrag in der Zukunft anlegen, den niemand mehr sucht.
    private static func parseDate(_ raw: String) throws -> Date {
        let cal = Calendar.current
        let resolved: Date
        switch raw.lowercased() {
        case "heute", "today":
            resolved = dayNoon(Date())
        case "gestern", "yesterday":
            resolved = dayNoon(cal.date(byAdding: .day, value: -1, to: Date())!)
        case "vorgestern":
            resolved = dayNoon(cal.date(byAdding: .day, value: -2, to: Date())!)
        default:
            guard let d = isoDayFormatter.date(from: raw) else {
                throw KKError("Ungültiges Datum: \(raw). Erwartet: \(dateHint).")
            }
            resolved = dayNoon(d)
        }

        guard !resolved.startOfDay.isFuture else {
            throw KKError("Datum liegt in der Zukunft: \(isoDay(resolved)). Buchbar sind nur heute und vergangene Tage.")
        }
        return resolved
    }

    /// Nicht `private`, damit die Tests gegen dieselbe Datumsform pruefen wie der Betrieb.
    static func dayNoon(_ date: Date) -> Date {
        Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
    }

    /// Formatter fuer ISO-Tagesdaten (YYYY-MM-DD) — geteilt von Parsen und Ausgabe.
    private static let isoDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "en_US_POSIX")
        f.timeZone   = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func parseAddArgs(_ args: [String]) throws -> AddArgs {
        var result = AddArgs()
        var i = 0

        while i < args.count {
            let consumed = try consumeDateOption(args, at: i, into: &result.date)
            if consumed > 0 {
                i += consumed
                continue
            }

            let arg = args[i]
            func number() throws -> Double {
                i += 1
                guard i < args.count, let v = Double(args[i]) else {
                    throw KKError("\(arg) braucht eine Zahl")
                }
                return v
            }

            switch arg {
            case "--time":
                i += 1
                guard i < args.count else { throw KKError("--time braucht einen Wert (HH:MM)") }
                result.timeHour = try parseTimeHour(args[i])

            case "--meal":
                i += 1
                guard i < args.count else { throw KKError("--meal braucht einen Wert") }
                result.meal = try MealType.from(string: args[i])

            case "--name":
                i += 1
                guard i < args.count else { throw KKError("--name braucht einen Wert") }
                result.name = args[i]

            case "--calories":      result.calories     = try number()
            case "--grams":         result.grams        = try number()
            case "--protein":       result.protein      = try number()
            case "--carbs":         result.carbs        = try number()
            case "--fat":           result.fat          = try number()
            case "--saturated-fat": result.saturatedFat = try number()
            case "--sugar":         result.sugar        = try number()
            case "--salt":          result.salt         = try number()

            default:
                if arg.hasPrefix("-") {
                    throw KKError("Unbekannte Option: \(arg). Nutze 'kk help' für Hilfe.")
                }
                result.description = arg
            }
            i += 1
        }
        return result
    }

    /// Parst `HH:MM` (oder `HH`) und liefert die Stunde. Die Minute wird nur geprüft:
    /// für die Mahlzeit-Ableitung zählt allein die Stunde.
    private static func parseTimeHour(_ raw: String) throws -> Int {
        let parts = raw.split(separator: ":", omittingEmptySubsequences: false)
        let invalid = KKError("Ungültige Uhrzeit: \(raw). Erwartet: HH:MM, z.B. 19:30.")

        guard (1...2).contains(parts.count),
              let hour = Int(parts[0]), (0...23).contains(hour) else { throw invalid }

        if parts.count == 2 {
            guard let minute = Int(parts[1]), (0...59).contains(minute) else { throw invalid }
        }
        return hour
    }

    // MARK: - JSON

    /// Serialisiert ein JSON-Objekt stabil (sortierte Schluessel, eingerueckt).
    /// Geteilt von allen `--json`-Ausgaben, damit Skripte sich auf dieselbe Form
    /// verlassen koennen.
    private static func jsonString(_ root: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    /// Maschinenlesbarer Tagesstand: Aufnahme, Qualitaet und Verbrauch in einem
    /// Aufruf. Zweck ist die taegliche Ernaehrungsauswertung, die sonst Farben
    /// und Zahlen aus formatiertem Text zurueckparsen muesste.
    private static func todayJSON(
        date: Date,
        entries: [DiaryEntry],
        goal: Int,
        totalCalories: Int,
        day: DayRecord.Day?,
        coffee: Store.CoffeeStatus?,
        summary: TrafficLightSummary
    ) -> String {
        let root: [String: Any] = [
            "date": isoDay(date),
            "calorieGoal": goal,
            "totalCalories": totalCalories,
            "remainingCalories": goal > 0 ? goal - totalCalories : NSNull(),
            "macros": [
                "proteinG":      round1(entries.reduce(0) { $0 + $1.protein }),
                "carbsG":        round1(entries.reduce(0) { $0 + $1.carbs }),
                "fatG":          round1(entries.reduce(0) { $0 + $1.fat }),
                "fiberG":        round1(entries.reduce(0) { $0 + $1.fiber }),
                "sugarG":        round1(entries.reduce(0) { $0 + $1.sugar }),
                "saturatedFatG": round1(entries.reduce(0) { $0 + $1.saturatedFat }),
                "saltG":         round1(entries.reduce(0) { $0 + $1.salt })
            ],
            "trafficLight": [
                "green":   summary.green,
                "amber":   summary.amber,
                "red":     summary.red,
                "unknown": summary.unknown
            ],
            "energy": energyJSON(day),
            // Immer gesetzt, notfalls null: ein Schluessel, der mal da ist und
            // mal fehlt, macht jede auswertende Zeile zur Fallunterscheidung.
            "coffee": coffeeJSON(coffee),
            "entries": entries.enumerated().map { index, entry in entryJSON(entry, index: index + 1) }
        ]

        return jsonString(root)
    }

    /// - Parameter index: 1-basiert und in derselben Reihenfolge wie `kk delete`,
    ///   damit ein ausgewerteter Eintrag ohne Umweg wieder loeschbar ist.
    private static func entryJSON(_ entry: DiaryEntry, index: Int) -> [String: Any] {
        let light = entry.foodItem?.trafficLight
        return [
            "index": index,
            "name": entry.foodItem?.name ?? "Unbekannt",
            "meal": entry.mealType.rawValue,
            "calories": Int(entry.calories),
            "grams": Int(entry.amountGrams),
            "proteinG": round1(entry.protein),
            "carbsG": round1(entry.carbs),
            "fatG": round1(entry.fat),
            "sugarG": round1(entry.sugar),
            "saturatedFatG": round1(entry.saturatedFat),
            "saltG": round1(entry.salt),
            // Kein Raten: fehlen die Naehrwerte, steht hier null statt einer
            // erfundenen gruenen Ampel (Issue #92).
            "trafficLight": light.map { ["rating": $0.rating.jsonName, "score": $0.score] as [String: Any] } ?? NSNull()
        ]
    }

    private static func coffeeJSON(_ status: Store.CoffeeStatus?) -> Any {
        guard let status else { return NSNull() }
        return [
            "cups": status.cups,
            "goal": status.goal,
            "caffeineMg": status.caffeineMg,
            "isWeekend": status.isWeekend
        ] as [String: Any]
    }

    private static func energyJSON(_ day: DayRecord.Day?) -> Any {
        guard let day else { return NSNull() }
        return [
            "activeEnergyKcal": day.activeEnergyKcal,
            "workoutCaloriesKcal": day.workoutCaloriesKcal,
            "nonWorkoutActiveEnergyKcal": day.nonWorkoutActiveEnergy,
            "steps": day.steps,
            "weightKg": day.weight.map { round1($0) } ?? NSNull()
        ] as [String: Any]
    }

    /// Eine Nachkommastelle — Naehrwerte genauer auszugeben taeuscht eine
    /// Praezision vor, die weder Datenbank noch KI-Schaetzung haben.
    ///
    /// Der Umweg ueber `NSDecimalNumber` ist noetig, weil `JSONSerialization`
    /// einen gerundeten `Double` wieder in voller Binaerbreite ausschreibt
    /// (`62.399999999999999`). Der dezimale Wert bleibt `62.4`.
    private static func round1(_ value: Double) -> NSDecimalNumber {
        NSDecimalNumber(string: String(format: "%.1f", value))
    }

    // MARK: - Formatierung

    private static func printEntryLine(
        name: String,
        entry: DiaryEntry,
        meal: MealType,
        dateStr: String,
        confidence: String?
    ) {
        let cals   = Int(entry.calories)
        let grams  = Int(entry.amountGrams)
        let prot   = Int(entry.protein)
        let carbs  = Int(entry.carbs)
        let fat    = Int(entry.fat)

        var line = green("✓") + " \(bold(name)) — \(bold("\(cals) kcal"))"
        line    += dim("  (P:\(prot)g | KH:\(carbs)g | F:\(fat)g | \(grams)g)")

        if let conf = confidence {
            let dots = confidenceDots(conf)
            line += "  \(dim("Konfidenz: \(dots)"))"
        }

        line += "\n  " + dim("\(meal.displayName)  |  \(dateStr)")
        print(line)
    }

    private static func confidenceDots(_ confidence: String) -> String {
        switch confidence {
        case "high":   return "● ● ●"
        case "medium": return "● ● ○"
        default:       return "● ○ ○"
        }
    }
}

// MARK: - Hilfsfunktionen

/// Einmal aufgebaut: `formattedDate` laeuft in `kk move` je Eintrag, und der Aufbau
/// eines DateFormatters ist die teuerste Einzeloperation im Ausgabepfad.
private let displayDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    f.locale    = Locale(identifier: "de_DE")
    return f
}()

private func formattedDate(_ date: Date) -> String {
    displayDateFormatter.string(from: date)
}

extension String {
    func leftPad(_ length: Int) -> String {
        let pad = max(0, length - self.count)
        return String(repeating: " ", count: pad) + self
    }
}
