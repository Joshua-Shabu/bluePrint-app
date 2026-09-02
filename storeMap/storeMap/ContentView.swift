//
//  ContentView.swift
//  storeMap
//
//  Created by Joshua Shabu on 8/25/26.
//

import SwiftUI

// MARK: - Models

struct Store: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let address: String
    let systemImage: String
    var footprint: AnyShape = AnyShape(LShapedFootprint())
    var pins: [Pin] = fixedLayoutPins
    // Multi-floor locations (e.g. Jefferson Market Library) list their floors
    // here; single-floor locations (e.g. Starbucks) leave this empty and the
    // layout screen falls back to `pins` above with no floor switcher shown.
    var floors: [StoreFloor] = []

    static func == (lhs: Store, rhs: Store) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct StoreFloor: Identifiable {
    let id = UUID()
    var name: String
    var pins: [Pin]
    // Unmapped floors render the same footprint dimmed with only a stairs
    // pin (back to the mapped floor) and a "not yet mapped" overlay.
    var isMapped: Bool = true
}

enum PinKind {
    case entrance
    case fixed
    case custom
    case stairs
}

struct Pin: Identifiable {
    let id = UUID()
    var label: String
    var systemImage: String
    var xFraction: CGFloat
    var yFraction: CGFloat
    var kind: PinKind = .fixed
    var color: Color = .accentColor
    // Nudges just the label away from the pin dot, for cases where two pins
    // sit close enough together that their labels would otherwise overlap.
    // The dot itself still renders at (xFraction, yFraction).
    var labelOffset: CGSize = .zero
}

// Warm, coffee-shop brand palette shared by the opening screen and the
// call-to-action button.
let brandColor = Color(red: 0.0, green: 0.39, blue: 0.25)

// Blueprint-style fill/border/grid for the store footprint.
let blueprintFillColor = Color(red: 0.74, green: 0.84, blue: 0.96)
let blueprintBorderColor = Color(red: 0.05, green: 0.14, blue: 0.35)
let blueprintGridColor = Color(red: 0.62, green: 0.77, blue: 0.94)
// The rest of the screen: a lighter fill with a thinner, more muted grid so
// the whole screen reads as one continuous blueprint sheet while the
// footprint (darker fill, denser grid) still stands out inside it.
let blueprintScreenBackground = Color(red: 0.93, green: 0.95, blue: 0.98)
let blueprintScreenGridColor = Color(red: 0.86, green: 0.90, blue: 0.95)

// Muted gray-blue fill/border/grid used for a floor that hasn't been mapped
// yet, plus the extra opacity reduction applied to the whole layer.
let blueprintDimmedFillColor = Color(red: 0.76, green: 0.78, blue: 0.82)
let blueprintDimmedBorderColor = Color(red: 0.40, green: 0.43, blue: 0.47)
let blueprintDimmedGridColor = Color(red: 0.68, green: 0.71, blue: 0.75)
let unmappedFloorOpacity: Double = 0.5

// The default store footprint is an L-shaped polygon (see LShapedFootprint).
// The entrance sits on the bottom "street" wall; every other fixed pin is
// positioned relative to it (counter just past the door, exit near the
// front, bin mid-store, restroom tucked in the back corner).
let entranceFraction = CGPoint(x: 0.5, y: 0.9)

let fixedLayoutPins: [Pin] = [
    Pin(label: "Entrance", systemImage: "door.right.hand.open", xFraction: entranceFraction.x, yFraction: entranceFraction.y, kind: .entrance, color: .green),
    Pin(label: "Counter", systemImage: "cup.and.saucer.fill", xFraction: 0.5, yFraction: 0.78, kind: .fixed, color: Color(red: 0.55, green: 0.35, blue: 0.16)),
    Pin(label: "Exit", systemImage: "door.left.hand.open", xFraction: 0.75, yFraction: 0.85, kind: .fixed, color: .red),
    Pin(label: "Bin", systemImage: "trash.fill", xFraction: 0.3, yFraction: 0.55, kind: .fixed, color: .gray),
    Pin(label: "Restroom", systemImage: "toilet.fill", xFraction: 0.25, yFraction: 0.2, kind: .fixed, color: .blue)
]

// Pin layout for the Jefferson Market Library preview: entrance at the
// bottom point of the footprint, librarian desk and work room in the
// waist, meeting/reading rooms in the wider facade up top, restroom near
// the hallway transition where the facade narrows into the waist, and
// the Monumental Stair right next to the entrance as in the real
// blueprint. The stair and entrance pins sit close together, so their
// labels are nudged apart (labelOffset) to avoid overlapping.
let jeffersonMarketLibraryPins: [Pin] = [
    Pin(label: "Meeting Room", systemImage: "person.3.fill", xFraction: 0.30, yFraction: 0.20, kind: .fixed, color: .indigo),
    Pin(label: "Children's Reading Room", systemImage: "book.fill", xFraction: 0.65, yFraction: 0.22, kind: .fixed, color: .orange),
    Pin(label: "Restroom", systemImage: "toilet.fill", xFraction: 0.62, yFraction: 0.45, kind: .fixed, color: .blue),
    Pin(label: "Work Room", systemImage: "briefcase.fill", xFraction: 0.55, yFraction: 0.65, kind: .fixed, color: .brown),
    Pin(label: "Librarian Desk", systemImage: "info.circle.fill", xFraction: 0.48, yFraction: 0.75, kind: .fixed, color: .teal),
    Pin(label: "Entrance / Vestibule", systemImage: "door.right.hand.open", xFraction: 0.50, yFraction: 0.90, kind: .entrance, color: .green, labelOffset: CGSize(width: 38, height: 0)),
    Pin(label: "Monumental Stair", systemImage: "figure.stairs", xFraction: 0.38, yFraction: 0.88, kind: .stairs, color: .cyan, labelOffset: CGSize(width: -34, height: 0))
]

// L-shaped store footprint, expressed as fractions of the available
// canvas so it scales the same way the pins do. This is the default shape
// used by any Store that doesn't specify its own footprint (e.g. a
// real-world place detected via the Places API, whose actual floor plan
// we don't know).
struct LShapedFootprint: Shape {
    static let unitPoints: [CGPoint] = [
        CGPoint(x: 0.1, y: 0.9),
        CGPoint(x: 0.1, y: 0.1),
        CGPoint(x: 0.55, y: 0.1),
        CGPoint(x: 0.55, y: 0.45),
        CGPoint(x: 0.9, y: 0.45),
        CGPoint(x: 0.9, y: 0.9)
    ]

    func path(in rect: CGRect) -> Path {
        let points = Self.unitPoints.map {
            CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
        }
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

// Arbitrary building outline traced by a Blueprint Contributor submission —
// an ordered list of unit points (0-1, same convention as every other
// footprint here), rather than a fixed shape like LShapedFootprint.
struct PolygonFootprint: Shape {
    var unitPoints: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard unitPoints.count >= 3 else { return path }
        let points = unitPoints.map {
            CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
        }
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

// Jefferson Market Library's Floor 1 footprint: a wide, rounded facade at
// the top narrowing through a waist down to a point at the entrance,
// modeled after the building's distinctive silhouette. Expressed as
// fractions of the available canvas, same convention as LShapedFootprint.
struct JeffersonMarketLibraryFootprint: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + fx * rect.width, y: rect.minY + fy * rect.height)
        }

        var path = Path()
        path.move(to: point(0.12, 0.25))
        path.addQuadCurve(to: point(0.88, 0.25), control: point(0.5, 0.05))
        path.addLine(to: point(0.60, 0.55))
        path.addLine(to: point(0.50, 0.90))
        path.addLine(to: point(0.40, 0.55))
        path.addLine(to: point(0.12, 0.25))
        path.closeSubpath()
        return path
    }
}

// Upper floors haven't been mapped yet: same footprint, dimmed, with
// only a stairs pin (in the same spot as Floor 1's Monumental Stair)
// linking back down.
let unmappedFloorStairsPin = Pin(label: "Stairs", systemImage: "figure.stairs", xFraction: 0.38, yFraction: 0.88, kind: .stairs, color: .cyan)

// Second hardcoded preview location: a curved, waisted building shape
// instead of the L-shaped one above, with a library-specific pin set and
// three floors (only Floor 1 is actually mapped out).
let jeffersonMarketLibrary = Store(
    name: "Jefferson Market Library",
    address: "425 6th Ave, New York, NY 10011",
    systemImage: "books.vertical.fill",
    footprint: AnyShape(JeffersonMarketLibraryFootprint()),
    pins: jeffersonMarketLibraryPins,
    floors: [
        StoreFloor(name: "Floor 1", pins: jeffersonMarketLibraryPins, isMapped: true),
        StoreFloor(name: "Floor 2", pins: [unmappedFloorStairsPin], isMapped: false),
        StoreFloor(name: "Floor 3", pins: [unmappedFloorStairsPin], isMapped: false)
    ]
)

// Original hardcoded preview location, kept around (alongside real GPS
// detection) so both layouts can be tested independently of location
// services or the Places API.
let starbucksReservePreview = Store(
    name: "Starbucks Reserve",
    address: "17th Ave, New York, NY 10011",
    systemImage: "cup.and.saucer.fill"
)

// Graph-paper style grid drawn across the whole canvas; clipped to the
// store's footprint shape so it only shows up inside the building outline.
struct GridPattern: Shape {
    var spacing: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = rect.minX
        while x <= rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += spacing
        }
        var y = rect.minY
        while y <= rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += spacing
        }
        return path
    }
}

// A simple peaked-roof house silhouette (body + roof, with a small eave
// overhang), expressed as fractions of the available canvas — matches the
// mark used on the app icon.
struct HouseSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + fx * rect.width, y: rect.minY + fy * rect.height)
        }
        var path = Path()
        path.move(to: point(0.20, 0.40))
        path.addLine(to: point(0.50, 0.20))
        path.addLine(to: point(0.80, 0.40))
        path.addLine(to: point(0.74, 0.40))
        path.addLine(to: point(0.74, 0.84))
        path.addLine(to: point(0.26, 0.84))
        path.addLine(to: point(0.26, 0.40))
        path.closeSubpath()
        return path
    }
}

// A map-pin teardrop, used sitting on the house's roof peak.
struct PinMark: Shape {
    func path(in rect: CGRect) -> Path {
        let centerX = rect.midX
        let circleCenterY = rect.minY + rect.height * 0.32
        let radius = rect.width * 0.32
        var path = Path()
        path.addArc(
            center: CGPoint(x: centerX, y: circleCenterY),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(360),
            clockwise: false
        )
        path.move(to: CGPoint(x: centerX - radius * 0.62, y: circleCenterY + radius * 0.62))
        path.addLine(to: CGPoint(x: centerX, y: rect.maxY))
        path.addLine(to: CGPoint(x: centerX + radius * 0.62, y: circleCenterY + radius * 0.62))
        path.closeSubpath()
        return path
    }
}

// Building logo mark for the opening screen: a house silhouette with two
// windows, a door, and a location pin sitting on the roof peak — drawn to
// echo the app icon.
struct BuildingLogoMark: View {
    var foreground: Color
    var background: Color

    var body: some View {
        GeometryReader { geometry in
            let s = min(geometry.size.width, geometry.size.height)

            ZStack {
                HouseSilhouette()
                    .fill(foreground)

                Rectangle()
                    .fill(background)
                    .frame(width: s * 0.09, height: s * 0.09)
                    .position(x: s * 0.378, y: s * 0.52)
                Rectangle()
                    .fill(background)
                    .frame(width: s * 0.09, height: s * 0.09)
                    .position(x: s * 0.622, y: s * 0.52)

                Rectangle()
                    .fill(background)
                    .frame(width: s * 0.16, height: s * 0.20)
                    .position(x: s * 0.5, y: s * 0.74)

                PinMark()
                    .fill(foreground)
                    .frame(width: s * 0.28, height: s * 0.28)
                    .position(x: s * 0.5, y: s * 0.115)
                Circle()
                    .fill(background)
                    .frame(width: s * 0.08, height: s * 0.08)
                    .position(x: s * 0.5, y: s * 0.065)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

extension Store {
    /// Builds a Store from a real contributor submission fetched from
    /// Firestore, rather than one of the hardcoded preview layouts. Falls
    /// back to the default L-shaped footprint if the submission's outline is
    /// somehow too short to draw (shouldn't happen — the web tool requires
    /// at least 3 points to close a shape — but better a generic layout than
    /// a blank floor).
    static func fromSubmission(_ submission: BlueprintSubmission, name: String, address: String) -> Store {
        let unitPoints = submission.outline.points.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
        let footprint: AnyShape = unitPoints.count >= 3
            ? AnyShape(PolygonFootprint(unitPoints: unitPoints))
            : AnyShape(LShapedFootprint())

        var pins: [Pin] = []
        if let entrance = submission.entrance {
            pins.append(Pin(
                label: "Entrance",
                systemImage: "door.right.hand.open",
                xFraction: CGFloat(entrance.x),
                yFraction: CGFloat(entrance.y),
                kind: .entrance,
                color: .green
            ))
        }
        for facility in submission.facilities {
            pins.append(Pin(
                label: facility.label,
                systemImage: Self.systemImage(forFacilityType: facility.type),
                xFraction: CGFloat(facility.x),
                yFraction: CGFloat(facility.y),
                kind: .fixed,
                color: Self.color(forFacilityType: facility.type)
            ))
        }

        return Store(
            name: name,
            address: address,
            systemImage: "storefront.fill",
            footprint: footprint,
            pins: pins
        )
    }

    private static func systemImage(forFacilityType type: String) -> String {
        switch type {
        case "counter": return "cup.and.saucer.fill"
        case "restroom": return "toilet.fill"
        case "bin": return "trash.fill"
        case "exit": return "door.left.hand.open"
        default: return "mappin.circle.fill"
        }
    }

    private static func color(forFacilityType type: String) -> Color {
        switch type {
        case "counter": return Color(red: 0.55, green: 0.35, blue: 0.16)
        case "restroom": return .blue
        case "bin": return .gray
        case "exit": return .red
        default: return .purple
        }
    }
}

// MARK: - Detecting Location

enum DetectionState {
    case loading
    case success(Store)
    case failure(String)
}

struct ContentView: View {
    @State private var detectionState: DetectionState = .loading
    @State private var selectedStore: Store?
    @State private var locationService = LocationService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                logoBadge

                Text("BLUEPRINT")
                    .font(.caption)
                    .fontWeight(.bold)
                    .kerning(2.5)
                    .foregroundStyle(.secondary)

                switch detectionState {
                case .loading:
                    VStack(spacing: 14) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: brandColor))
                            .controlSize(.large)
                        Text("Detecting your location...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)

                case .success(let store):
                    VStack(spacing: 24) {
                        VStack(spacing: 6) {
                            Text(store.name)
                                .font(.title.bold())
                                .multilineTextAlignment(.center)
                            Text(store.address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            selectedStore = store
                        } label: {
                            Text("Enter")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .background(brandColor)
                        .clipShape(Capsule())
                        .shadow(color: brandColor.opacity(0.35), radius: 12, y: 6)
                        .padding(.horizontal, 32)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                case .failure(let message):
                    VStack(spacing: 18) {
                        VStack(spacing: 6) {
                            Image(systemName: "location.slash.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }

                        Button {
                            Task { await detectLocation() }
                        } label: {
                            Text("Retry")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .background(brandColor)
                        .clipShape(Capsule())
                        .shadow(color: brandColor.opacity(0.35), radius: 12, y: 6)
                        .padding(.horizontal, 32)
                    }
                    .transition(.opacity)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationDestination(item: $selectedStore) { store in
                StoreLayoutView(store: store)
            }
            .task {
                if ProcessInfo.processInfo.arguments.contains("-PreviewJefferson") {
                    selectedStore = jeffersonMarketLibrary
                } else if ProcessInfo.processInfo.arguments.contains("-PreviewStarbucks") {
                    selectedStore = starbucksReservePreview
                } else {
                    await detectLocation()
                }
            }
        }
    }

    private func detectLocation() async {
        withAnimation(.easeOut(duration: 0.3)) {
            detectionState = .loading
        }
        do {
            let coordinate = try await locationService.requestCurrentLocation()
            let store = try await PlacesService.nearestPlace(to: coordinate)
            withAnimation(.easeOut(duration: 0.45)) {
                detectionState = .success(store)
            }
        } catch {
            withAnimation(.easeOut(duration: 0.3)) {
                detectionState = .failure(errorMessage(for: error))
            }
        }
    }

    private func errorMessage(for error: Error) -> String {
        switch error {
        case LocationError.permissionDenied:
            return "Location access was denied. Enable it in Settings to detect nearby stores."
        case LocationError.permissionRestricted:
            return "Location access is restricted on this device."
        case PlacesError.noResults:
            return "No supported location found nearby."
        default:
            return "Something went wrong while detecting your location. Please try again."
        }
    }

    private var logoBadge: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white)
            .frame(width: 84, height: 84)
            .overlay(
                BuildingLogoMark(foreground: blueprintBorderColor, background: .white)
                    .frame(width: 50, height: 50)
            )
            .shadow(color: blueprintBorderColor.opacity(0.25), radius: 12, y: 6)
    }
}

// MARK: - Store Layout

struct StoreLayoutView: View {
    let store: Store

    @State private var customPins: [Pin] = []
    @State private var isAddingPin = false
    @State private var pendingTapLocation: CGPoint?
    @State private var pendingCanvasSize: CGSize = .zero
    @State private var showingLabelPrompt = false
    @State private var newPinLabel = ""
    @State private var selectedFloorIndex = 0

    private var hasMultipleFloors: Bool { store.floors.count > 1 }
    private var currentFloor: StoreFloor? {
        hasMultipleFloors ? store.floors[selectedFloorIndex] : nil
    }
    private var currentPins: [Pin] { currentFloor?.pins ?? store.pins }
    private var isCurrentFloorMapped: Bool { currentFloor?.isMapped ?? true }
    private var mappedFloorIndex: Int {
        store.floors.firstIndex(where: { $0.isMapped }) ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            if hasMultipleFloors {
                Picker("Floor", selection: $selectedFloorIndex) {
                    ForEach(Array(store.floors.enumerated()), id: \.offset) { index, floor in
                        Text(floor.name).tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, isAddingPin ? 0 : 12)
                .onChange(of: selectedFloorIndex) {
                    isAddingPin = false
                }
            }

            if isAddingPin {
                Text("Tap anywhere on the layout to drop a pin")
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
            }

            GeometryReader { geometry in
                ZStack {
                    Group {
                        store.footprint
                            .fill(isCurrentFloorMapped ? blueprintFillColor : blueprintDimmedFillColor)
                            .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                        GridPattern()
                            .stroke(isCurrentFloorMapped ? blueprintGridColor : blueprintDimmedGridColor, lineWidth: 0.75)
                            .clipShape(store.footprint)
                        store.footprint
                            .stroke(isCurrentFloorMapped ? blueprintBorderColor : blueprintDimmedBorderColor, lineWidth: 3)
                    }
                    .opacity(isCurrentFloorMapped ? 1 : unmappedFloorOpacity)

                    ForEach(currentPins) { pin in
                        pinView(pin, in: geometry.size)
                    }

                    if isCurrentFloorMapped {
                        ForEach(customPins) { pin in
                            pinView(pin, in: geometry.size)
                        }
                    }

                    if !isCurrentFloorMapped {
                        unmappedFloorLabel
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    isAddingPin && isCurrentFloorMapped ?
                    SpatialTapGesture().onEnded { value in
                        pendingTapLocation = value.location
                        pendingCanvasSize = geometry.size
                        newPinLabel = ""
                        showingLabelPrompt = true
                        isAddingPin = false
                    } : nil
                )
            }
            .padding()
        }
        .background(
            ZStack {
                blueprintScreenBackground
                GridPattern(spacing: 18)
                    .stroke(blueprintScreenGridColor, lineWidth: 0.5)
            }
            .ignoresSafeArea()
        )
        .navigationTitle(store.name)
        .toolbar {
            if isCurrentFloorMapped {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingPin.toggle()
                    } label: {
                        Label("Add Pin", systemImage: "mappin.and.ellipse")
                    }
                }
            }
        }
        .alert("Label this pin", isPresented: $showingLabelPrompt) {
            TextField("Pin label", text: $newPinLabel)
            Button("Cancel", role: .cancel) {
                pendingTapLocation = nil
            }
            Button("Add") {
                addPendingPin()
            }
        }
    }

    private var unmappedFloorLabel: some View {
        Text("Layout not yet mapped")
            .font(.subheadline.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(.systemBackground).opacity(0.9))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
    }

    private func addPendingPin() {
        guard let location = pendingTapLocation, pendingCanvasSize.width > 0, pendingCanvasSize.height > 0 else { return }
        let label = newPinLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let pin = Pin(
            label: label.isEmpty ? "Pin" : label,
            systemImage: "mappin.circle.fill",
            xFraction: location.x / pendingCanvasSize.width,
            yFraction: location.y / pendingCanvasSize.height,
            kind: .custom,
            color: .purple
        )
        customPins.append(pin)
        pendingTapLocation = nil
    }

    @ViewBuilder
    private func pinView(_ pin: Pin, in size: CGSize) -> some View {
        let isEntrance = pin.kind == .entrance
        VStack(spacing: 3) {
            Image(systemName: pin.systemImage)
                .font(isEntrance ? .title : .title2)
                .foregroundStyle(pin.color)
                .padding(isEntrance ? 8 : 6)
                .background(
                    Circle()
                        .fill(Color(.systemBackground))
                        .overlay(Circle().stroke(pin.color, lineWidth: isEntrance ? 2.5 : 1.5))
                )
                .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
            Text(pin.label)
                .font(.caption2)
                .fontWeight(isEntrance ? .bold : .medium)
                .foregroundStyle(isEntrance ? pin.color : .primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.systemBackground).opacity(0.9))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
                .fixedSize()
                .offset(pin.labelOffset)
        }
        .position(x: pin.xFraction * size.width, y: pin.yFraction * size.height)
        .onTapGesture {
            guard pin.kind == .stairs, !isCurrentFloorMapped else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                selectedFloorIndex = mappedFloorIndex
            }
        }
    }
}

#Preview {
    ContentView()
}
