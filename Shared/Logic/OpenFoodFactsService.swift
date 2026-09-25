//
//  OpenFoodFactsService.swift
//  KalorienKompass
//
//  Erstellt von André Claaßen am 04.02.26.
//

import Foundation

/// Actor-basierter Client fuer die OpenFoodFacts API
actor OpenFoodFactsService {
    static let shared = OpenFoodFactsService()

    private let baseURL = "https://world.openfoodfacts.org"
    private let searchBaseURL = "https://search.openfoodfacts.org"
    private let session: URLSession
    private var cache: [String: OFFProduct] = [:]

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.httpAdditionalHeaders = [
            "User-Agent": "KalorienKompass/1.0 (iOS; contact: andre@claassen.net)"
        ]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Textsuche

    /// Sucht Produkte per Freitext ueber die Search-a-licious-API.
    ///
    /// Die fruehere Legacy-Suche (`cgi/search.pl`) lieferte sporadisch 503 und
    /// brauchte bei nicht gecachten Begriffen teils laenger als der
    /// URLSession-Timeout — beides erschien dem Nutzer als „Serverfehler"
    /// (Issue #100). Die neue API antwortet in Sekundenbruchteilen.
    func searchProducts(query: String, page: Int = 1, pageSize: Int = 20) async throws -> [OFFProduct] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        // Produktnamen in der Geraetesprache bevorzugen (Legacy lieferte gemischt)
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        let urlString = "\(searchBaseURL)/search?q=\(encodedQuery)&langs=\(lang)&page=\(page)&page_size=\(pageSize)&fields=code,product_name,brands,nutriments,serving_size,image_front_small_url"

        guard let url = URL(string: urlString) else {
            throw OpenFoodFactsError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenFoodFactsError.serverError
        }
        switch httpResponse.statusCode {
        case 200: break
        case 429: throw OpenFoodFactsError.rateLimited
        case 500...: throw OpenFoodFactsError.serviceUnavailable
        default: throw OpenFoodFactsError.serverError
        }

        let searchResult = try JSONDecoder().decode(OFFSearchResponse.self, from: data)
        let products = (searchResult.hits ?? []).map(\.asProduct)

        // Cache aktualisieren
        for product in products {
            if let code = product.code {
                cache[code] = product
            }
        }

        return products
    }

    // MARK: - Barcode-Lookup

    /// Sucht ein Produkt per Barcode (EAN/UPC)
    func lookupBarcode(_ barcode: String) async throws -> OFFProduct? {
        // Zuerst im Cache suchen
        if let cached = cache[barcode] {
            return cached
        }

        let urlString = "\(baseURL)/api/v2/product/\(barcode)?fields=code,product_name,brands,nutriments,serving_size,image_front_small_url"
        guard let url = URL(string: urlString) else {
            throw OpenFoodFactsError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OpenFoodFactsError.serverError
        }

        let result = try JSONDecoder().decode(OFFProductResponse.self, from: data)

        if let product = result.product {
            cache[barcode] = product
            return product
        }

        return nil
    }

    /// Konvertiert ein OFF-Produkt in ein lokales FoodItem
    func createFoodItem(from product: OFFProduct) -> FoodItem {
        let nutriments = product.nutriments ?? OFFNutriments()

        let food = FoodItem(
            name: product.productName ?? "Unbekannt",
            brand: product.brands,
            barcode: product.code,
            caloriesPer100g: nutriments.energyKcal100g ?? 0,
            proteinPer100g: nutriments.proteins100g ?? 0,
            carbsPer100g: nutriments.carbohydrates100g ?? 0,
            fatPer100g: nutriments.fat100g ?? 0,
            fiberPer100g: nutriments.fiber100g ?? 0,
            sugarPer100g: nutriments.sugars100g ?? 0,
            saturatedFatPer100g: nutriments.saturatedFat100g ?? 0,
            saltPer100g: nutriments.salt100g ?? 0
        )
        food.imageURL = product.imageFrontSmallURL
        food.lastFetched = Date()
        food.isUserCreated = false

        // Portionsgroesse parsen
        if let serving = product.servingSize {
            food.servingDescription = serving
            if let grams = ServingSizeParser.parseGrams(from: serving) {
                food.defaultServingSizeGrams = grams
            }
        }

        return food
    }

}

// MARK: - Fehler

enum OpenFoodFactsError: Error, LocalizedError {
    case invalidURL
    case serverError
    case rateLimited
    case serviceUnavailable
    case productNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL: String(localized: "error_invalid_url")
        case .serverError: String(localized: "error_server")
        case .rateLimited: String(localized: "error_rate_limited")
        case .serviceUnavailable: String(localized: "error_service_unavailable")
        case .productNotFound: String(localized: "error_product_not_found")
        }
    }
}

// MARK: - API-Datenstrukturen

nonisolated struct OFFSearchResponse: Codable, Sendable {
    let hits: [OFFSearchHit]?
}

/// Ein Treffer der Search-a-licious-API. Unterscheidet sich vom v2-Produkt:
/// `brands` ist dort ein Array statt eines kommagetrennten Strings.
nonisolated struct OFFSearchHit: Codable, Sendable {
    let code: String?
    let productName: String?
    let brands: [String]?
    let nutriments: OFFNutriments?
    let servingSize: String?
    let imageFrontSmallURL: String?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case nutriments
        case servingSize = "serving_size"
        case imageFrontSmallURL = "image_front_small_url"
    }

    /// Uebersetzt den Treffer in das vom Rest der App genutzte Produktformat.
    var asProduct: OFFProduct {
        let joinedBrands = (brands ?? [])
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        return OFFProduct(
            code: code,
            productName: productName,
            brands: joinedBrands.isEmpty ? nil : joinedBrands,
            nutriments: nutriments,
            servingSize: servingSize,
            imageFrontSmallURL: imageFrontSmallURL
        )
    }
}

nonisolated struct OFFProductResponse: Codable, Sendable {
    let status: Int?
    let product: OFFProduct?
}

nonisolated struct OFFProduct: Codable, Identifiable, Sendable {
    var id: String { code ?? UUID().uuidString }
    let code: String?
    let productName: String?
    let brands: String?
    let nutriments: OFFNutriments?
    let servingSize: String?
    let imageFrontSmallURL: String?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case nutriments
        case servingSize = "serving_size"
        case imageFrontSmallURL = "image_front_small_url"
    }
}

nonisolated struct OFFNutriments: Codable, Sendable {
    var energyKcal100g: Double?
    var proteins100g: Double?
    var carbohydrates100g: Double?
    var fat100g: Double?
    var fiber100g: Double?
    var sugars100g: Double?
    var saturatedFat100g: Double?
    var salt100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
        case fiber100g = "fiber_100g"
        case sugars100g = "sugars_100g"
        case saturatedFat100g = "saturated-fat_100g"
        case salt100g = "salt_100g"
    }
}
