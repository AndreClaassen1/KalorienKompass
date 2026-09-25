//
//  KalorienKompassApp.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct KalorienKompassApp: App {

    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    let modelContainer = DataModel.shared.modelContainer

    @State private var navigationModel = NavigationModel.shared

    /// Haelt den Beobachter der Duplikat-Bereinigung am Leben (siehe `DuplicateCleanup`).
    @State private var cleanupReloader: RemoteImportReloader?

    init() {
        // Die Sitzung zur Uhr braucht Vorlauf: aktiviert sie erst der erste
        // Sendeversuch, geht genau dieser verloren (Issue #69).
        #if os(iOS)
        WatchSnapshotSender.shared.activate()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            // Der Fokus-Modus ist die einzige UI. Vollmodus und Abenteuer sind
            // mit Issue #66 entfernt worden.
            FocusDayView()
                .environment(navigationModel)
                .onAppear {
                    // Bewusst kein Profil-Auto-Insert hier: bei leerem Store
                    // steht der CloudKit-Import noch aus, ein Default-Profil
                    // verdraengte das echte (Issue #63). Es entsteht lazy in
                    // SettingsViewModel.save().
                    //
                    // CloudKit-Sync-Monitor initialisieren (Singleton, lauscht sofort)
                    _ = CloudKitSyncMonitor.shared

                    if cleanupReloader == nil {
                        // Einmal beim Start (fuer Altbestaende auf Geraeten, die
                        // gerade nichts zu importieren haben), danach nach jedem
                        // abgeschlossenen Import — gedrosselt, siehe DuplicateCleanup.
                        DuplicateCleanup.run(in: ModelContext(modelContainer))
                        cleanupReloader = RemoteImportReloader {
                            DuplicateCleanup.runIfDue(in: ModelContext(modelContainer))
                        }
                    }
                }
                .task {
                    #if canImport(HealthKit)
                    await HealthKitManager.shared.requestAuthorization()
                    #endif
                    await NotificationManager.shared.requestAuthorization()
                    // CloudKit-Diagnose beim Start ausgeben
                    await CloudKitConfiguration.printDiagnostics()
                }
                .onReceive(NotificationCenter.default.publisher(for: .addWaterFromNotification)) { notification in
                    if let ml = notification.userInfo?["ml"] as? Int {
                        handleAddWaterFromNotification(ml: ml)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .openFoodSearchFromNotification)) { notification in
                    if let mealRaw = notification.userInfo?["meal"] as? String,
                       let meal = MealType(rawValue: mealRaw) {
                        navigationModel.selectedMealTypeForSearch = meal
                        navigationModel.selectedDateForSearch = Date().startOfDay
                        navigationModel.showFoodSearch = true
                    }
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .modelContainer(modelContainer)
        #if os(macOS)
        .commands {
            // Schlankes Menue des Fokus-Modus (inkl. Essen diktieren, Cmd+D)
            FocusMenuCommands()
        }
        // Fokus-Modus: Fenster an die Inhaltsgroesse binden (kompakt, kein Stranden).
        .windowResizability(.contentSize)
        // Keine weisse Titelleiste: der Ambient-Hintergrund laeuft durchgehend bis
        // oben, Ampel-Buttons und Zahnrad liegen direkt darauf.
        .windowStyle(.hiddenTitleBar)
        #endif

        #if os(macOS)
        // Lebensmittelsuche als eigenes resizable Fenster statt Sheet
        Window("sidebar_food_search", id: "food-search") {
            FoodSearchView(
                selectedDate: navigationModel.selectedDateForSearch,
                selectedMealType: navigationModel.selectedMealTypeForSearch
            )
            .environment(navigationModel)
            .onDisappear {
                navigationModel.showFoodSearch = false
            }
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 700, height: 600)
        .windowResizability(.contentSize)

        // KI-Schnelleingabe als eigenes Fenster (⌘⇧K)
        Window("ai_quick_entry_title", id: "ai-quick-entry") {
            NavigationStack {
                AIQuickEntryView(selectedDate: Date()) {
                    // Fenster wird per Dismiss geschlossen
                }
            }
            .environment(navigationModel)
            .onDisappear {
                navigationModel.showAIQuickEntry = false
            }
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 520, height: 480)
        .windowResizability(.contentSize)

        // Keine `Settings`-Scene: sie zeigte dieselbe SettingsView wie das Sheet im
        // Fokus-Modus, sodass es zwei Einstellungs-Zugaenge mit unterschiedlichem
        // Aussehen gab. ⌘, laeuft ueber `FocusMenuCommands` auf dasselbe Sheet wie
        // das Zahnrad — und nur dort greift der NavigationLink aufs Profil, weil die
        // Scene keinen NavigationStack hatte.

        // Menubar — Restkalorien permanent sichtbar
        MenuBarExtra {
            MenuBarPopoverView()
                .modelContainer(modelContainer)
        } label: {
            MenuBarLabelView()
        }
        .menuBarExtraStyle(.window)
        #endif
    }

    /// Verarbeitet Deep Links aus Widgets
    ///
    /// `dashboard` braucht keine Behandlung mehr: die App zeigt seit dem
    /// Wegfall des Vollmodus (Issue #66) ohnehin nur den Fokus-Modus, das
    /// Oeffnen der App ist die ganze Aktion.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == DeepLink.scheme, url.host() == "addFood" else { return }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let mealRaw = components.queryItems?.first(where: { $0.name == "meal" })?.value,
           let meal = MealType(rawValue: mealRaw) {
            navigationModel.selectedMealTypeForSearch = meal
        }
        navigationModel.selectedDateForSearch = Date().startOfDay
        navigationModel.showFoodSearch = true
    }

    /// Verarbeitet Wasser-Hinzufuegen aus Notification-Action
    private func handleAddWaterFromNotification(ml: Int) {
        let context = modelContainer.mainContext
        let record = DayRecord.canonical(in: context, for: Date())
        record.waterIntakeMl += ml
        try? context.save()
    }
}

// MARK: - App Delegate (iOS)

#if os(iOS)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        return true
    }
}
#endif
