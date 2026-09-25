//
//  CalorieCalculationView.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 07.02.26.
//

import SwiftUI

/// Aufschluesselung der Kalorienberechnung als Sheet.
/// Extrahiert aus SettingsView, um Type-Checker-Timeouts zu vermeiden.
struct CalorieCalculationView: View {
    @Environment(\.dismiss) private var dismiss
    let vm: SettingsViewModel

    /// Wikipedia-Link abhaengig von der aktuellen Sprache
    private var wikipediaURL: URL {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        if lang == "de" {
            return URL(string: "https://de.wikipedia.org/wiki/Grundumsatz#Mifflin-St.Jeor-Formel")!
        }
        return URL(string: "https://en.wikipedia.org/wiki/Basal_metabolic_rate#BMR_estimation_formulas")!
    }

    var body: some View {
        NavigationStack {
            List {
                formulaSection
                bmrSection
                tdeeSection

                if vm.goalType != .maintain {
                    deficitSection
                }

                goalSection

                if vm.useHealthKitActivity {
                    healthKitBonusSection
                }
            }
            .navigationTitle("calorie_show_calculation")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, idealWidth: 550, minHeight: 500, idealHeight: 650)
        #endif
    }

    // MARK: - Erklaerungstext-Hilfsview

    private func explanation(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Formel-Header

    private var formulaSection: some View {
        Section {
            Link(destination: wikipediaURL) {
                HStack {
                    Label("calorie_formula_name", systemImage: "book")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            explanation("calorie_formula_description")
        }
    }

    // MARK: - BMR-Berechnung

    private var bmrSection: some View {
        Section("calorie_bmr") {
            explanation("calorie_bmr_description")

            VStack(alignment: .leading, spacing: 4) {
                let genderOffset = vm.gender == .male ? "+5" : "−161"
                Text("10 × \(vm.bodyWeightKg, specifier: "%.1f") + 6,25 × \(Int(vm.heightCm)) − 5 × \(vm.age) \(genderOffset)")
                    .font(.footnote.monospaced())
                Text("= \(vm.calculatedBMR) kcal")
                    .font(.footnote.monospaced().bold())
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - TDEE-Berechnung

    private var tdeeSection: some View {
        Section("calorie_tdee") {
            explanation("calorie_tdee_description")

            VStack(alignment: .leading, spacing: 4) {
                Text("\(vm.calculatedBMR) × \(vm.activityLevel.palFactor, specifier: "%.3f") (\(vm.activityLevel.localizedName))")
                    .font(.footnote.monospaced())
                Text("= \(vm.calculatedTDEE) kcal")
                    .font(.footnote.monospaced().bold())
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Defizit-Berechnung

    private var deficitSection: some View {
        Section("calorie_deficit") {
            explanation("calorie_deficit_description")

            VStack(alignment: .leading, spacing: 4) {
                let weeklyAbs = abs(vm.weeklyWeightGoalKg)
                let sign = vm.weeklyWeightGoalKg < 0 ? "−" : "+"
                Text("\(sign)\(weeklyAbs, specifier: "%.2f") kg/\(String(localized: "calorie_week_short")) × 7.700 ÷ 7")
                    .font(.footnote.monospaced())
                Text("= \(vm.dailyDeficit) kcal/\(String(localized: "calorie_day_short"))")
                    .font(.footnote.monospaced().bold())
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Ziel-Berechnung

    private var goalSection: some View {
        Section("calorie_your_goal") {
            explanation("calorie_goal_description")

            VStack(alignment: .leading, spacing: 4) {
                if vm.goalType == .maintain {
                    Text("\(vm.calculatedTDEE) kcal")
                        .font(.footnote.monospaced().bold())
                } else {
                    Text("\(vm.calculatedTDEE) + (\(vm.dailyDeficit))")
                        .font(.footnote.monospaced())
                    Text("= \(vm.calculatedCalorieGoal) kcal")
                        .font(.footnote.monospaced().bold())

                    if vm.isBelowSafetyLimit {
                        let minimum = BMICalculator.safetyMinimum(gender: vm.gender)
                        Text("(\(String(localized: "calorie_clamped_to_minimum")) \(minimum) kcal)")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Apple Watch Bonus

    private var healthKitBonusSection: some View {
        Section("calorie_healthkit_bonus") {
            explanation("calorie_healthkit_bonus_description")

            VStack(alignment: .leading, spacing: 8) {
                // Schritt 1: Erwartete Aktivitaet aus PAL
                VStack(alignment: .leading, spacing: 2) {
                    Text("calorie_pal_step1_label")
                        .font(.footnote.bold())
                    Text("\(vm.calculatedTDEE) − \(vm.calculatedBMR) = \(vm.palImpliedActivity) kcal")
                        .font(.footnote.monospaced())
                }

                // Schritt 2: Bonus-Formel
                VStack(alignment: .leading, spacing: 2) {
                    Text("calorie_pal_step2_label")
                        .font(.footnote.bold())
                    Text("\(String(localized: "calorie_bonus_formula"))")
                        .font(.footnote.monospaced())
                }

                // Schritt 3: Workout-Anrechnung
                if vm.exerciseCreditPercent > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("calorie_pal_step3_label")
                            .font(.footnote.bold())
                        Text("calorie_pal_step3_detail_\(vm.exerciseCreditPercent)")
                            .font(.footnote.monospaced())
                    }
                }
            }
            .foregroundStyle(.secondary)
        }
    }
}
