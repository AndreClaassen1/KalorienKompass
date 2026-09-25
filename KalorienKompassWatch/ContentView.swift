//
//  ContentView.swift
//  KalorienKompassWatch
//
//  Erstellt von André Claaßen am 06.02.26.
//

#if os(watchOS)
import SwiftUI
import SwiftData
import CoreData
import WidgetKit

/// Hauptansicht der Watch App mit vertikalem Paging
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: WatchDayViewModel?
    @State private var healthKitManager = WatchHealthKitManager.shared

    var body: some View {
        TabView {
            if let vm = viewModel {
                DashboardView(viewModel: vm)
                MealsView(viewModel: vm)
                ActivityView(viewModel: vm, healthKitManager: healthKitManager)
            } else {
                ProgressView()
            }
        }
        .tabViewStyle(.verticalPage)
        .task {
            let vm = WatchDayViewModel(modelContext: modelContext)
            await vm.loadToday()
            viewModel = vm

            await healthKitManager.requestAuthorization()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await viewModel?.loadToday()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)) { notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                  event.type == .import,
                  event.endDate != nil,
                  event.error == nil else { return }
            // CloudKit-Import abgeschlossen — Daten neu laden + Komplikationen aktualisieren
            Task {
                await viewModel?.loadToday()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
#endif
