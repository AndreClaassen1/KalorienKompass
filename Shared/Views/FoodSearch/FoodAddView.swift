//
//  FoodAddView.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import SwiftUI
import SwiftData

/// Ansicht zum Hinzufuegen oder Bearbeiten eines Lebensmittels mit Mengen-Auswahl
struct FoodAddView: View {
    let foodItem: FoodItem
    let selectedDate: Date
    let selectedMealType: MealType
    let editingEntry: DiaryEntry?
    let onAdd: (Double, MealType) -> Void
    /// Wird im Edit-Modus gesetzt — ermoeglicht das Loeschen des Eintrags direkt aus dem Sheet
    var onDelete: (() -> Void)? = nil
    /// Legt statt eines Eintrags einen Plan an (Issue #99). Nur im Add-Modus
    /// sichtbar und nur, wenn der Aufrufer den Callback mitgibt.
    var onPlan: ((Double, MealType) -> Void)? = nil
    /// Ziel-Mahlzeit des Plans — steht im Button, damit sichtbar ist, wohin
    /// der Plan geht (kann von der angezeigten Mahlzeit abweichen).
    var planTarget: MealType = .dinner

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var currentMealType: MealType = .snack
    @State private var amountGrams: Double = 100
    @State private var selectedUnitTag: Int = 0 // 0=Gramm, 1=Portion, 2+=CustomUnit
    @State private var customization: FoodCustomization?
    @State private var showAddUnitSheet: Bool = false
    @State private var newUnitName: String = ""
    @State private var newUnitGrams: String = ""

    /// Ausgangswerte zum Erkennen von Aenderungen im Edit-Modus
    @State private var initialAmountGrams: Double = 0
    @State private var initialMealType: MealType = .snack
    @State private var showDeleteConfirmation: Bool = false

    /// Ist die View im Edit-Modus?
    private var isEditing: Bool { editingEntry != nil }

    /// Hat der Benutzer etwas am Eintrag veraendert?
    private var hasChanges: Bool {
        guard isEditing else { return true }
        return abs(amountGrams - initialAmountGrams) > 0.01 || currentMealType != initialMealType
    }

    private var isFavorite: Bool { customization != nil }

    private var servingGrams: Double {
        foodItem.defaultServingSizeGrams
    }

    /// Sortierte benutzerdefinierte Einheiten
    private var customUnits: [CustomUnit] {
        customization?.sortedUnits ?? []
    }

    private var calculatedCalories: Double {
        NutrientCalculator.caloriesForAmount(food: foodItem, grams: amountGrams)
    }

    private var calculatedProtein: Double {
        foodItem.proteinPer100g * amountGrams / 100.0
    }

    private var calculatedCarbs: Double {
        foodItem.carbsPer100g * amountGrams / 100.0
    }

    private var calculatedFat: Double {
        foodItem.fatPer100g * amountGrams / 100.0
    }

    var body: some View {
        VStack(spacing: 16) {
            // Lebensmittel-Info
            HStack {
                TrafficLightIndicator(foodItem: foodItem)
                VStack(alignment: .leading, spacing: 2) {
                    Text(foodItem.name)
                        .font(.headline)
                    if let brand = foodItem.brand, !brand.isEmpty {
                        Text(brand)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isEditing {
                    Picker(selection: $currentMealType) {
                        ForEach(MealType.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })) { type in
                            Label(type.localizedName, systemImage: type.symbolName)
                                .tag(type)
                        }
                    } label: {
                        Text("meal_type_label")
                    }
                    .pickerStyle(.menu)
                    .font(.caption)
                } else {
                    Label(selectedMealType.localizedName, systemImage: selectedMealType.symbolName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            Divider()

            // Mengen-Eingabe
            if horizontalSizeClass == .compact {
                compactAmountPicker
            } else {
                regularAmountPicker
            }

            Divider()

            // Berechnete Naehrwerte
            HStack(spacing: 20) {
                NutrientLabel("nutrient_calories", value: calculatedCalories, unit: " kcal", color: .primary)
                NutrientLabel("nutrient_protein", value: calculatedProtein, color: .blue)
                NutrientLabel("nutrient_carbs", value: calculatedCarbs, color: .green)
                NutrientLabel("nutrient_fat", value: calculatedFat, color: .orange)
            }
            .padding(.horizontal)

            Spacer()

            // Aktions-Buttons
            if isEditing {
                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("delete", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.large)

                    Button {
                        onAdd(amountGrams, currentMealType)
                        dismiss()
                    } label: {
                        Text("action_save")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!hasChanges)
                }
                .padding(.horizontal)
            } else {
                VStack(spacing: 12) {
                    Button {
                        onAdd(amountGrams, currentMealType)
                        dismiss()
                    } label: {
                        Text("action_add_to_diary")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if let onPlan {
                        Button {
                            onPlan(amountGrams, planTarget)
                            dismiss()
                        } label: {
                            Label {
                                Text(String(format: String(localized: "action_plan_for_meal"), planTarget.localizedString))
                            } icon: {
                                Image(systemName: "calendar.badge.clock")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .navigationTitle(isEditing ? "edit_food_title" : "add_food_title")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? .red : .secondary)
                }
            }
        }
        .sheet(isPresented: $showAddUnitSheet) {
            addUnitSheet
        }
        .confirmationDialog(
            "delete_entry_confirm_title",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("delete_entry_confirm_message")
        }
        .onAppear {
            loadCustomization()
            let startMeal = editingEntry?.mealType ?? selectedMealType
            let startGrams = editingEntry?.amountGrams ?? foodItem.defaultServingSizeGrams
            currentMealType = startMeal
            amountGrams = startGrams
            initialMealType = startMeal
            initialAmountGrams = startGrams
        }
    }

    // MARK: - iPhone: Kompakter Picker

    private var compactAmountPicker: some View {
        VStack(spacing: 8) {
            unitPicker
                .padding(.horizontal)

            unitInputControl
                .padding(.horizontal)
        }
    }

    // MARK: - iPad/Mac: Breiter Picker

    private var regularAmountPicker: some View {
        VStack(spacing: 8) {
            unitPicker
                .padding(.horizontal)

            if selectedUnitTag == 0 {
                HStack(spacing: 24) {
                    VStack(alignment: .leading) {
                        HStack {
                            Slider(value: $amountGrams, in: 10...1000, step: 5)
                            Stepper(
                                "\(Int(amountGrams)) g",
                                value: $amountGrams,
                                in: 10...1000,
                                step: 10
                            )
                            .fixedSize()
                        }
                    }
                }
                .padding(.horizontal)
            } else {
                unitInputControl
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Einheiten-Picker (dynamisch)

    @ViewBuilder
    private var unitPicker: some View {
        let hasCustomUnits = !customUnits.isEmpty

        if hasCustomUnits {
            // Menu-Picker bei eigenen Einheiten
            HStack {
                Picker("amount_type", selection: $selectedUnitTag) {
                    Text("amount_grams").tag(0)
                    Text("amount_servings").tag(1)
                    ForEach(Array(customUnits.enumerated()), id: \.offset) { index, unit in
                        Text(unit.name).tag(index + 2)
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                if isFavorite {
                    Button {
                        showAddUnitSheet = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }
        } else {
            // Segmented-Picker ohne eigene Einheiten
            HStack {
                Picker("amount_type", selection: $selectedUnitTag) {
                    Text("amount_grams").tag(0)
                    Text("amount_servings").tag(1)
                }
                .pickerStyle(.segmented)

                if isFavorite {
                    Button {
                        showAddUnitSheet = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .padding(.leading, 8)
                }
            }
        }
    }

    // MARK: - Eingabe-Control je nach gewaehlter Einheit

    @ViewBuilder
    private var unitInputControl: some View {
        if selectedUnitTag == 0 {
            // Gramm: Slider
            HStack {
                Slider(value: $amountGrams, in: 10...500, step: 5)
                Text("\(Int(amountGrams)) g")
                    .frame(width: 60, alignment: .trailing)
                    .monospacedDigit()
            }
        } else if selectedUnitTag == 1 {
            // Standard-Portion
            unitStepper(gramsPerUnit: servingGrams, description: foodItem.servingDescription)
        } else {
            // Benutzerdefinierte Einheit
            let unitIndex = selectedUnitTag - 2
            if unitIndex < customUnits.count {
                let unit = customUnits[unitIndex]
                unitStepper(gramsPerUnit: unit.gramsPerUnit, description: unit.name)
            }
        }
    }

    /// Stepper fuer portionsbasierte Eingabe
    private func unitStepper(gramsPerUnit: Double, description: String?) -> some View {
        Stepper(value: Binding(
            get: { amountGrams / gramsPerUnit },
            set: { amountGrams = $0 * gramsPerUnit }
        ), in: 0.25...20, step: 0.25) {
            HStack {
                Text(String(format: "%.2f", amountGrams / gramsPerUnit))
                if let desc = description {
                    Text("(\(desc))")
                        .foregroundStyle(.secondary)
                }
                Text("= \(Int(amountGrams)) g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Neue-Einheit-Sheet

    private var addUnitSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("custom_unit_name_placeholder", text: $newUnitName)
                } header: {
                    Text("custom_unit_name")
                }

                Section {
                    TextField("100", text: $newUnitGrams)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                } header: {
                    Text("custom_unit_grams_per_unit")
                }
            }
            .navigationTitle("add_custom_unit_title")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        resetUnitForm()
                        showAddUnitSheet = false
                    }
                    .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action_save") {
                        saveCustomUnit()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newUnitName.isEmpty || Double(newUnitGrams.replacingOccurrences(of: ",", with: ".")) == nil)
                }
            }
        }
    }

    // MARK: - Datenlogik

    /// Laedt die FoodCustomization fuer dieses Lebensmittel
    private func loadCustomization() {
        let barcode = foodItem.barcode
        let itemId = foodItem.itemId

        var descriptor = FetchDescriptor<FoodCustomization>()
        if let barcode, !barcode.isEmpty {
            descriptor.predicate = #Predicate<FoodCustomization> { c in
                c.barcode == barcode
            }
        } else {
            descriptor.predicate = #Predicate<FoodCustomization> { c in
                c.foodItemId == itemId
            }
        }

        customization = (try? modelContext.fetch(descriptor))?.first
    }

    /// Favorit ein-/ausschalten
    private func toggleFavorite() {
        if let existing = customization {
            // Favorit entfernen: Customization loeschen
            modelContext.delete(existing)
            try? modelContext.save()
            customization = nil
            // Zurueck auf Gramm, falls benutzerdefinierte Einheit ausgewaehlt war
            if selectedUnitTag >= 2 {
                selectedUnitTag = 0
            }
        } else {
            // Neuen Favoriten anlegen
            let c = FoodCustomization(
                barcode: foodItem.barcode,
                foodItemId: foodItem.itemId
            )
            modelContext.insert(c)
            try? modelContext.save()
            customization = c
        }
    }

    /// Benutzerdefinierte Einheit speichern
    private func saveCustomUnit() {
        guard let grams = Double(newUnitGrams.replacingOccurrences(of: ",", with: ".")) else { return }

        // Sicherstellen dass Customization existiert
        if customization == nil {
            let c = FoodCustomization(
                barcode: foodItem.barcode,
                foodItemId: foodItem.itemId
            )
            modelContext.insert(c)
            customization = c
        }

        let nextOrder = (customization?.customUnits?.count ?? 0)
        let unit = CustomUnit(name: newUnitName, gramsPerUnit: grams, sortOrder: nextOrder)
        unit.customization = customization
        modelContext.insert(unit)
        try? modelContext.save()

        // Neue Einheit direkt auswaehlen
        selectedUnitTag = nextOrder + 2
        amountGrams = grams

        resetUnitForm()
        showAddUnitSheet = false
    }

    private func resetUnitForm() {
        newUnitName = ""
        newUnitGrams = ""
    }
}
