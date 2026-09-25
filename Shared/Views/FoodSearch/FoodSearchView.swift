//
//  FoodSearchView.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import SwiftUI
import SwiftData

#if os(iOS)
/// Wrapper fuer ein aufgenommenes Foto (Identifiable fuer .sheet(item:))
private struct SearchCapturedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}
#endif

/// Hauptansicht fuer die Lebensmittelsuche
struct FoodSearchView: View {
    /// Tab-Auswahl: Suche oder Favoriten
    private enum SearchTab: Int {
        case search, favorites
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var selectedDate: Date = Date()
    var selectedMealType: MealType = .snack
    /// Explizit gewaehlte Rubrik (contextMeal) — uebersteuert beim Planen die
    /// automatisch bestimmte naechste Hauptmahlzeit. `nil`, wenn
    /// `selectedMealType` nur aus der Uhrzeit abgeleitet wurde.
    var plannedMealOverride: MealType? = nil

    @State private var viewModel: FoodSearchViewModel?
    @State private var selectedFood: FoodItem?
    @State private var sheetFood: FoodItem?
    @State private var showQuickEntry = false
    @State private var selectedTab: SearchTab = .search
    #if os(iOS)
    @State private var showBarcodeScanner = false
    @State private var pendingBarcode: String?
    @State private var showAICamera = false
    @State private var pendingAIImage: UIImage?
    @State private var aiCapturedPhoto: SearchCapturedPhoto?
    @State private var showAIQuickEntry = false
    #endif
    #if os(macOS)
    @State private var showMacAIPicker = false
    @State private var showAIQuickEntry = false
    #endif

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactLayout
            } else {
                regularLayout
            }
        }
        .navigationTitle("sidebar_food_search")
        .searchable(
            text: Binding(
                get: { viewModel?.searchText ?? "" },
                set: { viewModel?.searchText = $0 }
            ),
            prompt: "search_food_placeholder"
        )
        .onChange(of: viewModel?.searchText) { _, _ in
            if selectedTab == .search {
                viewModel?.search()
            } else {
                viewModel?.searchFavorites(query: viewModel?.searchText ?? "")
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .favorites {
                viewModel?.loadFavorites()
                viewModel?.searchFavorites(query: viewModel?.searchText ?? "")
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = FoodSearchViewModel(modelContext: modelContext)
            }
        }
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showBarcodeScanner = true
                } label: {
                    Label("barcode_scanner_title", systemImage: "barcode.viewfinder")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    pendingAIImage = nil
                    aiCapturedPhoto = nil
                    showAICamera = true
                } label: {
                    Label("ai_camera_title", systemImage: "wand.and.stars")
                }
            }
            #endif
            #if os(macOS)
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAIQuickEntry = true
                } label: {
                    Label("ai_quick_entry_title", systemImage: "sparkles")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showMacAIPicker = true
                } label: {
                    Label("ai_camera_title", systemImage: "wand.and.stars")
                }
            }
            #endif
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if KeychainHelper.hasAPIKey {
                        showAIQuickEntry = true
                    } else {
                        showQuickEntry = true
                    }
                } label: {
                    Label(
                        KeychainHelper.hasAPIKey ? "ai_quick_entry_title" : "quick_entry_title",
                        systemImage: KeychainHelper.hasAPIKey ? "sparkles" : "bolt.fill"
                    )
                }
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showAIQuickEntry) {
            NavigationStack {
                AIQuickEntryView(selectedDate: selectedDate, initialMealType: selectedMealType) {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showBarcodeScanner, onDismiss: {
            if let barcode = pendingBarcode {
                pendingBarcode = nil
                Task {
                    let searchVM = viewModel ?? FoodSearchViewModel(modelContext: modelContext)
                    if let food = await searchVM.lookupBarcode(barcode) {
                        sheetFood = food
                    }
                }
            }
        }) {
            NavigationStack {
                BarcodeScannerView { barcode in
                    pendingBarcode = barcode
                }
            }
        }
        .sheet(isPresented: $showAICamera, onDismiss: {
            if let image = pendingAIImage {
                pendingAIImage = nil
                aiCapturedPhoto = SearchCapturedPhoto(image: image)
            }
        }) {
            NavigationStack {
                AIFoodCameraView { image in
                    pendingAIImage = image
                    showAICamera = false
                }
            }
        }
        .sheet(item: $aiCapturedPhoto) { captured in
            NavigationStack {
                AIFoodResultView(
                    capturedImage: captured.image,
                    selectedDate: selectedDate,
                    selectedMealType: selectedMealType
                ) {
                    dismiss()
                }
            }
        }
        #endif
        #if os(macOS)
        .sheet(isPresented: $showAIQuickEntry) {
            NavigationStack {
                AIQuickEntryView(selectedDate: selectedDate, initialMealType: selectedMealType) {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showMacAIPicker) {
            NavigationStack {
                MacAIFoodPickerView(
                    selectedDate: selectedDate,
                    selectedMealType: selectedMealType
                ) {
                    dismiss()
                }
            }
        }
        #endif
        .sheet(item: $sheetFood) { food in
            NavigationStack {
                FoodAddView(
                    foodItem: food,
                    selectedDate: selectedDate,
                    selectedMealType: selectedMealType,
                    editingEntry: nil,
                    onAdd: { grams, _ in
                        viewModel?.addDiaryEntry(
                            foodItem: food,
                            date: selectedDate,
                            mealType: selectedMealType,
                            amountGrams: grams
                        )
                        dismiss()
                    },
                    onPlan: { grams, meal in
                        viewModel?.addPlannedEntry(
                            foodItem: food,
                            date: selectedDate,
                            mealType: meal,
                            amountGrams: grams
                        )
                        dismiss()
                    },
                    planTarget: plannedMealOverride ?? MealType.planningTargetBasedOnTime
                )
            }
        }
        .sheet(isPresented: $showQuickEntry) {
            NavigationStack {
                QuickEntryView(
                    selectedDate: selectedDate,
                    selectedMealType: selectedMealType
                ) {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Tab-Picker

    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            Text("search_tab_search").tag(SearchTab.search)
            Text("search_tab_favorites").tag(SearchTab.favorites)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    // MARK: - iPhone: Vollbild-Liste

    private var compactLayout: some View {
        VStack(spacing: 0) {
            tabPicker
            List {
                if selectedTab == .search {
                    offlineSection
                    localSection
                    onlineSection
                } else {
                    favoritesContent
                }
            }
        }
    }

    // MARK: - iPad/Mac: Split mit Detail

    private var regularLayout: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                tabPicker
                List {
                    if selectedTab == .search {
                        offlineSection
                        localSection
                        onlineSection
                    } else {
                        favoritesContent
                    }
                }
            }
            .frame(minWidth: 300)

            Divider()

            // Detail-Panel mit Hinzufuegen-Button
            if let food = selectedFood {
                VStack(spacing: 0) {
                    FoodDetailPanel(foodItem: food)

                    Divider()

                    Button {
                        sheetFood = selectedFood
                    } label: {
                        Text("action_add_to_diary")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding()
                }
                .frame(minWidth: 300)
            } else {
                ContentUnavailableView {
                    Label("select_food", systemImage: "fork.knife")
                } description: {
                    Text("select_food_description")
                }
                .frame(minWidth: 300)
            }
        }
    }

    // MARK: - Sektionen

    @ViewBuilder
    private var offlineSection: some View {
        let results = viewModel?.offlineResults ?? []
        if !results.isEmpty {
            Section("search_section_offline") {
                ForEach(results) { product in
                    FoodSearchResultRow(
                        name: product.name,
                        brand: product.brand,
                        caloriesPer100g: product.caloriesPer100g,
                        isLocal: false,
                        fatPer100g: product.fatPer100g,
                        saturatedFatPer100g: product.saturatedFatPer100g,
                        sugarPer100g: product.sugarPer100g,
                        saltPer100g: product.saltPer100g
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let food = product.toFoodItem()
                        modelContext.insert(food)
                        try? modelContext.save()
                        selectedFood = food
                        if horizontalSizeClass == .compact {
                            sheetFood = food
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var localSection: some View {
        let results = viewModel?.localResults ?? []
        if !results.isEmpty {
            Section("search_local_results") {
                ForEach(results, id: \.itemId) { food in
                    FoodSearchResultRow(
                        name: food.name,
                        brand: food.brand,
                        caloriesPer100g: food.caloriesPer100g,
                        isLocal: true,
                        fatPer100g: food.fatPer100g,
                        saturatedFatPer100g: food.saturatedFatPer100g,
                        sugarPer100g: food.sugarPer100g,
                        saltPer100g: food.saltPer100g
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedFood = food
                        if horizontalSizeClass == .compact {
                            sheetFood = food
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var onlineSection: some View {
        let results = viewModel?.onlineResults ?? []
        let isLoading = viewModel?.isLoading ?? false

        Section("search_online_results") {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }

            ForEach(results) { product in
                FoodSearchResultRow(
                    name: product.productName ?? "—",
                    brand: product.brands,
                    caloriesPer100g: product.nutriments?.energyKcal100g ?? 0,
                    isLocal: false,
                    fatPer100g: product.nutriments?.fat100g ?? 0,
                    saturatedFatPer100g: product.nutriments?.saturatedFat100g ?? 0,
                    sugarPer100g: product.nutriments?.sugars100g ?? 0,
                    saltPer100g: product.nutriments?.salt100g ?? 0
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    Task {
                        if let vm = viewModel {
                            let food = await vm.saveProduct(product)
                            selectedFood = food
                            if horizontalSizeClass == .compact {
                                sheetFood = food
                            }
                        }
                    }
                }
            }

            if let error = viewModel?.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }

    // MARK: - Favoriten

    @ViewBuilder
    private var favoritesContent: some View {
        let results = viewModel?.filteredFavorites ?? []
        if results.isEmpty {
            ContentUnavailableView {
                Label("no_favorites_title", systemImage: "heart")
            } description: {
                Text("no_favorites_description")
            }
        } else {
            ForEach(results, id: \.itemId) { food in
                FoodSearchResultRow(
                    name: food.name,
                    brand: food.brand,
                    caloriesPer100g: food.caloriesPer100g,
                    isLocal: true,
                    fatPer100g: food.fatPer100g,
                    saturatedFatPer100g: food.saturatedFatPer100g,
                    sugarPer100g: food.sugarPer100g,
                    saltPer100g: food.saltPer100g
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedFood = food
                    if horizontalSizeClass == .compact {
                        sheetFood = food
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        FoodSearchView()
    }
    .modelContainer(PreviewSampleData.container)
}
