//
//  AIWatchSheet.swift
//  KalorienKompassWatch
//
//  Erstellt von André Claaßen am 20.02.26.
//

#if os(watchOS)
import SwiftData
import SwiftUI

/// Identifiable-Nutzlast fuer den Diktat-Flow: der gesprochene Text und optional
/// die Ziel-Mahlzeit. Wird von DashboardView und MealsView an `.sheet(item:)` uebergeben.
struct WatchDictation: Identifiable {
    let id = UUID()
    let text: String
    var meal: MealType?
}

/// KI-Schaetzung fuer die Watch. Nimmt diktierten Text entgegen, schaetzt die
/// Naehrwerte und laesst per Digital Crown die Menge feinjustieren. Der Text kommt
/// ausschliesslich ueber die native Diktat-Eingabe (TextFieldLink) — kein eigenes
/// Textfeld mehr. Ablauf: laden → bestaetigen (oder Fehler mit Wiederholen).
struct AIWatchSheet: View {
    var viewModel: WatchDayViewModel
    var preselectedMeal: MealType?
    /// Diktierter Text, der geschaetzt wird
    let dictatedText: String
    /// Wird nach erfolgreicher Buchung aufgerufen (fuer das Undo-Banner)
    var onBooked: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    enum AIWatchStep {
        case loading, confirmation, error
    }

    @State private var step: AIWatchStep = .loading
    @State private var estimate: AIFoodEstimate?
    @State private var portionGrams: Double = 100
    @State private var selectedMeal: MealType
    @State private var errorMessage: String?
    @FocusState private var gramsFocused: Bool

    init(viewModel: WatchDayViewModel,
         preselectedMeal: MealType? = nil,
         dictatedText: String,
         onBooked: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.preselectedMeal = preselectedMeal
        self.dictatedText = dictatedText
        self.onBooked = onBooked
        self._selectedMeal = State(initialValue: preselectedMeal ?? MealType.currentBasedOnTime)
    }

    var body: some View {
        NavigationStack {
            switch step {
            case .loading:
                loadingView
            case .confirmation:
                if let estimate {
                    confirmationView(estimate: estimate)
                }
            case .error:
                errorView
            }
        }
        .task {
            // Diktierten Text einmalig schaetzen.
            if estimate == nil {
                await estimateNutrients()
            }
        }
    }

    // MARK: - Laden

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.3)
            Text(dictatedText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.horizontal)
        .navigationTitle("watch_ai_title")
    }

    // MARK: - Fehler

    private var errorView: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await estimateNutrients() }
                } label: {
                    Text("watch_ai_retry")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button("cancel") { dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal)
        }
        .navigationTitle("watch_ai_title")
    }

    // MARK: - Bestaetigung

    private func confirmationView(estimate: AIFoodEstimate) -> some View {
        let kcal    = estimate.caloriesPer100g * portionGrams / 100
        let protein = estimate.proteinPer100g  * portionGrams / 100
        let lower   = max(10.0, estimate.estimatedWeightGrams - 200)
        let upper   = estimate.estimatedWeightGrams + 500

        return List {
            // Lebensmittel-Name
            Section {
                Text(estimate.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            // Gramm — steuerbar per Digital Crown
            Section {
                Text("\(Int(portionGrams)) g")
                    .font(.title2.bold())
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .focused($gramsFocused)
                    .digitalCrownRotation(
                        $portionGrams,
                        from: lower,
                        through: upper,
                        by: 10,
                        sensitivity: .medium,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true
                    )

                // Proportional berechnete Nährwerte
                HStack(spacing: 12) {
                    Label("\(Int(kcal)) kcal", systemImage: "flame.fill")
                        .foregroundStyle(.orange)
                    Label("\(Int(protein))g", systemImage: "figure.strengthtraining.traditional")
                        .foregroundStyle(.blue)
                }
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .center)
            }

            // Mahlzeit wählen
            Section {
                Picker("Mahlzeit", selection: $selectedMeal) {
                    ForEach(MealType.allCases) { meal in
                        Text(meal.localizedName)
                            .tag(meal)
                    }
                }
            }

            // Speichern
            Section {
                Button {
                    Task { await saveEntry() }
                } label: {
                    Text("watch_ai_confirm_button")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("watch_ai_title")
        .onAppear { gramsFocused = true }
    }

    // MARK: - Aktionen

    private func estimateNutrients() async {
        step = .loading
        errorMessage = nil
        do {
            let result = try await ClaudeAPIService.shared.estimateNutrients(
                description: dictatedText
            )
            estimate = result
            portionGrams = result.estimatedWeightGrams
            step = .confirmation
        } catch ClaudeAPIService.APIError.noAPIKey {
            errorMessage = String(localized: "ai_no_api_key_error")
            step = .error
        } catch {
            errorMessage = error.localizedDescription
            step = .error
        }
    }

    private func saveEntry() async {
        guard let est = estimate else { return }
        await viewModel.addAIEntry(
            estimate: est,
            mealType: selectedMeal,
            portionGrams: portionGrams
        )
        onBooked?()
        dismiss()
    }
}

#Preview {
    AIWatchSheet(
        viewModel: WatchDayViewModel(modelContext: PreviewSampleData.container.mainContext),
        dictatedText: "Apfel"
    )
}
#endif
