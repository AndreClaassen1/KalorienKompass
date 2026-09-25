//
//  PlannedEntry.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 25.08.26.
//
//  Ein vorab festgelegter Tagebucheintrag (Issue #99): aus der Lebensmittelsuche
//  geplant, im Tagesbild ausgegraut angezeigt, per Tap als DiaryEntry uebernommen
//  oder spurlos verworfen. Eigenes Modell statt Flag auf DiaryEntry, damit kein
//  bestehender Fetch-Pfad (App, Widget, Watch, MenuBar, CLI) Plaene mitzaehlt.
//

import Foundation
import SwiftData

/// Eine geplante, noch nicht gegessene Mahlzeit
@Model
public class PlannedEntry {
    #Index<PlannedEntry>([\.date], [\.mealTypeRaw])

    /// Eindeutiger Bezeichner
    var plannedEntryId: String = UUID().uuidString

    /// Datum des geplanten Eintrags (nur Datum, ohne Uhrzeit)
    var date: Date = Date()

    /// Mahlzeitentyp als String (CloudKit-kompatibel)
    var mealTypeRaw: String = MealType.snack.rawValue

    /// Mahlzeitentyp (Computed Property)
    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }

    /// Menge in Gramm
    var amountGrams: Double = 100

    /// Anzahl Portionen (alternative Eingabe)
    var servings: Double = 1.0

    /// Zeitpunkt der Erstellung
    var createdAt: Date = Date()

    /// Referenz auf das Lebensmittel
    var foodItem: FoodItem?

    /// Kalorien fuer die geplante Menge
    var calories: Double {
        guard let food = foodItem else { return 0 }
        return food.caloriesPer100g * amountGrams / 100.0
    }

    init(
        date: Date = Date(),
        mealType: MealType = .snack,
        amountGrams: Double = 100,
        servings: Double = 1.0,
        foodItem: FoodItem? = nil
    ) {
        self.date = date.startOfDay
        self.mealTypeRaw = mealType.rawValue
        self.amountGrams = amountGrams
        self.servings = servings
        self.foodItem = foodItem
    }
}

// MARK: - Setzen, Uebernahme und Duplikat-Auswahl

extension PlannedEntry {

    /// Setzt den Plan fuer eine Mahlzeit eines Tages. Es gilt ein Plan je
    /// Mahlzeit und Tag: ein bestehender wird ersetzt (Muster
    /// `FocusLever.setActive`) — so lebt die Invariante am Modell statt in
    /// jedem Aufrufer. Speichert bewusst nicht selbst.
    @discardableResult
    static func setPlan(
        foodItem: FoodItem?,
        date: Date,
        mealType: MealType,
        amountGrams: Double,
        in context: ModelContext
    ) -> PlannedEntry {
        let day = date.startOfDay
        let raw = mealType.rawValue
        let descriptor = FetchDescriptor<PlannedEntry>(
            predicate: #Predicate<PlannedEntry> { plan in
                plan.date == day && plan.mealTypeRaw == raw
            }
        )
        for existing in (try? context.fetch(descriptor)) ?? [] {
            existing.discard(in: context, keeping: foodItem)
        }

        let plan = PlannedEntry(
            date: date,
            mealType: mealType,
            amountGrams: amountGrams,
            foodItem: foodItem
        )
        context.insert(plan)
        return plan
    }

    /// Loescht den Plan spurlos und raeumt sein Schnell-Lebensmittel mit ab,
    /// wenn es nur fuer diesen Plan angelegt wurde (KI-Schaetzung) und kein
    /// Tagebucheintrag es nutzt. Ein Lebensmittel aus der Suche bleibt stehen.
    func discard(in context: ModelContext, keeping keptFood: FoodItem? = nil) {
        if let food = foodItem, food.isQuickEntry, food !== keptFood,
           (food.diaryEntries ?? []).isEmpty {
            context.delete(food)
        }
        context.delete(self)
    }

    /// Materialisiert den Plan als echten `DiaryEntry` mit identischen Werten
    /// und verbraucht ihn. Speichert bewusst nicht selbst — Save, Reload und
    /// Widget-Refresh gehoeren dem Aufrufer (DayViewModel).
    @discardableResult
    func accept(in context: ModelContext) -> DiaryEntry {
        let entry = DiaryEntry(
            date: date,
            mealType: mealType,
            amountGrams: amountGrams,
            servings: servings,
            foodItem: foodItem
        )
        context.insert(entry)
        context.delete(self)
        return entry
    }

    /// Bei CloudKit-Duplikaten (ein Plan je Mahlzeit und Tag) gilt der zuletzt
    /// angelegte Plan; die String-ID ist der deterministische Tiebreak, damit
    /// alle Geraete dieselbe Wahl treffen.
    static func effective(among plans: [PlannedEntry]) -> PlannedEntry? {
        plans.max { lhs, rhs in
            lhs.createdAt == rhs.createdAt
                ? lhs.plannedEntryId > rhs.plannedEntryId
                : lhs.createdAt < rhs.createdAt
        }
    }
}
