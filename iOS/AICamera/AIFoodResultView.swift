//
//  AIFoodResultView.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 05.02.26.
//
//  Bestaetigungsscreen fuer KI-erkannte Mahlzeit (nur iOS)
//

#if os(iOS)
import SwiftUI
import SwiftData

/// Zeigt das Ergebnis der KI-Erkennung und erlaubt Bestaetigung/Anpassung
struct AIFoodResultView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let capturedImage: UIImage
    let selectedDate: Date
    let selectedMealType: MealType
    let onComplete: () -> Void

    @State private var viewModel: AIFoodViewModel?
    @State private var showDetails = false
    @State private var showCamera = false

    var body: some View {
        Group {
            if showCamera {
                AIFoodCameraView { newImage in
                    showCamera = false
                    Task {
                        await viewModel?.analyzeImage(newImage)
                    }
                }
            } else if let vm = viewModel {
                resultContent(vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(viewModel?.estimate != nil ? "ai_result_title" : "ai_camera_title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = AIFoodViewModel(modelContext: modelContext)
                viewModel = vm
                Task {
                    await vm.analyzeImage(capturedImage)
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
                    nutrientCardView(vm)
                    portionView(vm)
                    confidenceView(vm)
                    componentsView(vm)
                    reAnalyzeSection(vm)
                    if showDetails {
                        detailsEditView(vm)
                    }
                    adjustButton
                    confirmButton(vm)
                    retakeButton
                }
                .padding()
            }
        }
    }

    // MARK: - Lade-Zustand

    private var analyzingView: some View {
        VStack(spacing: 24) {
            Image(uiImage: capturedImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
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
                showCamera = true
            } label: {
                Text("ai_retake_button")
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Ergebnis-Komponenten

    private var foodImageView: some View {
        Image(uiImage: capturedImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
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

    private func nutrientCardView(_ vm: AIFoodViewModel) -> some View {
        HStack(spacing: 0) {
            nutrientColumn(
                value: String(format: "%.0f", vm.portionCalories),
                unit: "kcal",
                label: String(localized: "settings_calories")
            )
            nutrientColumn(
                value: String(format: "%.1f", vm.portionCarbs),
                unit: "g",
                label: String(localized: "settings_carbs")
            )
            nutrientColumn(
                value: String(format: "%.1f", vm.portionProtein),
                unit: "g",
                label: String(localized: "settings_protein")
            )
            nutrientColumn(
                value: String(format: "%.1f", vm.portionFat),
                unit: "g",
                label: String(localized: "settings_fat")
            )
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

    private func portionView(_ vm: AIFoodViewModel) -> some View {
        @Bindable var vm = vm
        return HStack {
            Text("ai_estimated_portion")
                .foregroundStyle(.secondary)
            Spacer()
            TextField("g", value: $vm.editedPortionGrams, format: .number)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .keyboardType(.decimalPad)
            Text("g")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private func confidenceView(_ vm: AIFoodViewModel) -> some View {
        HStack {
            Text("ai_confidence")
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 4) {
                let level = vm.estimate?.confidenceLevel ?? .medium
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

    @ViewBuilder
    private func componentsView(_ vm: AIFoodViewModel) -> some View {
        if let components = vm.estimate?.components, !components.isEmpty {
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
                    await vm.reanalyzeWithHint()
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
            detailRow("settings_protein", value: $vm.editedProteinPer100g, suffix: "g/100g")
            detailRow("settings_carbs", value: $vm.editedCarbsPer100g, suffix: "g/100g")
            detailRow("settings_fat", value: $vm.editedFatPer100g, suffix: "g/100g")
            detailRow("settings_fiber", value: $vm.editedFiberPer100g, suffix: "g/100g")
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
                .keyboardType(.decimalPad)
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

    private var retakeButton: some View {
        Button {
            showCamera = true
        } label: {
            Text("ai_retake_button")
                .foregroundStyle(.tint)
        }
    }
}
#endif
