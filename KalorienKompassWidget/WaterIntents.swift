//
//  WaterIntents.swift
//  KalorienKompassWidget
//
//  Erstellt von André Claaßen am 05.02.26.
//

import AppIntents
import SwiftData
import WidgetKit

/// AppIntent: 250ml Wasser hinzufuegen
struct AddWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "widget_add_water"
    static var description: IntentDescription = "widget_add_water"

    @MainActor
    func perform() async throws -> some IntentResult {
        let container = DataModel.shared.modelContainer
        let context = ModelContext(container)

        // Schreibpfad: legt bei Bedarf an und fuehrt CloudKit-Duplikate zusammen.
        // Ohne das schrieb der Widget-Knopf auf einen beliebigen Record des Tages,
        // waehrend die App den kanonischen anzeigte (Issue #65).
        let record = DayRecord.canonical(in: context, for: Date())
        record.waterIntakeMl += 250
        try? context.save()

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// AppIntent: 250ml Wasser entfernen
struct RemoveWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "widget_remove_water"
    static var description: IntentDescription = "widget_remove_water"

    @MainActor
    func perform() async throws -> some IntentResult {
        let container = DataModel.shared.modelContainer
        let context = ModelContext(container)

        // Dekrement auf dem kanonischen Record. Auf einem Duplikat gebucht wuerde
        // es der naechste max()-Merge wieder hochziehen (Issue #65). Kein Record
        // heisst: es gibt nichts abzuziehen.
        if let record = DayRecord.existing(in: context, for: Date()) {
            record.waterIntakeMl = max(record.waterIntakeMl - 250, 0)
            try? context.save()
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
