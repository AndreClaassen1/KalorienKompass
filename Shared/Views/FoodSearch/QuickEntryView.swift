//
//  QuickEntryView.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 05.02.26.
//

import SwiftUI
import SwiftData

/// Schnelleintrag fuer Kalorien und Naehrwerte ohne Produktsuche
struct QuickEntryView: View {
    let selectedDate: Date
    let selectedMealType: MealType
    let onAdd: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var fiber: String = ""
    @State private var saveForLater: Bool = false
    @State private var showMacros: Bool = false

    private var caloriesValue: Double? {
        Double(calories.replacingOccurrences(of: ",", with: "."))
    }

    private var isValid: Bool {
        guard let cal = caloriesValue, cal > 0 else { return false }
        return true
    }

    var body: some View {
        Form {
            mealInfoSection
            nameSection
            caloriesSection
            macrosSection
            saveSection
            addButton
        }
        .navigationTitle("quick_entry_title")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var mealInfoSection: some View {
        Section {
            Label(selectedMealType.localizedName, systemImage: selectedMealType.symbolName)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var nameSection: some View {
        Section("quick_entry_name") {
            TextField("quick_entry_name_placeholder", text: $name)
        }
    }

    @ViewBuilder
    private var caloriesSection: some View {
        Section("quick_entry_calories") {
            TextField("0", text: $calories)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
        }
    }

    @ViewBuilder
    private var macrosSection: some View {
        Section {
            DisclosureGroup("quick_entry_macros", isExpanded: $showMacros) {
                TextField("quick_entry_protein", text: $protein)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                TextField("quick_entry_carbs", text: $carbs)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                TextField("quick_entry_fat", text: $fat)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                TextField("quick_entry_fiber", text: $fiber)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            }
        }
    }

    @ViewBuilder
    private var saveSection: some View {
        Section {
            Toggle("quick_entry_save_for_later", isOn: $saveForLater)
        } footer: {
            Text("quick_entry_save_description")
        }
    }

    @ViewBuilder
    private var addButton: some View {
        Section {
            Button {
                addEntry()
            } label: {
                Text("quick_entry_add")
                    .frame(maxWidth: .infinity)
                    .font(.headline)
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!isValid)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Logik

    private func addEntry() {
        guard let cal = caloriesValue else { return }

        let displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        let foodItem = FoodItem(
            name: displayName.isEmpty
                ? String(localized: "quick_entry_default_name")
                : displayName,
            caloriesPer100g: cal,
            proteinPer100g: parseDouble(protein),
            carbsPer100g: parseDouble(carbs),
            fatPer100g: parseDouble(fat),
            fiberPer100g: parseDouble(fiber)
        )
        foodItem.isQuickEntry = !saveForLater
        foodItem.isUserCreated = saveForLater

        let entry = DiaryEntry(
            date: selectedDate,
            mealType: selectedMealType,
            amountGrams: 100,
            foodItem: foodItem
        )

        modelContext.insert(foodItem)
        modelContext.insert(entry)
        try? modelContext.save()

        onAdd()
        dismiss()
    }

    private func parseDouble(_ text: String) -> Double {
        Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
}

#Preview {
    NavigationStack {
        QuickEntryView(
            selectedDate: Date(),
            selectedMealType: .lunch
        ) {}
    }
    .modelContainer(PreviewSampleData.container)
}
