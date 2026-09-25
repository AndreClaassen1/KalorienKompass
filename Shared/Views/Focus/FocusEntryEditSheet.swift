//
//  FocusEntryEditSheet.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 13.07.26.
//
//  Schlankes Editier-Sheet fuer einen Tagebucheintrag im Fokus-Modus:
//  Menge, Mahlzeit und die wichtigsten Naehrwerte pro 100 g.
//

import SwiftUI
import SwiftData

struct FocusEntryEditSheet: View {
    let entry: DiaryEntry
    /// Wird nach dem Speichern/Loeschen aufgerufen, damit der Tag neu geladen wird
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var grams: Double = 0
    @State private var mealType: MealType = .snack
    @State private var caloriesPer100g: Double = 0
    @State private var proteinPer100g: Double = 0
    @State private var carbsPer100g: Double = 0
    @State private var fatPer100g: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("focus_edit_food") {
                    TextField("focus_edit_name", text: $name)
                    Picker("meal_type_label", selection: $mealType) {
                        ForEach(MealType.allCases) { meal in
                            Label(meal.localizedName, systemImage: meal.symbolName).tag(meal)
                        }
                    }
                    LabeledContent("focus_edit_grams") {
                        TextField("focus_edit_grams", value: $grams, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }
                }

                Section("focus_edit_per_100g") {
                    nutrientField("nutrient_calories", value: $caloriesPer100g)
                    nutrientField("nutrient_protein", value: $proteinPer100g)
                    nutrientField("nutrient_carbs", value: $carbsPer100g)
                    nutrientField("nutrient_fat", value: $fatPer100g)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("focus_edit_title")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") { save() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .onAppear(perform: load)
        #if os(macOS)
        .frame(minWidth: 420, idealWidth: 460, minHeight: 460, idealHeight: 520)
        #endif
    }

    private func nutrientField(_ titleKey: LocalizedStringKey, value: Binding<Double>) -> some View {
        LabeledContent(titleKey) {
            TextField(titleKey, value: value, format: .number)
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
        }
    }

    private func load() {
        name = entry.foodItem?.name ?? ""
        grams = entry.amountGrams
        mealType = entry.mealType
        caloriesPer100g = entry.foodItem?.caloriesPer100g ?? 0
        proteinPer100g = entry.foodItem?.proteinPer100g ?? 0
        carbsPer100g = entry.foodItem?.carbsPer100g ?? 0
        fatPer100g = entry.foodItem?.fatPer100g ?? 0
    }

    private func save() {
        if let food = entry.foodItem {
            food.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            food.caloriesPer100g = caloriesPer100g
            food.proteinPer100g = proteinPer100g
            food.carbsPer100g = carbsPer100g
            food.fatPer100g = fatPer100g
        }
        entry.amountGrams = max(grams, 1)
        entry.mealType = mealType
        try? modelContext.save()
        onSaved()
        dismiss()
    }
}
