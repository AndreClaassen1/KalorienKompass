//
//  QuickAddSheet.swift
//  KalorienKompassWatch
//
//  Erstellt von André Claaßen am 06.02.26.
//

#if os(watchOS)
import SwiftUI
import SwiftData

/// Fokus-Felder fuer QuickAddSheet
enum QuickAddField: Hashable {
    case name
    case calories
}

/// 2-Schritt-Flow fuer schnelle Kalorienerfassung
struct QuickAddSheet: View {
    var viewModel: WatchDayViewModel
    var preselectedMeal: MealType?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedMeal: MealType?
    @State private var name: String = ""
    @State private var calories: Double = 350
    @FocusState private var focusedField: QuickAddField?

    var body: some View {
        NavigationStack {
            if let meal = selectedMeal ?? preselectedMeal {
                // Schritt 2: Name + Kalorien
                calorieInputView(meal: meal)
            } else {
                // Schritt 1: Mahlzeit waehlen
                mealSelectionView
            }
        }
    }

    private var mealSelectionView: some View {
        List {
            ForEach(MealType.allCases) { meal in
                Button {
                    selectedMeal = meal
                } label: {
                    Label(meal.localizedName, systemImage: meal.symbolName)
                }
            }
        }
        .navigationTitle("select_meal_title")
    }

    private func calorieInputView(meal: MealType) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Kalorien - tappbar fuer Fokus
                VStack(spacing: 4) {
                    Text("\(Int(calories))")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(focusedField == .calories ? .orange : .orange.opacity(0.6))
                    Text("kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .focusable(true)
                .focused($focusedField, equals: .calories)
                .digitalCrownRotation(
                    $calories,
                    from: 50.0,
                    through: 2000.0,
                    by: 10.0,
                    sensitivity: .medium,
                    isHapticFeedbackEnabled: true
                )
                .onTapGesture {
                    focusedField = .calories
                }

                // Name-Eingabe
                TextField("name_placeholder", text: $name)
                    .focused($focusedField, equals: .name)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    .onSubmit {
                        focusedField = .calories
                    }

                // Speichern-Button
                Button {
                    Task {
                        let entryName = name.isEmpty ? String(localized: "quick_entry_default_name") : name
                        await viewModel.addQuickEntry(
                            name: entryName,
                            calories: Int(calories),
                            mealType: meal
                        )
                        dismiss()
                    }
                } label: {
                    Text("save_button")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle("quick_add_title")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("cancel_button") {
                    dismiss()
                }
            }
        }
        .onAppear {
            // Kalorien-Feld als Standard fokussieren
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .calories
            }
        }
    }
}

#Preview {
    QuickAddSheet(viewModel: WatchDayViewModel(modelContext: PreviewSampleData.container.mainContext))
}
#endif
