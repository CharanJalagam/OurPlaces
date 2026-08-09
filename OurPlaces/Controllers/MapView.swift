//
//  MapView.swift
//  OurPlaces
//
//  Created by SAIRAM  on 03/01/26.
//

import SwiftUI
import MapKit

struct MapView: View {
    
    let allCategories: [PlaceCategory] = [
        PlaceCategory( title: "All",icon: "square.grid.2x2.fill"),
        PlaceCategory(title: "Cafe",icon: "cup.and.saucer.fill",),
        PlaceCategory(title: "Food",icon: "fork.knife",),
        PlaceCategory(title: "Historic",icon: "building.columns.fill",),
        PlaceCategory(title: "Nature",icon: "leaf.fill",),
        PlaceCategory(title: "Shopping",icon: "bag.fill",),
        PlaceCategory(title: "Religious",icon: "sparkles",),
        PlaceCategory(title: "Entertainment",icon: "theatermasks.fill",)
    ]
    @StateObject private var locationManager = LocationManager()
    @State private var selectedCategory: PlaceCategory = PlaceCategory(title: "All", icon: "square.grid.2x2.fill")
    @State private var selectedPlaceForDetails: Place?
    @State private var randomPlace: Place?
    @State private var isAddingPlace = false
    @State private var navigateToAddPlace = false
    @State private var newPlaceCoordinate: CLLocationCoordinate2D?
    @State private var isInAddFlow = false
    @State private var isNavigatingToDetails = false
    @State private var isNavigatingToRandomPlace = false
    let maxAltitude: Double = 200000

    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(
                latitude: 37.3349,
                longitude: -122.0090
            ),
            distance: 28000
        )
    )
    @State private var currentCamera: MapCamera?
    @State private var selectedPlace: Place?
    @State private var showCard = false
    @State private var isFirtTime = true
    @State private var showLoader = false
    @State private var vistitedPlacesID : [UUID] = []
    @State private var isMapMoving = false
    
    var filteredPlaces: [Place] {
        
        let categoryFiltered: [Place]
        
        if selectedCategory.title == "All" {
            categoryFiltered = places
        } else {
            categoryFiltered = places.filter {
                $0.category.lowercased() == selectedCategory.title.lowercased()
            }
        }
        
        if searchText.isEmpty {
            return categoryFiltered
        }
        
        return categoryFiltered.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
//    var filteredPlaces: [Place] {
//        
//        let baseFiltered: [Place]
//        
//        // Category filter
//        if selectedCategory.title == "All" {
//            baseFiltered = places
//        } else {
//            baseFiltered = places.filter {
//                $0.category.lowercased() == selectedCategory.title.lowercased()
//            }
//        }
//        
//        // Search filter
//        let searchFiltered: [Place]
//        if searchText.isEmpty {
//            searchFiltered = baseFiltered
//        } else {
//            searchFiltered = baseFiltered.filter {
//                $0.name.localizedCaseInsensitiveContains(searchText)
//            }
//        }
//        
//        // 🔥 NEW: Zoom-based filtering
//        guard let camera = currentCamera else { return searchFiltered }
//        
//        let zoom = camera.distance
//
//        let sorted = searchFiltered.sorted {
//            let score1 = vistitedPlacesID.contains($0.id) ? 1 : 0
//            let score2 = vistitedPlacesID.contains($1.id) ? 1 : 0
//            return score1 > score2
//        }
//
//        switch zoom {
//            
//        case 200_000...:
//            return Array(sorted.prefix(5))      // 🌍 world view
//            
//        case 120_000..<200_000:
//            return Array(sorted.prefix(10))     // 🌎 country
//            
//        case 80_000..<120_000:
//            return Array(sorted.prefix(20))     // 🏙️ state
//            
//        case 50_000..<80_000:
//            return Array(sorted.prefix(35))     // 🏘️ city
//            
//        case 30_000..<50_000:
//            return Array(sorted.prefix(60))     // 🧭 town
//            
//        case 15_000..<30_000:
//            return Array(sorted.prefix(100))    // 🏡 neighborhood
//            
//        default:
//            return sorted                      // 🔍 full detail
//        }
//    }

    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var placingAddress: String = ""
    @State private var placingName: String = ""
    @State private var visitedThumbnails: [UUID: String] = [:]
    @State private var clusters: [PlaceCluster] = []
    @AppStorage("userIndicatorEmoji") private var selectedEmoji: String = "🧍🏼‍♂️"
    private let emojiOptions = ["🧍🏼‍♂️", "🧍🏼‍♀️", "🚶‍♂️", "🏃‍♂️", "👫🏼", "🦖", "🚗", "🐥"]

    var supabaseVM = SupabaseAuthVM()
    
    @State private var places: [Place] = []
    var body: some View {
        NavigationStack {
            ZStack {
                
                Map(position: $cameraPosition) {
                    ForEach(clusters) { cluster in
                        Annotation(
                            cluster.places.count == 1 ? cluster.places[0].name : "",
                            coordinate: cluster.coordinate,
                            // Single pins point at the location with their tip;
                            // cluster bubbles are centered on it.
                            anchor: cluster.places.count == 1 ? .bottom : .center
                        ) {
                            if cluster.places.count == 1 {
                                let place = cluster.places[0]
                                Button {
                                    selectedPlace = place
                                    withAnimation(.spring()) { showCard = true }
                                } label: {
                                    // One unified photo-balloon pin for every place.
                                    VisitedMapPinView(place: place, imageURL: bestImage(for: place))
                                }
                            } else {
                                Button {
                                    zoomToCluster(cluster)
                                } label: {
                                    clusterBubble(cluster.places.count)
                                }
                            }
                        }
                    }

                    // Custom "you are here" marker, drawn last so it stays on top.
                    if let userLoc = locationManager.userLocation {
                        Annotation("", coordinate: userLoc.coordinate, anchor: .bottom) {
                            UserLocationDot(emoji: selectedEmoji)
                        }
                    }
                }
                .onMapCameraChange { context in
                    // Free roaming — no pan/zoom lock, so trips anywhere work.
                    self.currentCamera = context.camera
                    if isAddingPlace {
                        newPlaceCoordinate = context.camera.centerCoordinate
                    }
                    recomputeClusters()   // re-cluster for the new zoom level
                }
                .onMapCameraChange(frequency: .continuous) { _ in
                    if isAddingPlace {
                        isMapMoving = true
                    }
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    if isAddingPlace {
                        isMapMoving = false
                        newPlaceCoordinate = context.camera.centerCoordinate
                        reverseGeocode(context.camera.centerCoordinate)
                    }
                }
                .ignoresSafeArea()
                
                if isAddingPlace {
                    // Center "placing" pin — the tip marks the exact target point.
                    // It lifts while the map is moving and drops when you stop.
                    ZStack {
                        // Ground shadow at the precise point (screen center).
                        Ellipse()
                            .fill(Color.black.opacity(0.28))
                            .frame(width: isMapMoving ? 18 : 10,
                                   height: isMapMoving ? 6 : 4)
                            .blur(radius: 1)

                        // Branded pin graphic, tip resting on the ground dot.
                        Image(.iconPointer)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 56)
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 3)
                            .offset(y: -28 + (isMapMoving ? -14 : 0))
                    }
                    .animation(.spring(response: 0.32, dampingFraction: 0.62), value: isMapMoving)
                    .allowsHitTesting(false)
                }
                // TOP CONTROLS
                if !isAddingPlace{
                    VStack(spacing: 12) {
                        GlassSearchBar(text: $searchText)
                            .onChange(of: searchText) { _, query in
                                scheduleSearch(query)
                            }

                        if !searchResults.isEmpty {
                            searchResultsList
                        }

                        CategoryChipsView(
                            categories: allCategories,
                            selectedCategory: $selectedCategory
                        )

                        if locationManager.isDenied {
                            locationDeniedBanner
                        }

                        Spacer()

                        HStack {
                            Spacer()
                            VStack(spacing: 12){
                                //                            Button {
                                //                                guard let camera = currentCamera else { return }
                                //
                                //                                withAnimation(.easeInOut) {
                                //
                                //                                }
                                //                            } label: {
                                //                                Image(systemName: "location.north.line.fill")
                                //                                    .frame(width: 44, height: 44)
                                //                                    .background(Color.white)
                                //                                    .clipShape(Circle())
                                //                                    .shadow(radius: 4)
                                //                            }
                                Button {
                                    withAnimation(.spring()) {
                                        isAddingPlace = true
                                        if let camera = currentCamera {
                                            newPlaceCoordinate = camera.centerCoordinate
                                            reverseGeocode(camera.centerCoordinate)
                                        }
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                        .frame(width: 52, height: 52)
                                }
                                .glassEffect(.regular.tint(Color(.appRed)).interactive(), in: Circle())

                                Button {
                                    guard let coordinate = locationManager.userLocation?.coordinate else { return }
                                    withAnimation(.easeInOut) {
                                        cameraPosition = .camera(
                                            MapCamera(
                                                centerCoordinate: coordinate,
                                                distance: 2_000,
                                                heading: 0,          // 🧭 north
                                                pitch: currentCamera?.pitch ?? 0
                                            )
                                        )
                                    }
                                } label: {
                                    Image(systemName: "location.fill")
                                        .foregroundStyle(Color(.appRed))
                                        .frame(width: 52, height: 52)
                                }
                                .glassEffect(.regular.interactive(), in: Circle())
                            }
                        }
                        .padding(.horizontal, 20)

                        EmojiPickerButton(selected: $selectedEmoji, options: emojiOptions)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }
                    .padding(.top, 10)
                }
                
                // LOADER
                if showLoader {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.accent)
                        .scaleEffect(1.2)
                }
                
                // EMPTY STATE
                if places.isEmpty && !showLoader && !isAddingPlace {
                    emptyState
                }

                if showCard {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            dismissBottomCard()
                        }
                }
                
                // BOTTOM CARD
                if let place = selectedPlace, showCard {
                    
                    PlaceCardView(place: place) {
                        dismissBottomCard()
                    }
                    .onTapGesture {
                        navigateToDetails(place)
                    }
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
                }
                if isAddingPlace {
                    VStack {
                        Spacer()

                        VStack(spacing: 12) {
                            // Address preview so the user knows what they're picking.
                            HStack(spacing: 10) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(Color(.appRed))
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(placingName.isEmpty ? "Dropped pin" : placingName)
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundStyle(Color(.textPrimary))
                                        .lineLimit(1)
                                    Text(placingAddress.isEmpty ? "Move the map to position the pin" : placingAddress)
                                        .font(.caption)
                                        .foregroundStyle(Color(.textSecondary))
                                        .lineLimit(2)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)

                            Button {
                                print("Selected Coordinate:", newPlaceCoordinate as Any)

                                // Later → show sheet for name entry
                                withAnimation(.spring()) {
                                    isInAddFlow = true
                                    navigateToAddPlace = true
                                    isAddingPlace = false
                                }
                            } label: {
                                Text("Confirm")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(.accent)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .padding(.horizontal)
                            
                            Button {
                                
                                withAnimation(.spring()) {
                                    isAddingPlace = false
                                    newPlaceCoordinate = nil
                                }
                            } label: {
                                Text("Cancel")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .foregroundColor(.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 30)
                        }
                        
                    }
                    .transition(.move(edge: .bottom))
                }
            }
            .toolbar((isAddingPlace || isInAddFlow || isNavigatingToDetails || isNavigatingToRandomPlace) ? .hidden : .visible, for: .tabBar)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedPlaceForDetails) { place in
                CaptureMomentView(place: place)
                    .toolbar(.hidden, for: .tabBar)
                    .onDisappear {
                        Task {
                                    await refreshPlaces()
                                }
                        isNavigatingToDetails = false   // ← restore when popped back
                    }
            }
            .navigationDestination(item: $randomPlace) { place in
                ExploreDiscoveryView(place: place)
                    .toolbar(.hidden, for: .tabBar)
                    .onDisappear {
                        isNavigatingToRandomPlace = false   // ← restore when popped back
                    }
            }
            .navigationDestination(isPresented: $navigateToAddPlace) {
                AddPlaceView(
                    coordinate: newPlaceCoordinate ?? CLLocationCoordinate2D(
                        latitude: 37.7749,
                        longitude: -122.4194
                    ),
                    suggestedName: placingName
                ){
                    Task {
                                await refreshPlaces()
                            }
                }
                .toolbar(.hidden, for: .tabBar)
                .onDisappear {
                    isInAddFlow = false   // ← restore when popped back
                }
            }
        }
//
        .onAppear {
            selectedCategory = allCategories.first!
            locationManager.requestLocation()
            
            if let place = CoreDataLayer.shared.selectedPlace {
                navigateToRandomPlace(place)
                CoreDataLayer.shared.selectedPlace = nil
            }

            Task {
                await refreshPlaces()
            }
        }
        .task {
//            places = CoreDataLayer.shared.fetchPlaces()
//        if places.isEmpty{
//            showLoader = true
//        }
//            await supabaseVM.fetchPlaces()
//        places = []
//            places = CoreDataLayer.shared.fetchPlaces()
//            showLoader = false
        }
        .task {
//            vistitedPlacesID = await supabaseVM.fetchUniqueVisitedPlaces()
        }
        .onChange(of: filteredPlaces) { _, _ in
            recomputeClusters()
        }
        .onChange(of: locationManager.userLocation) { _, location in
            guard let location, isFirtTime else { return }
            isFirtTime = false
            
            withAnimation(.easeInOut) {
                cameraPosition = .camera(
                    MapCamera(
                        centerCoordinate: location.coordinate,
                        distance: 28000
                    )
                )
            }
        }
    }
    // MARK: - Search results dropdown

    private var searchResultsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(searchResults.prefix(6).enumerated()), id: \.offset) { _, item in
                Button {
                    goToSearchResult(item)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(Color(.appRed))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name ?? "Unknown")
                                .font(.subheadline)
                                .foregroundStyle(Color(.textPrimary))
                                .lineLimit(1)
                            if let locality = item.placemark.locality {
                                Text(locality)
                                    .font(.caption)
                                    .foregroundStyle(Color(.textSecondary))
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .contentShape(Rectangle())
                }
                Divider().padding(.leading, 46)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .padding(.horizontal)
    }

    // MARK: - Location-denied banner

    private var locationDeniedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "location.slash.fill")
                .foregroundStyle(Color(.appRed))
            Text("Location is off — turn it on to center the map on you.")
                .font(.caption)
                .foregroundStyle(Color(.textPrimary))
            Spacer()
            Button("Settings") { openSettings() }
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(Color(.appRed))
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 40))
                .foregroundStyle(Color(.appRed))
            Text("No places yet")
                .font(.headline)
                .foregroundStyle(Color(.textPrimary))
            Text("Tap the + button to drop a pin and save your first place.")
                .font(.subheadline)
                .foregroundStyle(Color(.textSecondary))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        .padding(.horizontal, 40)
    }

    // MARK: - Search + geocoding

    /// Debounced address/landmark search that repositions the map.
    private func scheduleSearch(_ query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            searchResults = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            await runSearch(trimmed)
        }
    }

    private func runSearch(_ query: String) async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let camera = currentCamera {
            request.region = MKCoordinateRegion(
                center: camera.centerCoordinate,
                latitudinalMeters: 60_000,
                longitudinalMeters: 60_000
            )
        }
        let response = try? await MKLocalSearch(request: request).start()
        await MainActor.run {
            searchResults = response?.mapItems ?? []
        }
    }

    private func goToSearchResult(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate

        // Recenter so the spot is in view when we return from the add flow.
        cameraPosition = .camera(
            MapCamera(centerCoordinate: coordinate, distance: 4_000)
        )

        // Prefill and open Add Place for this searched place — one-tap save.
        newPlaceCoordinate = coordinate
        placingName = item.name ?? ""
        searchResults = []
        searchText = ""
        hideKeyboard()
        isInAddFlow = true
        navigateToAddPlace = true
    }

    /// Reverse-geocode the pin being placed so the user sees the address.
    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            guard let p = placemarks?.first else { return }
            let name = p.name ?? p.thoroughfare ?? p.locality ?? "Dropped pin"
            let address = [p.thoroughfare, p.locality, p.administrativeArea, p.country]
                .compactMap { $0 }
                .joined(separator: ", ")
            DispatchQueue.main.async {
                placingName = name
                placingAddress = address
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func refreshPlaces() async {
        let localPlaces = CoreDataLayer.shared.fetchPlaces()
        
        if localPlaces.isEmpty {
            showLoader = true
        } else {
            places = localPlaces   // ✅ show immediately
        }

        await supabaseVM.fetchPlaces()
        
        places = CoreDataLayer.shared.fetchPlaces()  // ✅ latest data
        showLoader = false

        vistitedPlacesID = await supabaseVM.fetchUniqueVisitedPlaces()
        visitedThumbnails = await supabaseVM.fetchVisitedPlaceThumbnails()
        recomputeClusters()
    }

    /// Best image for a pin: a visit memory photo if there is one, otherwise the
    /// place's own uploaded photo. `nil` → the pin shows its category icon.
    private func bestImage(for place: Place) -> String? {
        visitedThumbnails[place.id] ?? place.image_urls?.first
    }

    // MARK: - Clustering

    /// Groups nearby places into clusters sized to the current zoom level.
    private func recomputeClusters() {
        let items = filteredPlaces
        let distance = currentCamera?.distance ?? 28_000
        // Cell size (degrees) scales with zoom: bigger when zoomed out.
        let cellDeg = max((distance / 111_000) * 0.12, 0.0002)

        var buckets: [String: [Place]] = [:]
        for place in items {
            let latCell = Int((place.latitude / cellDeg).rounded(.down))
            let lonCell = Int((place.longitude / cellDeg).rounded(.down))
            buckets["\(latCell)_\(lonCell)", default: []].append(place)
        }

        clusters = buckets.map { key, group in
            let lat = group.map(\.latitude).reduce(0, +) / Double(group.count)
            let lon = group.map(\.longitude).reduce(0, +) / Double(group.count)
            return PlaceCluster(
                id: key,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                places: group
            )
        }
    }

    private func zoomToCluster(_ cluster: PlaceCluster) {
        let newDistance = max((currentCamera?.distance ?? 28_000) / 3, 1_000)
        withAnimation(.easeInOut) {
            cameraPosition = .camera(
                MapCamera(centerCoordinate: cluster.coordinate, distance: newDistance)
            )
        }
    }

    private func clusterBubble(_ count: Int) -> some View {
        Text("\(count)")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(Circle().fill(Color(.appRed)))
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
    }
    private func dismissBottomCard() {
        withAnimation(.spring()) {
            showCard = false
            selectedPlace = nil
        }
    }
    
    private func navigateToDetails(_ place: Place) {
        isNavigatingToDetails = true    // ← hide tab bar immediately
        dismissBottomCard()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            selectedPlaceForDetails = place
        }
    }

    private func navigateToRandomPlace(_ place: Place) {
        isNavigatingToRandomPlace = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            randomPlace = place
        }
    }
    
    private func navigateToAddPlaceFunc() {
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            navigateToAddPlace = true
        }
    }

}



/// A group of nearby places rendered as one annotation (a single pin when it
/// contains one place, a count bubble when it contains several).
struct PlaceCluster: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let places: [Place]
}

#Preview{
    MapView()
}
