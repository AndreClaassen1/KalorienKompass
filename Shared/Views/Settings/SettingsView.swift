//
//  SettingsView.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import SwiftUI
import AppChangelog
import AppIntents
import SwiftData

/// Technische Einstellungen: Benachrichtigungen, Gewichtseinheit, KI, Datenbank, iCloud, About.
/// Profil-bezogene Sektionen sind in ProfileView.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        settingsForm
            .formStyle(.grouped)
            .navigationTitle("sidebar_settings")
            .onAppear {
                if viewModel == nil {
                    viewModel = SettingsViewModel(modelContext: modelContext)
                }
            }
    }

    private var settingsForm: some View {
        Form {
            if let vm = viewModel {
                profileSection
                leverSection
                siriSection
                notificationSection(vm)
                weightSection(vm)
                aiSettingsSection
                databaseSection
                iCloudSection
                aboutSection
            }
        }
        .onChange(of: viewModel?.weightUnit) { _, _ in guard viewModel?.isLoading != true else { return }; viewModel?.save() }
        .modifier(SettingsNotificationModifier(viewModel: viewModel))
    }

    // MARK: - Sections

    /// Einstiegspunkt zu den Koerperdaten. Im Fokus-Modus (der einzigen aktiven UI)
    /// ist dies der einzige Weg zu `ProfileView` — die Vollmodus-Navigation, die sie
    /// frueher zeigte, wird seit dem Fokus-Umstieg nicht mehr gerendert.
    private var profileSection: some View {
        Section {
            NavigationLink {
                ProfileView()
            } label: {
                Label("sidebar_profile", systemImage: "person.crop.circle")
            }
        }
    }

    /// Zugang zum aktuellen Hebel. Er wird hier gesetzt (bzw. per `kk focus set`
    /// aus dem OKR-Check-In) und im Fokus-Modus am Point of Decision angezeigt.
    private var leverSection: some View {
        Section {
            NavigationLink {
                FocusLeverDetailView()
            } label: {
                Label("focus_lever_title", systemImage: "target")
            }
        }
    }

    /// Die Siri-Phrasen sichtbar machen (Issue #74).
    ///
    /// Ohne diesen Abschnitt muss man wissen, dass es „Ich habe gegessen in
    /// KalorienKompass" heisst — die Kurzbefehle stehen sonst nirgends in der App.
    ///
    /// Bewusst als eigene Zeilen statt `SiriTipView`: Apples Ansicht bleibt leer,
    /// solange das System die Kurzbefehle nicht indexiert hat (im Simulator
    /// dauerhaft, auf dem Geraet nach einer Neuinstallation eine Weile) — und drei
    /// graue Platzhalter helfen niemandem. `ShortcutsLink` fuehrt weiterhin in die
    /// Kurzbefehle-App, wo sich eigene Phrasen anlegen lassen.
    private var siriSection: some View {
        Section("settings_siri") {
            ForEach(Self.siriPhrases, id: \.self) { phrase in
                Label {
                    Text(phrase)
                } icon: {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.tint)
                }
                .font(.callout)
            }
            #if os(iOS)
            ShortcutsLink()
            #endif
        }
    }

    /// Muessen zu den Phrasen in `KalorienKompassShortcuts` passen.
    private static let siriPhrases = [
        String(localized: "settings_siri_phrase_food"),
        String(localized: "settings_siri_phrase_water"),
        String(localized: "settings_siri_phrase_coffee")
    ]

    @ViewBuilder
    private func notificationSection(_ vm: SettingsViewModel) -> some View {
        @Bindable var vm = vm
        Section {
            Toggle(isOn: $vm.waterRemindersEnabled) {
                Label("settings_water_reminders", systemImage: "drop.fill")
            }

            Toggle(isOn: $vm.mealRemindersEnabled) {
                Label("settings_meal_reminders", systemImage: "fork.knife")
            }

            if vm.waterRemindersEnabled || vm.mealRemindersEnabled {
                HStack {
                    Text("settings_quiet_time")
                    Spacer()
                    Text("\(vm.quietTimeStartHour):00 – \(vm.quietTimeEndHour):00")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("settings_section_notifications")
        } footer: {
            if vm.waterRemindersEnabled || vm.mealRemindersEnabled {
                Text("settings_notifications_footer")
            }
        }
    }

    @ViewBuilder
    private func weightSection(_ vm: SettingsViewModel) -> some View {
        @Bindable var vm = vm
        Section("settings_weight") {
            Picker("settings_weight_unit", selection: $vm.weightUnit) {
                ForEach(WeightUnit.allCases) { unit in
                    Text(unit.localizedName).tag(unit)
                }
            }
        }
    }

    /// Prueft ob ein API-Key verfuegbar ist (eingebettet oder Keychain)
    private var hasAnyAPIKey: Bool {
        if let bundleKey = Bundle.main.infoDictionary?["ClaudeAPIKey"] as? String,
           !bundleKey.isEmpty {
            return true
        }
        return KeychainHelper.hasAPIKey
    }

    /// Ob der Key aus der App-Konfiguration stammt (nicht manuell eingegeben)
    private var hasBundledAPIKey: Bool {
        if let bundleKey = Bundle.main.infoDictionary?["ClaudeAPIKey"] as? String,
           !bundleKey.isEmpty {
            return true
        }
        return false
    }

    @ViewBuilder
    private var aiSettingsSection: some View {
        Section("ai_settings_title") {
            if hasAnyAPIKey {
                HStack {
                    Text("ai_settings_status")
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("ai_settings_connected")
                            .foregroundStyle(.secondary)
                    }
                }

                if !hasBundledAPIKey, KeychainHelper.hasAPIKey {
                    HStack {
                        Text("ai_settings_api_key")
                        Spacer()
                        if let masked = KeychainHelper.maskedAPIKey {
                            Text(masked)
                                .foregroundStyle(.secondary)
                                .font(.caption.monospaced())
                        }
                        Button(role: .destructive) {
                            KeychainHelper.deleteAPIKey()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("ai_settings_no_key")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("ai_settings_enter_key") {
                    showAPIKeyInput = true
                }

                Text("ai_settings_cost_hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showAPIKeyInput) {
            APIKeyInputSheet()
        }
    }

    @State private var showAPIKeyInput = false

    @ViewBuilder
    private var databaseSection: some View {
        Section("settings_offline_database") {
            DatabaseDownloadView()
        }
    }

    @ViewBuilder
    private var iCloudSection: some View {
        Section("sidebar_cloudkit") {
            NavigationLink {
                CloudKitDebugView()
            } label: {
                Label("sidebar_cloudkit", systemImage: "icloud")
            }
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section("settings_about") {
            HStack {
                Text("settings_version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }

            NavigationLink {
                ChangelogView(
                    changelog: BuildInfo.changelog,
                    currentVersion: BuildInfo.semanticVersion
                )
            } label: {
                Label("settings_whats_new", systemImage: "sparkles")
            }

            HStack {
                Text("settings_build")
                Spacer()
                Text(BuildInfo.buildDate)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("settings_build_type")
                Spacer()
                Text(buildType.name)
                    .foregroundStyle(buildType.color)
            }

            HStack {
                Text("CloudKit")
                Spacer()
                Text(cloudKitEnvironmentName)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var appVersion: String { BuildInfo.version }

    private var isProvisionedDevelopment: Bool {
        #if os(iOS) || os(watchOS)
        Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil
        #elseif os(macOS)
        FileManager.default.fileExists(atPath: Bundle.main.bundlePath + "/Contents/embedded.provisionprofile")
        #else
        false
        #endif
    }

    private var isTestFlightBuild: Bool {
        guard let receiptURL = (Bundle.main as NSObject).value(forKey: "appStoreReceiptURL") as? URL else {
            return false
        }
        return receiptURL.lastPathComponent == "sandboxReceipt"
            || receiptURL.path.contains("sandboxReceipt")
    }

    private var buildType: (name: String, color: Color) {
        #if DEBUG
        return (String(localized: "build_type_debug"), .orange)
        #else
        if isProvisionedDevelopment {
            return (String(localized: "build_type_deploy"), .purple)
        }
        if isTestFlightBuild {
            return (String(localized: "build_type_testflight"), .blue)
        }
        return (String(localized: "build_type_release"), .green)
        #endif
    }

    private var cloudKitEnvironmentName: String {
        let env = CloudKitConfiguration.detectEnvironment()
        return env.description
    }
}

/// ViewModifier fuer Notification-Einstellungen
private struct SettingsNotificationModifier: ViewModifier {
    var viewModel: SettingsViewModel?

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel?.waterRemindersEnabled) { _, _ in
                guard viewModel?.isLoading != true else { return }
                viewModel?.save()
            }
            .onChange(of: viewModel?.mealRemindersEnabled) { _, _ in
                guard viewModel?.isLoading != true else { return }
                viewModel?.save()
            }
            .onChange(of: viewModel?.quietTimeStartHour) { _, _ in
                guard viewModel?.isLoading != true else { return }
                viewModel?.save()
            }
            .onChange(of: viewModel?.quietTimeEndHour) { _, _ in
                guard viewModel?.isLoading != true else { return }
                viewModel?.save()
            }
    }
}

/// Sheet fuer die Eingabe des Anthropic API-Keys
private struct APIKeyInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("ai_settings_api_key", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                } footer: {
                    Text("ai_settings_cost_hint")
                }
            }
            .navigationTitle("ai_settings_enter_key")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") {
                        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            KeychainHelper.saveAPIKey(trimmed)
                        }
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(PreviewSampleData.container)
}
