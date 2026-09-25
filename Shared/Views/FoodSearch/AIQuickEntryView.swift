//
//  AIQuickEntryView.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 19.02.26.
//

import SwiftUI
import SwiftData

/// Freitext-Schnelleingabe mit KI-Naehrwertschaetzung
struct AIQuickEntryView: View {
    let selectedDate: Date
    var initialMealType: MealType = .lunch
    let onAdd: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AIQuickEntryViewModel()

    var body: some View {
        Group {
            if viewModel.estimate != nil {
                resultPhase
            } else {
                inputPhase
            }
        }
        .onAppear { viewModel.mealType = initialMealType }
        .navigationTitle("ai_quick_entry_title")
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
        .frame(minWidth: 520, idealWidth: 580, minHeight: 420, idealHeight: 580)
        #endif
    }

    // MARK: - Eingabe-Phase (Form)

    private var inputPhase: some View {
        Form {
            mealPickerSection
            inputSection
            if viewModel.isLoading {
                loadingSection
            } else if let error = viewModel.errorMessage {
                errorSection(error)
            }
        }
    }

    @ViewBuilder
    private var mealPickerSection: some View {
        Section {
            Picker("ai_quick_entry_meal", selection: $viewModel.mealType) {
                ForEach(MealType.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })) { meal in
                    Label(meal.localizedName, systemImage: meal.symbolName).tag(meal)
                }
            }
        }
    }

    @ViewBuilder
    private var inputSection: some View {
        Section("ai_quick_entry_description") {
            TextField("ai_quick_entry_placeholder", text: $viewModel.description, axis: .vertical)
                .lineLimit(1...3)
                .onSubmit {
                    let text = viewModel.description.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty, !viewModel.isLoading, viewModel.hasAPIKey else { return }
                    Task { await viewModel.estimateNutrients() }
                }

            if !viewModel.hasAPIKey {
                Label("ai_quick_entry_no_key", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }

            Button {
                Task { await viewModel.estimateNutrients() }
            } label: {
                Label("ai_quick_entry_estimate", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(
                viewModel.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || viewModel.isLoading
                || !viewModel.hasAPIKey
            )
        }
    }

    @ViewBuilder
    private var loadingSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    ProgressView()
                    Text("ai_quick_entry_loading")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func errorSection(_ message: String) -> some View {
        Section {
            Text(message)
                .foregroundStyle(.red)
                .font(.subheadline)
            Button {
                Task { await viewModel.estimateNutrients() }
            } label: {
                Label("ai_quick_entry_retry", systemImage: "arrow.clockwise")
            }
        } header: {
            Text("ai_quick_entry_error")
        }
    }

    // MARK: - Ergebnis-Phase (wie Foto-Flow)

    @ViewBuilder
    private var resultPhase: some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(spacing: 20) {
                // Mahlzeit-Picker
                mealPickerRow

                // Erkannter Name (editierbar)
                TextField("ai_result_title", text: $vm.editedName)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Nährwert-Kacheln (skalieren mit Portion)
                AIEstimateNutrientCard(
                    calories: viewModel.portionCalories,
                    carbs:    viewModel.portionCarbs,
                    protein:  viewModel.portionProtein,
                    fat:      viewModel.portionFat
                )
                .padding(.horizontal)

                // Portionsgröße (editierbar → proportionale Umrechnung)
                AIEstimatePortionRow(portionGrams: $vm.editedPortionGrams)

                // Konfidenz
                if let est = viewModel.estimate {
                    AIEstimateConfidenceRow(level: est.confidenceLevel)

                    // Bestandteile
                    AIEstimateComponentsList(components: est.components)
                        .padding(.horizontal)
                }

                Divider()
                    .padding(.horizontal)

                // Für später speichern
                Toggle("quick_entry_save_for_later", isOn: $vm.saveForLater)
                    .padding(.horizontal)

                // Hinzufügen-Button
                Button {
                    viewModel.saveEntry(date: selectedDate, context: modelContext)
                    onAdd()
                    dismiss()
                } label: {
                    Text("quick_entry_add")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .padding(.horizontal)
                .disabled(viewModel.portionCalories <= 0)

                // Zurück zur Eingabe
                Button {
                    viewModel.clearEstimate()
                } label: {
                    Text("ai_quick_entry_new_estimate")
                        .foregroundStyle(.tint)
                }
                .padding(.bottom)
            }
            .padding(.vertical)
        }
    }

    private var mealPickerRow: some View {
        HStack {
            Text("ai_quick_entry_meal")
                .foregroundStyle(.secondary)
            Spacer()
            Picker("", selection: $viewModel.mealType) {
                ForEach(MealType.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })) { meal in
                    Label(meal.localizedName, systemImage: meal.symbolName).tag(meal)
                }
            }
            .labelsHidden()
        }
        .padding(.horizontal)
    }
}

#Preview {
    NavigationStack {
        AIQuickEntryView(selectedDate: Date()) {}
    }
    .modelContainer(PreviewSampleData.container)
}
