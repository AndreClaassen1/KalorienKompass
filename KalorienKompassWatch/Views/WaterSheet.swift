//
//  WaterSheet.swift
//  KalorienKompassWatch
//
//  Erstellt von André Claaßen am 06.02.26.
//

#if os(watchOS)
import SwiftUI
import SwiftData

/// Ein-Tap Wassererfassung mit vordefinierten Mengen
struct WaterSheet: View {
    var viewModel: WatchDayViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Aktueller Stand
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "drop.fill")
                            .font(.title2)
                            .foregroundStyle(.cyan)
                        Text("\(viewModel.dayRecord?.waterIntakeMl ?? 0)")
                            .font(.system(size: 36, weight: .bold))
                        Text("ml")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: min(viewModel.waterProgress, 1.0))
                        .tint(.cyan)
                        .padding(.horizontal)

                    Text("\(viewModel.profile?.dailyWaterGoalMl ?? 2000) ml " + String(localized: "goal_suffix"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Schnell-Buttons
                HStack(spacing: 8) {
                    WaterButton(amount: 150) {
                        await addWater(ml: 150)
                    }
                    WaterButton(amount: 250) {
                        await addWater(ml: 250)
                    }
                    WaterButton(amount: 500) {
                        await addWater(ml: 500)
                    }
                }
            }
            .padding()
            .navigationTitle("water_title")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done_button") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func addWater(ml: Int) async {
        await viewModel.addWater(ml: ml)
    }
}

/// Button fuer eine Wassermenge
struct WaterButton: View {
    let amount: Int
    let action: () async -> Void

    var body: some View {
        Button {
            Task {
                await action()
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.cyan)
                Text("+\(amount)")
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}

#Preview {
    WaterSheet(viewModel: WatchDayViewModel(modelContext: PreviewSampleData.container.mainContext))
}
#endif
