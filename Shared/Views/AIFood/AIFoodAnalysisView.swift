//
//  AIFoodAnalysisView.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 07.02.26.
//
//  Plattformuebergreifende Ergebnis-View fuer KI-Erkennung (Data-basiert)
//

import SwiftUI
import SwiftData

// MARK: - Geteilte KI-Ergebnis-Komponenten
// Werden von AIFoodAnalysisView UND AIQuickEntryView verwendet.

struct AIEstimateNutrientCard: View {
    let calories: Double
    let carbs: Double
    let protein: Double
    let fat: Double

    var body: some View {
        HStack(spacing: 0) {
            nutrientColumn(value: String(format: "%.0f", calories), unit: "kcal",
                           label: String(localized: "settings_calories"))
            nutrientColumn(value: String(format: "%.1f", carbs),    unit: "g",
                           label: String(localized: "settings_carbs"))
            nutrientColumn(value: String(format: "%.1f", protein),  unit: "g",
                           label: String(localized: "settings_protein"))
            nutrientColumn(value: String(format: "%.1f", fat),      unit: "g",
                           label: String(localized: "settings_fat"))
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func nutrientColumn(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value) \(unit)")
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AIEstimatePortionRow: View {
    @Binding var portionGrams: Double

    var body: some View {
        HStack {
            Text("ai_estimated_portion")
                .foregroundStyle(.secondary)
            Spacer()
            TextField("g", value: $portionGrams, format: .number)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
            Text("g")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }
}

struct AIEstimateConfidenceRow: View {
    let level: ConfidenceLevel

    var body: some View {
        HStack {
            Text("ai_confidence")
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 4) {
                Text(level.localizedName)
                    .foregroundStyle(.secondary)
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i < level.dots ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct AIEstimateComponentsList: View {
    let components: [FoodComponent]

    var body: some View {
        if !components.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("ai_components")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                ForEach(components, id: \.name) { component in
                    HStack {
                        Text(component.name)
                        Spacer()
                        Text("~\(Int(component.estimatedGrams)) g")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - AIFoodAnalysisView

/// Zeigt das Ergebnis der KI-Erkennung und erlaubt Bestaetigung/Anpassung (plattformuebergreifend)
struct AIFoodAnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let imageData: Data
    let selectedDate: Date
    let selectedMealType: MealType
    let onComplete: () -> Void

    @State private var viewModel: AIFoodViewModel?
    @State private var showDetails = false

    var body: some View {
        Group {
            if let vm = viewModel {
                resultContent(vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(viewModel?.estimate != nil ? "ai_result_title" : "ai_camera_title")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, idealWidth: 600, minHeight: 500, idealHeight: 700)
        #endif
        .onAppear {
            if viewModel == nil {
                let vm = AIFoodViewModel(modelContext: modelContext)
                viewModel = vm
                Task {
                    await vm.analyzeImageData(imageData)
                }
            }
        }
    }

    // MARK: - Ergebnis-Inhalt

    @ViewBuilder
    private func resultContent(_ vm: AIFoodViewModel) -> some View {
        if vm.isAnalyzing {
            analyzingView
        } else if let error = vm.errorMessage {
            errorView(error)
        } else if vm.estimate != nil {
            ScrollView {
                VStack(spacing: 20) {
                    foodImageView
                    foodNameView(vm)
                    AIEstimateNutrientCard(
                        calories: vm.portionCalories,
                        carbs: vm.portionCarbs,
                        protein: vm.portionProtein,
                        fat: vm.portionFat
                    )
                    AIEstimatePortionRow(portionGrams: Bindable(vm).editedPortionGrams)
                    AIEstimateConfidenceRow(level: vm.estimate?.confidenceLevel ?? .medium)
                    AIEstimateComponentsList(components: vm.estimate?.components ?? [])
                    reAnalyzeSection(vm)
                    if showDetails {
                        detailsEditView(vm)
                    }
                    adjustButton
                    confirmButton(vm)
                }
                .padding()
            }
        }
    }

    // MARK: - Lade-Zustand

    private var analyzingView: some View {
        VStack(spacing: 24) {
            dataImage
                .frame(maxHeight: 250)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 4)

            ProgressView()
                .scaleEffect(1.5)

            Text("ai_analyzing")
                .font(.headline)

            Text("ai_analyzing_hint")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Fehler-Zustand

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("ai_error_not_food", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button {
                dismiss()
            } label: {
                Text("cancel")
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Bild-Anzeige

    @ViewBuilder
    private var dataImage: some View {
        #if canImport(UIKit)
        if let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
        #elseif canImport(AppKit)
        if let nsImage = NSImage(data: imageData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
        #endif
    }

    private var foodImageView: some View {
        dataImage
            .frame(maxHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 4)
    }

    private func foodNameView(_ vm: AIFoodViewModel) -> some View {
        @Bindable var vm = vm
        return TextField("ai_result_title", text: $vm.editedName)
            .font(.title2.bold())
            .multilineTextAlignment(.center)
    }

    // MARK: - Erneute Analyse mit Hinweis

    private func reAnalyzeSection(_ vm: AIFoodViewModel) -> some View {
        @Bindable var vm = vm
        return VStack(alignment: .leading, spacing: 12) {
            Label("ai_reanalyze_title", systemImage: "sparkles")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            TextField("ai_reanalyze_placeholder", text: $vm.userHint, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.roundedBorder)

            Button {
                showDetails = false
                Task {
                    await vm.reanalyzeDataWithHint()
                }
            } label: {
                Text("ai_reanalyze_button")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(vm.userHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Detail-Bearbeitung

    @ViewBuilder
    private func detailsEditView(_ vm: AIFoodViewModel) -> some View {
        @Bindable var vm = vm
        VStack(spacing: 12) {
            detailRow("settings_calories", value: $vm.editedCaloriesPer100g, suffix: "kcal/100g")
            detailRow("settings_protein",  value: $vm.editedProteinPer100g,  suffix: "g/100g")
            detailRow("settings_carbs",    value: $vm.editedCarbsPer100g,    suffix: "g/100g")
            detailRow("settings_fat",      value: $vm.editedFatPer100g,      suffix: "g/100g")
            detailRow("settings_fiber",    value: $vm.editedFiberPer100g,    suffix: "g/100g")
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func detailRow(_ label: LocalizedStringKey, value: Binding<Double>, suffix: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            TextField("0", value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
            Text(suffix)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Buttons

    private var adjustButton: some View {
        Button {
            withAnimation { showDetails.toggle() }
        } label: {
            Text("ai_adjust_details")
                .foregroundStyle(.tint)
        }
    }

    private func confirmButton(_ vm: AIFoodViewModel) -> some View {
        Button {
            vm.createEntry(date: selectedDate, mealType: selectedMealType)
            onComplete()
            dismiss()
        } label: {
            Text("ai_confirm_button")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
    }
}
