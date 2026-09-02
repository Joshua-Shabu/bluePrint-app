//
//  FirestoreSubmissionService.swift
//  storeMap
//
//  Fetches a contributor-submitted floor plan from Firestore for a given
//  Google Place ID, matching the schema produced by the Blueprint
//  Contributor web tool. Returns nil when nobody has mapped a place yet, or
//  when a submission exists but hasn't been reviewed — the caller falls
//  back to the generic placeholder layout in either case.
//

import CoreLocation
import FirebaseFirestore
import Foundation

struct BlueprintSubmission: Decodable {
    struct Place: Decodable {
        let google_place_id: String?
        let name: String?
        let address: String?
        let lat: Double?
        let lng: Double?
    }
    struct Point: Decodable {
        let x: Double
        let y: Double
    }
    struct Outline: Decodable {
        let points: [Point]
    }
    struct Facility: Decodable {
        let id: String
        let type: String
        let label: String
        let x: Double
        let y: Double
    }

    let place: Place
    let outline: Outline
    let entrance: Point?
    let facilities: [Facility]
    let status: String
}

enum FirestoreSubmissionService {
    private static var db: Firestore { Firestore.firestore() }

    /// Looks up a verified floor plan submission for a given Google Place ID.
    /// If more than one exists, this currently returns whichever one Firestore
    /// hands back first — once voting is wired up, this is the spot to sort by
    /// votes instead of just taking `limit(to: 1)`.
    static func verifiedSubmission(forPlaceId placeId: String) async throws -> BlueprintSubmission? {
        let snapshot = try await db.collection("submissions")
            .whereField("place.google_place_id", isEqualTo: placeId)
            .whereField("status", isEqualTo: "verified")
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first else { return nil }
        return try document.data(as: BlueprintSubmission.self)
    }

    /// Fallback for when the exact Google Place ID doesn't match anything —
    /// this happens in practice, because Google's Autocomplete/Place Details
    /// endpoints (used by the web contributor tool) and the Nearby Search
    /// endpoint (used here in the app) sometimes resolve the very same
    /// physical business to two different Place IDs, especially for smaller
    /// or newer listings Google hasn't fully deduplicated yet.
    ///
    /// Finds the closest verified submission within `maxDistanceMeters` of
    /// the given coordinate instead. This pulls every verified submission
    /// and measures distance client-side, which is fine at prototype scale
    /// (a handful of documents) but should move to a geohash-indexed query
    /// once there are enough submissions for that to matter.
    static func verifiedSubmission(near coordinate: CLLocationCoordinate2D, maxDistanceMeters: Double = 50) async throws -> BlueprintSubmission? {
        let snapshot = try await db.collection("submissions")
            .whereField("status", isEqualTo: "verified")
            .getDocuments()

        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        var closestMatch: (submission: BlueprintSubmission, distance: CLLocationDistance)?
        for document in snapshot.documents {
            guard let submission = try? document.data(as: BlueprintSubmission.self),
                  let lat = submission.place.lat,
                  let lng = submission.place.lng else { continue }

            let distance = target.distance(from: CLLocation(latitude: lat, longitude: lng))
            guard distance <= maxDistanceMeters else { continue }
            if closestMatch == nil || distance < closestMatch!.distance {
                closestMatch = (submission, distance)
            }
        }

        return closestMatch?.submission
    }
}
