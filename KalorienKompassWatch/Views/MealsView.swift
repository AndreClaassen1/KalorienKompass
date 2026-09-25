//
//  MealsView.swift
//  KalorienKompassWatch
//
//  Erstellt von André Claaßen am 06.02.26.
//

#if os(watchOS)
import SwiftUI
import SwiftData

/// Uebersicht aller 6 Mahlzeiten mit Fortschritt
struct MealsView: View {
    var viewModel: WatchDayViewModel
    /// Diktierte Nutzlast (Text + Ziel-Mahlzeit) — praesentiert das KI-Sheet
    @State private var voiceEntry: WatchDictation?

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Auf eine Mahlzeit tippen -> direkt fuer diese Mahlzeit diktieren
                ForEach(MealType.allCases) { mealType in
                    TextFieldLink(prompt: Text("watch_focus_speak")) {
                        MealRowView(
                            mealType: mealType,
                            consumed: Int(viewModel.summaryForMeal(mealType).totalCalories),
                            budget: viewModel.calorieBudgetForMeal(mealType)
                        )
                    } onSubmit: { text in
                        submit(text, meal: mealType)
                    }
                    .buttonStyle(.plain)
                }

                // Allgemeines Hinzufuegen (Mahlzeit nach Uhrzeit)
                TextFieldLink(prompt: Text("watch_focus_speak")) {
                    Label("add_meal_button", systemImage: "plus.circle.fill")
                        .font(.caption)
                } onSubmit: { text in
                    submit(text, meal: nil)
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
            .padding(.horizontal)
        }
        .navigationTitle("meals_title")
        .sheet(item: $voiceEntry) { entry in
            AIWatchSheet(viewModel: viewModel, preselectedMeal: entry.meal, dictatedText: entry.text)
        }
    }

    private func submit(_ text: String, meal: MealType?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        voiceEntry = WatchDictation(text: trimmed, meal: meal)
    }
}

#Preview {
    MealsView(viewModel: WatchDayViewModel(modelContext: PreviewSampleData.container.mainContext))
}
#endif
