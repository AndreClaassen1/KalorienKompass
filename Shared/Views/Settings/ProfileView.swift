//
//  ProfileView.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 05.03.26.
//

import SwiftUI
import SwiftData

/// Profilansicht: Persoenliche Daten, Ziele, Kalorien und Makros.
/// Getrennt von SettingsView — als eigener Tab (iPhone) bzw. Sidebar-Kategorie (iPad/Mac).
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?
    @State private var showCalculation = false

    var body: some View {
        profileForm
            .formStyle(.grouped)
            .navigationTitle("sidebar_profile")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: "settings") {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .navigationDestination(for: String.self) { id in
                if id == "settings" {
                    SettingsView()
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = SettingsViewModel(modelContext: modelContext)
                }
            }
    }

    private var profileForm: some View {
        Form {
            if let vm = viewModel {
                personalDataSection(vm)
                goalSection(vm)
                calorieSection(vm)
                macroSection(vm)
                activitySection(vm)
                coffeeSection(vm)
                coffeeWeekendSection(vm)
            }
        }
        .onChange(of: viewModel?.dailyCalorieGoal) { _, _ in guard viewModel?.isLoading != true else { return }; viewModel?.save() }
        .onChange(of: viewModel?.proteinGoalGrams) { _, _ in guard viewModel?.isLoading != true else { return }; viewModel?.save() }
        .onChange(of: viewModel?.carbsGoalGrams) { _, _ in guard viewModel?.isLoading != true else { return }; viewModel?.save() }
        .onChange(of: viewModel?.fatGoalGrams) { _, _ in guard viewModel?.isLoading != true else { return }; viewModel?.save() }
        .onChange(of: viewModel?.fiberGoalGrams) { _, _ in guard viewModel?.isLoading != true else { return }; viewModel?.save() }
        .onChange(of: viewModel?.dailyStepsGoal) { _, _ in guard viewModel?.isLoading != true else { return }; viewModel?.save() }
        .onChange(of: viewModel?.dailyWaterGoalMl) { _, _ in guard viewModel?.isLoading != true else { return }; viewModel?.save() }
        .onChange(of: viewModel?.exerciseCreditPercent) { _, _ in guard viewModel?.isLoading != true else { return }; viewModel?.save() }
        .onChange(of: viewModel?.weekendBonusPercent) { _, _ in guard viewModel?.isLoading != true else { return }; viewModel?.save() }
        .modifier(ProfileCoffeeModifier(viewModel: viewModel))
        .modifier(ProfileAutoCaloriesModifier(viewModel: viewModel))
        .sheet(isPresented: $showCalculation) {
            if let vm = viewModel {
                CalorieCalculationView(vm: vm)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func personalDataSection(_ vm: SettingsViewModel) -> some View {
        @Bindable var vm = vm
        Section("settings_personal_data") {
            // Kein Gewichts-Stepper mehr: das aktuelle Gewicht wird ausschliesslich
            // ueber das Wiegen (Gewicht-Kachel) gesetzt, damit es nur eine Quelle gibt.
            Stepper(value: $vm.heightCm, in: 100...250, step: 1) {
                HStack {
                    Text("settings_height")
                    Spacer()
                    Text("\(Int(vm.heightCm)) cm")
                        .foregroundStyle(.secondary)
                }
            }

            Stepper(value: $vm.age, in: 10...120, step: 1) {
                HStack {
                    Text("settings_age")
                    Spacer()
                    Text("\(vm.age)")
                        .foregroundStyle(.secondary)
                }
            }

            Picker("settings_gender", selection: $vm.gender) {
                ForEach(Gender.allCases) { g in
                    Text(g.localizedName).tag(g)
                }
            }

            BMIBarView(bmi: vm.currentBMI, compact: false)
                .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func goalSection(_ vm: SettingsViewModel) -> some View {
        @Bindable var vm = vm
        Section("goal_section_title") {
            Picker("goal_type_label", selection: $vm.goalType) {
                ForEach(GoalType.allCases) { type in
                    Text(type.localizedName).tag(type)
                }
            }

            if vm.goalType != .maintain {
                // Chronologisch: Startgewicht -> Startdatum -> Zielgewicht. Beide
                // Startfelder sind die Basis fuer den Fortschrittsring der Gewicht-Kachel;
                // Startgewicht ist mit dem aktuellen Gewicht vorbelegt, aber ueberschreibbar.
                HStack {
                    Text("goal_start_weight")
                    Spacer()
                    TextField("kg", value: Binding(
                        get: { vm.startWeightKg ?? vm.bodyWeightKg },
                        set: { vm.startWeightKg = $0 }
                    ), format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("kg")
                        .foregroundStyle(.secondary)
                }

                DatePicker(
                    "goal_start_date",
                    selection: Binding(
                        get: { vm.goalStartDate ?? Date() },
                        set: { vm.goalStartDate = $0 }
                    ),
                    displayedComponents: .date
                )

                HStack {
                    Text("goal_target_weight")
                    Spacer()
                    TextField("kg", value: $vm.weightGoalKg, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("kg")
                        .foregroundStyle(.secondary)
                }

                Picker("goal_weekly_rate", selection: $vm.weeklyWeightGoalKg) {
                    Text(String(localized: "weekly_rate_slow")).tag(-0.25)
                    Text(String(localized: "weekly_rate_moderate")).tag(-0.50)
                    Text(String(localized: "weekly_rate_fast")).tag(-0.75)
                    Text(String(localized: "weekly_rate_very_fast")).tag(-1.0)
                }
            }
        }
    }

    @ViewBuilder
    private func calorieSection(_ vm: SettingsViewModel) -> some View {
        @Bindable var vm = vm
        Section("settings_calories") {
            HStack {
                Text("calorie_bmr")
                Spacer()
                Text("\(vm.calculatedBMR) kcal")
                    .foregroundStyle(.secondary)
            }

            Picker("settings_activity_level", selection: $vm.activityLevel) {
                ForEach(ActivityLevel.allCases) { level in
                    Text(level.localizedName).tag(level)
                }
            }

            HStack {
                Text("calorie_tdee")
                Spacer()
                Text("\(vm.calculatedTDEE) kcal")
                    .foregroundStyle(.secondary)
            }

            #if canImport(HealthKit)
            Toggle("settings_healthkit_activity", isOn: $vm.useHealthKitActivity)

            if vm.useHealthKitActivity {
                Text("settings_healthkit_bonus_hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            #endif

            if vm.goalType != .maintain {
                HStack {
                    Text("calorie_deficit")
                    Spacer()
                    Text("\(vm.dailyDeficit) kcal")
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("calorie_your_goal")
                    .bold()
                Spacer()
                Text("\(vm.calculatedCalorieGoal) kcal")
                    .bold()
                    .foregroundStyle(.primary)
            }

            if vm.useHealthKitActivity {
                HStack {
                    Text("calorie_pal_activity")
                    Spacer()
                    Text("\(vm.palImpliedActivity) kcal")
                        .foregroundStyle(.secondary)
                }
                Text("settings_healthkit_pal_hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let goalDate = vm.estimatedGoalDate {
                HStack {
                    Text("goal_estimated_date")
                    Spacer()
                    Text(goalDate, style: .date)
                        .foregroundStyle(.secondary)
                }
            }

            if vm.isBelowSafetyLimit {
                Text("goal_safety_warning")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                showCalculation = true
            } label: {
                Label("calorie_show_calculation", systemImage: "function")
            }

            Toggle("calorie_auto_calories", isOn: $vm.useAutoCalories)

            if vm.useAutoCalories {
                Text("settings_auto_calories_hint")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Stepper(value: $vm.dailyCalorieGoal, in: 1000...5000, step: 50) {
                    HStack {
                        Text("settings_daily_goal")
                        Spacer()
                        Text("\(vm.dailyCalorieGoal) kcal")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func macroSection(_ vm: SettingsViewModel) -> some View {
        @Bindable var vm = vm
        Section("settings_macros") {
            Stepper(value: $vm.proteinGoalGrams, in: 10...300, step: 5) {
                HStack {
                    Text("settings_protein")
                    Spacer()
                    Text("\(vm.proteinGoalGrams) g")
                        .foregroundStyle(.secondary)
                }
            }

            Stepper(value: $vm.carbsGoalGrams, in: 50...500, step: 10) {
                HStack {
                    Text("settings_carbs")
                    Spacer()
                    Text("\(vm.carbsGoalGrams) g")
                        .foregroundStyle(.secondary)
                }
            }

            Stepper(value: $vm.fatGoalGrams, in: 10...200, step: 5) {
                HStack {
                    Text("settings_fat")
                    Spacer()
                    Text("\(vm.fatGoalGrams) g")
                        .foregroundStyle(.secondary)
                }
            }

            Stepper(value: $vm.fiberGoalGrams, in: 10...100, step: 5) {
                HStack {
                    Text("settings_fiber")
                    Spacer()
                    Text("\(vm.fiberGoalGrams) g")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func activitySection(_ vm: SettingsViewModel) -> some View {
        @Bindable var vm = vm
        Section("settings_activity") {
            Stepper(value: $vm.dailyStepsGoal, in: 1000...30000, step: 500) {
                HStack {
                    Text("settings_steps_goal")
                    Spacer()
                    Text("\(vm.dailyStepsGoal)")
                        .foregroundStyle(.secondary)
                }
            }

            Stepper(value: $vm.dailyWaterGoalMl, in: 500...5000, step: 250) {
                HStack {
                    Text("settings_water_goal")
                    Spacer()
                    Text("\(vm.dailyWaterGoalMl) ml")
                        .foregroundStyle(.secondary)
                }
            }

            Stepper(value: $vm.exerciseCreditPercent, in: 0...100, step: 10) {
                HStack {
                    Text("settings_exercise_credit")
                    Spacer()
                    Text("\(vm.exerciseCreditPercent) %")
                        .foregroundStyle(.secondary)
                }
            }
            Text("settings_exercise_credit_hint")
                .font(.caption)
                .foregroundStyle(.secondary)

            Stepper(value: $vm.weekendBonusPercent, in: 0...25, step: 5) {
                HStack {
                    Text("settings_weekend_bonus")
                    Spacer()
                    Text(vm.weekendBonusPercent == 0
                        ? String(localized: "settings_off")
                        : "\(vm.weekendBonusPercent) %")
                        .foregroundStyle(.secondary)
                }
            }
            Text("settings_weekend_bonus_hint")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

extension ProfileView {
    @ViewBuilder
    fileprivate func coffeeSection(_ vm: SettingsViewModel) -> some View {
        @Bindable var vm = vm
        Section("settings_coffee_section") {
            Stepper(value: $vm.dailyCoffeeGoal, in: 0...15, step: 1) {
                HStack {
                    Text("settings_coffee_goal")
                    Spacer()
                    Text("\(vm.dailyCoffeeGoal)")
                        .foregroundStyle(.secondary)
                }
            }

            Stepper(value: $vm.coffeeMlPerCup, in: 30...500, step: 10) {
                HStack {
                    Text("settings_coffee_ml_per_cup")
                    Spacer()
                    Text("\(vm.coffeeMlPerCup) ml")
                        .foregroundStyle(.secondary)
                }
            }

            Stepper(value: $vm.caffeineMgPerCup, in: 0...300, step: 5) {
                HStack {
                    Text("settings_coffee_caffeine_per_cup")
                    Spacer()
                    Text("\(vm.caffeineMgPerCup) mg")
                        .foregroundStyle(.secondary)
                }
            }

            Text("settings_coffee_hint")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    fileprivate func coffeeWeekendSection(_ vm: SettingsViewModel) -> some View {
        @Bindable var vm = vm
        Section("settings_coffee_weekend_section") {
            Stepper(value: $vm.weekendCoffeeGoal, in: 0...15, step: 1) {
                HStack {
                    Text("settings_coffee_weekend_goal")
                    Spacer()
                    Text("\(vm.weekendCoffeeGoal)")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(WeekdayEntry.all, id: \.weekday) { entry in
                Toggle(isOn: Binding(
                    get: { vm.isWeekendCoffeeDay(entry.weekday) },
                    set: { vm.setWeekendCoffeeDay(entry.weekday, enabled: $0) }
                )) {
                    Text(entry.name)
                }
            }

            Text("settings_coffee_weekend_hint")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Wochentage fuer den Wochenend-Kaffee-Picker
/// weekday folgt Calendar.Weekday: 1=Sonntag, 2=Montag, ..., 7=Samstag
private struct WeekdayEntry {
    let weekday: Int
    let name: LocalizedStringKey

    static let all: [WeekdayEntry] = [
        .init(weekday: 2, name: "weekday_monday"),
        .init(weekday: 3, name: "weekday_tuesday"),
        .init(weekday: 4, name: "weekday_wednesday"),
        .init(weekday: 5, name: "weekday_thursday"),
        .init(weekday: 6, name: "weekday_friday"),
        .init(weekday: 7, name: "weekday_saturday"),
        .init(weekday: 1, name: "weekday_sunday"),
    ]
}

// MARK: - Kaffee-Einstellungen onChange-Handler (ausgelagert wegen Type-Checker-Timeout)

private struct ProfileCoffeeModifier: ViewModifier {
    var viewModel: SettingsViewModel?

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel?.dailyCoffeeGoal) { _, _ in
                guard viewModel?.isLoading != true else { return }
                viewModel?.save()
            }
            .onChange(of: viewModel?.coffeeMlPerCup) { _, _ in
                guard viewModel?.isLoading != true else { return }
                viewModel?.save()
            }
            .onChange(of: viewModel?.caffeineMgPerCup) { _, _ in
                guard viewModel?.isLoading != true else { return }
                viewModel?.save()
            }
            .onChange(of: viewModel?.weekendCoffeeGoal) { _, _ in
                guard viewModel?.isLoading != true else { return }
                viewModel?.save()
            }
            .onChange(of: viewModel?.weekendCoffeeDaysRaw) { _, _ in
                guard viewModel?.isLoading != true else { return }
                viewModel?.save()
            }
    }
}

// MARK: - ViewModifier fuer Auto-Kalorien onChange-Handler (ProfileView)

private struct ProfileAutoCaloriesModifier: ViewModifier {
    var viewModel: SettingsViewModel?

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel?.bodyWeightKg) { _, _ in
                guard viewModel?.isLoading != true else { return }
                viewModel?.updateAutoCalories()
                viewModel?.updateAutoMacros()
                viewModel?.save()
            }
            .onChange(of: viewModel?.heightCm) { _, _ in
                guard viewModel?.isLoading != true else { return }
                viewModel?.updateAutoCalories()
                viewModel?.updateAutoMacros()
                viewModel?.save()
            }
            .onChange(of: viewModel?.age) { _, _ in
                guard viewModel?.isLoading != true else { return }
                viewModel?.updateAutoCalories()
                viewModel?.updateAutoMacros()
                viewModel?.save()
            }
            .onChange(of: viewModel?.gender) { _, _ in
                guard viewModel?.isLoading != true else { return }
                viewModel?.updateAutoCalories()
                viewModel?.updateAutoMacros()
                viewModel?.save()
            }
            .onChange(of: viewModel?.activityLevel) { _, _ in
                guard viewModel?.isLoading != true else { return }
                viewModel?.updateAutoCalories()
                viewModel?.updateAutoMacros()
                viewModel?.save()
            }
            .modifier(ProfileGoalModifier(viewModel: viewModel))
    }
}

private struct ProfileGoalModifier: ViewModifier {
    var viewModel: SettingsViewModel?

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel?.useAutoCalories) { _, newValue in
                guard viewModel?.isLoading != true else { return }
                if newValue == true {
                    viewModel?.updateAutoCalories()
                    viewModel?.updateAutoMacros()
                }
                viewModel?.save()
            }
            .onChange(of: viewModel?.goalType) { _, _ in
                guard viewModel?.isLoading != true else { return }
                viewModel?.updateAutoCalories()
                viewModel?.updateAutoMacros()
                viewModel?.save()
            }
            .onChange(of: viewModel?.weeklyWeightGoalKg) { _, _ in
                guard viewModel?.isLoading != true else { return }
                viewModel?.updateAutoCalories()
                viewModel?.updateAutoMacros()
                viewModel?.save()
            }
            .onChange(of: viewModel?.weightGoalKg) { _, _ in
                guard viewModel?.isLoading != true else { return }
                viewModel?.updateAutoCalories()
                viewModel?.updateAutoMacros()
                viewModel?.save()
            }
            .onChange(of: viewModel?.startWeightKg) { _, _ in
                guard viewModel?.isLoading != true else { return }
                viewModel?.save()
            }
            .onChange(of: viewModel?.goalStartDate) { _, _ in
                guard viewModel?.isLoading != true else { return }
                viewModel?.save()
            }
            .onChange(of: viewModel?.useHealthKitActivity) { _, _ in
                guard viewModel?.isLoading != true else { return }
                viewModel?.updateAutoCalories()
                viewModel?.updateAutoMacros()
                viewModel?.save()
            }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .modelContainer(PreviewSampleData.container)
}
