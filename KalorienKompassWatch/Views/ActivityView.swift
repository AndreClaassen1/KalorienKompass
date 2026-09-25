//
//  ActivityView.swift
//  KalorienKompassWatch
//
//  Erstellt von André Claaßen am 06.02.26.
//

#if os(watchOS)
import SwiftUI
import SwiftData

/// Aktivitaetsansicht mit Schritten, aktiver Energie und Workouts
struct ActivityView: View {
    var viewModel: WatchDayViewModel
    var healthKitManager: WatchHealthKitManager

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Schritte gross
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "figure.walk")
                            .font(.title2)
                            .foregroundStyle(.green)
                        Text(String(localized: "steps_label"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(viewModel.dayRecord?.steps ?? 0)")
                        .font(.title)
                        .fontWeight(.bold)
                    ProgressBarView(
                        progress: viewModel.stepsProgress,
                        color: .green,
                        goal: viewModel.profile?.dailyStepsGoal ?? 10000
                    )
                }
                .padding(.vertical, 4)

                Divider()

                // Aktive Energie (ohne Workouts)
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text(String(localized: "active_energy_label"))
                        .font(.caption)
                    Spacer()
                    Text("\(viewModel.nonWorkoutActiveEnergy) kcal")
                        .font(.headline)
                }

                // Workout-Kalorien
                HStack {
                    Image(systemName: "figure.run")
                        .foregroundStyle(.red)
                    Text(String(localized: "workout_energy_label"))
                        .font(.caption)
                    Spacer()
                    Text("\(viewModel.dayRecord?.workoutCaloriesKcal ?? 0) kcal")
                        .font(.headline)
                }

                // Workout-Liste
                if !viewModel.workouts.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "workouts_label"))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(viewModel.workouts, id: \.activityName) { workout in
                            HStack {
                                Image(systemName: workout.symbolName)
                                    .foregroundStyle(.red)
                                VStack(alignment: .leading) {
                                    Text(workout.activityName)
                                        .font(.caption)
                                    Text("\(workout.durationMinutes) min")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(workout.caloriesBurned) kcal")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("activity_title")
    }
}

#Preview {
    ActivityView(
        viewModel: WatchDayViewModel(modelContext: PreviewSampleData.container.mainContext),
        healthKitManager: WatchHealthKitManager.shared
    )
}
#endif
