//
//  MenuBarPopoverView.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 06.04.26.
//

#if os(macOS)
import SwiftUI

/// Label-View fuer die Menubar — eigene Struct damit SwiftUI @Observable-Aenderungen trackt
struct MenuBarLabelView: View {
    private let vm = MenuBarViewModel.shared

    var body: some View {
        Label(vm.menuBarText, systemImage: vm.menuBarSymbol)
    }
}

/// Popover-Inhalt fuer die macOS Menubar
struct MenuBarPopoverView: View {
    private let vm = MenuBarViewModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Datum-Header
            dateHeader

            Divider()

            // Kalorienring + Zusammenfassung
            calorieSection

            Divider()

            // Mahlzeiten-Uebersicht
            mealsSection

            Divider()

            // Wasser
            waterSection

            Divider()

            // Kaffee
            coffeeSection

            Divider()

            // Schnelleingabe
            MenuBarQuickAddView()

            Divider()

            // App oeffnen
            openAppButton

            Divider()

            // Build-Info Fusszeile
            buildInfoFooter
        }
        .padding(16)
        .frame(width: 300)
        .background(keyboardShortcuts)
        .onAppear {
            vm.loadToday()
        }
        .onChange(of: NavigationModel.shared.entryAddedCount) {
            vm.loadToday()
        }
    }

    // MARK: - Sektionen

    private var dateHeader: some View {
        Text(Date(), format: .dateTime.weekday(.wide).day().month(.wide))
            .font(.headline)
    }

    private var calorieSection: some View {
        HStack(spacing: 16) {
            // Kompakter Kalorienring
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: min(vm.calorieProgress, 1.0))
                    .stroke(
                        calorieColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(Int(vm.remainingCalories))")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(calorieColor)
                    Text("kcal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 70, height: 70)

            VStack(alignment: .leading, spacing: 4) {
                if vm.isOverBudget {
                    Text("menubar_over_budget_label")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                } else {
                    Text("menubar_remaining_label")
                        .font(.subheadline.weight(.semibold))
                }

                Text("menubar_eaten_of_goal \(Int(vm.summary.totalCalories)) \(vm.effectiveCalorieGoal)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var mealsSection: some View {
        VStack(spacing: 6) {
            ForEach(vm.mainMealSummaries, id: \.mealType) { meal in
                HStack {
                    Image(systemName: meal.mealType.symbolName)
                        .frame(width: 16)
                        .foregroundStyle(.secondary)
                    Text(meal.mealType.localizedName)
                        .font(.callout)
                    Spacer()
                    if meal.calories > 0 {
                        Text("\(Int(meal.calories)) kcal")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        Text("—")
                            .font(.callout)
                            .foregroundStyle(.quaternary)
                    }
                }
            }
        }
    }

    private var waterSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.cyan)
                Text("\(vm.waterIntakeMl) ml")
                    .font(.callout)
                Spacer()
                Text("water_goal_of \(vm.waterGoalMl)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                ForEach(0..<vm.waterSlotCount, id: \.self) { index in
                    Button {
                        vm.setWaterGlasses(DrinkRow.newCount(tapped: index, filled: vm.filledGlasses))
                    } label: {
                        WaterGlassIcon(isFilled: index < vm.filledGlasses)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Tastaturbedienung des Popovers. Bewusst mit ⌘⇧: das Popover enthaelt ein
    /// Textfeld, modifierlose Buchstaben wuerden beim Tippen mitgefeuert. ⌘W allein
    /// scheidet aus (schliesst das Fenster).
    private var keyboardShortcuts: some View {
        ZStack {
            ShortcutButton(key: "w", modifiers: [.command, .shift]) { vm.addWaterGlass() }
            ShortcutButton(key: "k", modifiers: [.command, .shift]) { vm.addCoffee() }
        }
    }

    /// Kaffee, aufgebaut wie das Wasser darueber: Symbol und Zahl in der Zeile,
    /// darunter die anklickbaren Tassen. Die Bohne steht fuer den Kaffee, die
    /// Tassen fuer das Getrunkene — dieselbe Trennung wie Tropfen und Glaeser.
    private var coffeeSection: some View {
        // Einmal binden statt gut ein Dutzend Mal im Body: `coffeeGoal` liest den
        // Wochentag und drei SwiftData-Felder.
        let goal = vm.coffeeGoal
        let cups = vm.coffeeCups
        let ueberLimit = vm.coffeeOverLimit

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                CoffeeBeanIcon(color: ueberLimit ? .red : .brown)
                Text("coffee_cups_count \(cups)")
                    .font(.callout)
                    .foregroundStyle(ueberLimit ? Color.red : .primary)
                Spacer()
                Text("coffee_cups_max \(goal)")
                    .font(.caption)
                    .foregroundStyle(ueberLimit ? Color.red : .secondary)
            }

            HStack(spacing: 4) {
                ForEach(0..<vm.coffeeSlotCount, id: \.self) { index in
                    Button {
                        vm.setCoffeeCups(DrinkRow.newCount(tapped: index, filled: cups))
                    } label: {
                        CoffeeCupIcon(isFilled: index < cups, isOverLimit: index >= goal)
                    }
                    .buttonStyle(.plain)
                    // Die erste Tasse ueber dem Ziel bekommt Luft nach links,
                    // damit die Ueberschreitung auch ohne Farbe ablesbar bleibt.
                    .padding(.leading, index == goal ? 6 : 0)
                }
            }
        }
    }

    private var openAppButton: some View {
        Button {
            // Hauptfenster finden oder erstellen und aktivieren
            if let mainWindow = NSApplication.shared.windows.first(where: { !($0 is NSPanel) && $0.title != "" }) {
                mainWindow.makeKeyAndOrderFront(nil)
            }
            NSApplication.shared.activate(ignoringOtherApps: true)
        } label: {
            HStack {
                Image(systemName: "arrow.up.forward.app")
                Text("menubar_open_app")
            }
            .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
    }

    private var buildInfoFooter: some View {
        HStack {
            Text("KalorienKompass \(BuildInfo.version) (\(BuildInfo.buildNumber)) \u{2022} \(BuildInfo.configuration)")
            Spacer()
            Text(BuildInfo.buildDate)
        }
        .font(.caption2)
        .foregroundStyle(.quaternary)
    }

    // MARK: - Hilfsfunktionen

    private var calorieColor: Color {
        if vm.calorieProgress > 1.0 { return .red }
        if vm.calorieProgress > 0.85 { return .orange }
        return .green
    }
}
#endif
