//
//  FoodSearchViewModel.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import SwiftUI
import SwiftData

/// ViewModel fuer die kombinierte Lebensmittelsuche (Offline-DB + lokal + OpenFoodFacts)
@Observable
final class FoodSearchViewModel {
    private let modelContext: ModelContext
    private let offService = OpenFoodFactsService.shared
    private let offlineDB = OfflineDatabaseService.shared

    /// Suchtext
    var searchText: String = ""

    /// Offline-Suchergebnisse (aus lokaler OFF-Datenbank)
    var offlineResults: [OfflineProduct] = []

    /// Lokale Suchergebnisse (aus SwiftData — eigene Lebensmittel)
    var localResults: [FoodItem] = []

    /// Online-Suchergebnisse (aus OpenFoodFacts API)
    var onlineResults: [OFFProduct] = []

    /// Ladezustand
    var isLoading = false

    /// Fehlermeldung
    var errorMessage: String?

    /// Favorisierte Lebensmittel
    var favoriteItems: [FoodItem] = []

    /// Gefilterte Favoriten (nach Suchtext)
    var filteredFavorites: [FoodItem] = []

    /// Debounce-Task
    private var searchTask: Task<Void, Never>?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Startet die 3-Tier Suche: Offline-DB → SwiftData → Online-API
    func search() {
        searchTask?.cancel()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            offlineResults = []
            localResults = []
            onlineResults = []
            return
        }

        searchTask = Task { @MainActor in
            // 1. Sofort: Offline-Datenbank durchsuchen
            await searchOffline(query: query)

            // 2. Sofort: Lokale SwiftData-Suche
            searchLocal(query: query)

            // 3. Debounce fuer Online-Suche (500ms) — nur wenn wenige lokale Treffer
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            if offlineResults.count + localResults.count < 5 {
                await searchOnline(query: query)
            }
        }
    }

    /// Offline-Suche in der lokalen OFF-Datenbank
    private func searchOffline(query: String) async {
        do {
            try await offlineDB.open()
            offlineResults = await offlineDB.searchProducts(query: query)
        } catch {
            // Datenbank nicht vorhanden — kein Fehler anzeigen
            offlineResults = []
        }
    }

    /// Lokale Suche in SwiftData
    private func searchLocal(query: String) {
        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate<FoodItem> { food in
                food.name.localizedStandardContains(query)
                && food.isQuickEntry == false
            },
            sortBy: [SortDescriptor(\.name)]
        )
        localResults = (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Online-Suche ueber OpenFoodFacts
    private func searchOnline(query: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let products = try await offService.searchProducts(query: query)
            if !Task.isCancelled {
                onlineResults = products
            }
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    /// Laedt alle favorisierten Lebensmittel aus SwiftData
    func loadFavorites() {
        let descriptor = FetchDescriptor<FoodCustomization>(
            predicate: #Predicate<FoodCustomization> { $0.isFavorite == true }
        )
        let customizations = (try? modelContext.fetch(descriptor)) ?? []

        // Favorisierte FoodItems via Barcode oder foodItemId laden
        var items: [FoodItem] = []
        for cust in customizations {
            if let barcode = cust.barcode, !barcode.isEmpty {
                let bc = barcode
                let foodDescriptor = FetchDescriptor<FoodItem>(
                    predicate: #Predicate<FoodItem> { $0.barcode == bc }
                )
                if let food = try? modelContext.fetch(foodDescriptor).first {
                    items.append(food)
                    continue
                }
            }
            let fid = cust.foodItemId
            if !fid.isEmpty {
                let foodDescriptor = FetchDescriptor<FoodItem>(
                    predicate: #Predicate<FoodItem> { $0.itemId == fid }
                )
                if let food = try? modelContext.fetch(foodDescriptor).first {
                    items.append(food)
                }
            }
        }

        favoriteItems = items.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        filteredFavorites = favoriteItems
    }

    /// Filtert die geladenen Favoriten nach Name
    func searchFavorites(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            filteredFavorites = favoriteItems
            return
        }
        filteredFavorites = favoriteItems.filter {
            $0.name.localizedStandardContains(trimmed)
        }
    }

    /// Barcode-Lookup (Offline-DB zuerst, dann Online-API)
    func lookupBarcode(_ barcode: String) async -> FoodItem? {
        isLoading = true
        defer { isLoading = false }

        // 1. Zuerst Offline-Datenbank pruefen
        do {
            try await offlineDB.open()
            if let offlineProduct = await offlineDB.lookupBarcode(barcode) {
                return offlineProduct.toFoodItem()
            }
        } catch {
            // Offline-DB nicht verfuegbar — weiter mit Online
        }

        // 2. Fallback: Online-API
        do {
            if let product = try await offService.lookupBarcode(barcode) {
                let foodItem = await offService.createFoodItem(from: product)
                return foodItem
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        return nil
    }

    /// Speichert ein OFF-Produkt lokal und gibt das FoodItem zurueck
    func saveProduct(_ product: OFFProduct) async -> FoodItem {
        let foodItem = await offService.createFoodItem(from: product)
        modelContext.insert(foodItem)
        try? modelContext.save()
        return foodItem
    }

    /// Erstellt einen DiaryEntry fuer ein FoodItem
    func addDiaryEntry(
        foodItem: FoodItem,
        date: Date,
        mealType: MealType,
        amountGrams: Double
    ) {
        let entry = DiaryEntry(
            date: date,
            mealType: mealType,
            amountGrams: amountGrams,
            foodItem: foodItem
        )
        modelContext.insert(entry)
        try? modelContext.save()
    }

    /// Legt einen geplanten Eintrag an — die Ein-Plan-Invariante setzt
    /// `PlannedEntry.setPlan` am Modell durch.
    func addPlannedEntry(
        foodItem: FoodItem,
        date: Date,
        mealType: MealType,
        amountGrams: Double
    ) {
        PlannedEntry.setPlan(
            foodItem: foodItem,
            date: date,
            mealType: mealType,
            amountGrams: amountGrams,
            in: modelContext
        )
        try? modelContext.save()
    }
}
