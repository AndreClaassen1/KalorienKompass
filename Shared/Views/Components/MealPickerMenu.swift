//
//  MealPickerMenu.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 19.09.26.
//

import SwiftUI

/// Menue zur Wahl einer Mahlzeit, mit frei gestaltbarem Label.
///
/// Es gibt drei Orte, an denen eine Mahlzeit gewaehlt wird: die Pille am
/// Eingabefeld, das Popover der Menueleiste und die Eintragszeile samt
/// Kontextmenue. Sie unterscheiden sich allein im Label; die Liste selbst war
/// dreimal wortgleich ausgeschrieben, bevor sie hier zusammengezogen wurde.
struct MealPickerMenu<Label: View>: View {
    /// Die aktuell geltende Mahlzeit; sie traegt den Haken und ist kein Ziel.
    /// `nil` heisst: es gilt die Vorgabe nach Uhrzeit.
    let current: MealType?
    /// Blendet den Eintrag „Nach Uhrzeit" ein. Beim Umbuchen eines bereits
    /// gebuchten Eintrags gibt es diese Wahl nicht, dort liegt er in einer
    /// konkreten Mahlzeit.
    var allowsAutomatic: Bool = false
    /// `nil` steht fuer „Nach Uhrzeit" und kommt nur bei `allowsAutomatic`.
    let onSelect: (MealType?) -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Menu {
            if allowsAutomatic {
                Button {
                    onSelect(nil)
                } label: {
                    SwiftUI.Label(
                        "meal_by_time",
                        systemImage: current == nil ? "checkmark" : "clock"
                    )
                }
                .disabled(current == nil)

                Divider()
            }

            ForEach(MealType.sortedCases) { meal in
                Button {
                    onSelect(meal)
                } label: {
                    if meal == current {
                        SwiftUI.Label(meal.localizedName, systemImage: "checkmark")
                    } else {
                        SwiftUI.Label(meal.localizedName, systemImage: meal.symbolName)
                    }
                }
                .disabled(meal == current)
            }
        } label: {
            label()
        }
    }
}
