//
//  CalorieBudgetSheet.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 26.07.26.
//
//  Zeigt, wie das Tagesziel zustande kommt (Issue #80). Ohne diese Ansicht ist
//  nicht erkennbar, dass von der verbrannten Energie nur ein Teil im Budget
//  ankommt: der im PAL-Faktor implizierte Anteil steckt schon im Grundziel.
//

import SwiftUI

struct CalorieBudgetSheet: View {
    let breakdown: NutrientCalculator.GoalBreakdown
    let eaten: Int
    let date: Date

    @Environment(\.dismiss) private var dismiss

    /// Wie eine Zeile gelesen werden soll. Ersetzt mehrere Flags, die sonst an drei
    /// Stellen einzeln ausgewertet wuerden.
    private enum RowStyle {
        /// Ausgangswert, schlicht
        case plain
        /// Kommt oben drauf, mit Pluszeichen und in Gruen
        case bonus
        /// Zwischensumme
        case sum
        /// Das Ergebnis: gruen, solange Budget da ist
        case result
    }

    private var remaining: Int { breakdown.total - eaten }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row("budget_base", value: breakdown.base)

                    if breakdown.weekendBonus > 0 {
                        row(
                            "budget_weekend",
                            value: breakdown.weekendBonus,
                            note: "budget_weekend_note \(breakdown.weekendPercent)",
                            style: .bonus
                        )
                    }

                    if breakdown.usesActivity {
                        row(
                            "budget_activity",
                            value: breakdown.activityBonus,
                            note: "budget_activity_note \(breakdown.activityRaw) \(breakdown.activityIncludedInBase)",
                            style: .bonus
                        )
                    } else if breakdown.activityRaw > 0 {
                        // Ohne PAL-Bonus-Modell zaehlt Alltagsbewegung gar nicht. Der
                        // Ring zeigt sie trotzdem an, also gehoert die Erklaerung
                        // hierher — sonst bleibt offen, wo sie geblieben ist.
                        VStack(alignment: .leading, spacing: 2) {
                            Text("budget_activity")
                            Text("budget_activity_not_counted \(breakdown.activityRaw)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if breakdown.workoutRaw > 0 {
                        row(
                            "budget_workout",
                            value: breakdown.workoutBonus,
                            note: "budget_workout_note \(breakdown.workoutRaw) \(breakdown.workoutPercent)",
                            style: .bonus
                        )
                    }
                } header: {
                    Text(date.formattedMedium)
                }

                Section {
                    row("budget_goal_today", value: breakdown.total, style: .sum)
                    row("budget_eaten", value: -eaten)
                    row("budget_remaining", value: remaining, style: .result)
                }
            }
            .navigationTitle("budget_title")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, idealWidth: 420, minHeight: 420, idealHeight: 480)
        #endif
    }

    /// Eine Zeile: Bezeichnung links, Betrag rechts, erklaerender Halbsatz darunter.
    private func row(
        _ title: LocalizedStringKey,
        value: Int,
        note: LocalizedStringKey? = nil,
        style: RowStyle = .plain
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            LabeledContent {
                Text(formatted(value, style: style))
                    .foregroundStyle(color(for: value, style: style))
                    .monospacedDigit()
            } label: {
                Text(title)
            }
            .font(style == .plain || style == .bonus ? .body : .body.weight(.semibold))

            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Bonuszeilen tragen ihr Pluszeichen, damit erkennbar bleibt, was oben
    /// draufkommt und was abgezogen wird.
    private func formatted(_ value: Int, style: RowStyle) -> String {
        let zahl = value.formatted(.number)
        return style == .bonus && value >= 0 ? "+\(zahl)" : zahl
    }

    private func color(for value: Int, style: RowStyle) -> Color {
        switch style {
        case .bonus: .green
        case .result: value >= 0 ? .green : .red
        case .plain, .sum: .primary
        }
    }
}

#Preview {
    CalorieBudgetSheet(
        breakdown: NutrientCalculator.GoalBreakdown(
            base: 2475,
            weekendBonus: 248,
            weekendPercent: 10,
            usesActivity: true,
            activityRaw: 1325,
            activityIncludedInBase: 983,
            workoutRaw: 420,
            workoutPercent: 50
        ),
        eaten: 1862,
        date: Date()
    )
}
