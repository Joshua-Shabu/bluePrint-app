//
//  PlacesService.swift
//  storeMap
//

import CoreLocation
import Foundation

enum PlacesError: Error {
    case invalidResponse
    case httpError(Int)
    case noResults
    case decoding(Error)
    case network(Error)
}

/// Thin client for the Google Places API (New) Nearby Search endpoint.
enum PlacesService {
    private static let searchNearbyURL = URL(string: "https://places.googleapis.com/v1/places:searchNearby")!

    /// Place types (from Google's Places API "Table A" type list) that represent
    /// restaurants, cafes, retail stores, libraries, and similar venues a visitor
    /// would casually walk into. Deliberately excludes medical offices, dispensaries,
    /// adult venues, and other categories not meant for casual walk-in browsing.
    private static let includedTypes: [String] = [
        // Food & drink
        "restaurant", "cafe", "bakery", "bar", "meal_takeaway",
        // Retail
        "clothing_store", "shoe_store", "book_store", "electronics_store",
        "furniture_store", "hardware_store", "home_goods_store", "jewelry_store",
        "shopping_mall", "department_store", "pet_store", "florist",
        "bicycle_store", "sporting_goods_store", "convenience_store",
        "grocery_store", "supermarket", "liquor_store",
        // Public / cultural venues
        "library", "museum", "art_gallery", "movie_theater"
    ]

    static func nearestPlace(to coordinate: CLLocationCoordinate2D) async throws -> Store {
        var request = URLRequest(url: searchNearbyURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(APIConfig.googlePlacesAPIKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("places.id,places.displayName,places.formattedAddress,places.location", forHTTPHeaderField: "X-Goog-FieldMask")

        let body: [String: Any] = [
            "maxResultCount": 1,
            "rankPreference": "DISTANCE",
            "includedTypes": includedTypes,
            "locationRestriction": [
                "circle": [
                    "center": [
                        "latitude": coordinate.latitude,
                        "longitude": coordinate.longitude
                    ],
                    "radius": 1000.0
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw PlacesError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlacesError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw PlacesError.httpError(httpResponse.statusCode)
        }

        let decoded: NearbySearchResponse
        do {
            decoded = try JSONDecoder().decode(NearbySearchResponse.self, from: data)
        } catch {
            throw PlacesError.decoding(error)
        }

        guard let place = decoded.places?.first else {
            throw PlacesError.noResults
        }

        let name = place.displayName?.text ?? "Unnamed place"
        let address = place.formattedAddress ?? "Address unavailable"
        let placeCoordinate = place.location.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        } ?? coordinate

        // If a Blueprint contributor has already mapped this exact place and
        // it's been reviewed, show their real floor plan. Any failure here
        // (no data yet, a network hiccup, whatever) just falls through to the
        // generic placeholder layout below rather than failing detection.
        //
        // Two lookup passes: first by exact Place ID, then — since Google's
        // Autocomplete/Place Details endpoints (used by the web contributor
        // tool) and this Nearby Search endpoint occasionally resolve the same
        // physical business to two different Place IDs — by proximity to the
        // detected place's own coordinate.
        if let placeId = place.id,
           let submission = try? await FirestoreSubmissionService.verifiedSubmission(forPlaceId: placeId) {
            return Store.fromSubmission(submission, name: name, address: address)
        }
        if let submission = try? await FirestoreSubmissionService.verifiedSubmission(near: placeCoordinate) {
            return Store.fromSubmission(submission, name: name, address: address)
        }

        return Store(
            name: name,
            address: address,
            systemImage: "storefront.fill"
        )
    }
}

private struct NearbySearchResponse: Decodable {
    struct Place: Decodable {
        struct DisplayName: Decodable {
            let text: String
        }
        struct Location: Decodable {
            let latitude: Double
            let longitude: Double
        }
        let id: String?
        let displayName: DisplayName?
        let formattedAddress: String?
        let location: Location?
    }
    let places: [Place]?
}
