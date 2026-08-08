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

    
    var supabaseVM = SupabaseAuthVM()
    
    @State private var places: [Place] = []
    var body: some View {
        NavigationStack {
            ZStack {
                
                Map(position: $cameraPosition) {
                    UserAnnotation()
                    ForEach(filteredPlaces) { place in
                        Annotation(place.name, coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)) {
                            Button {
                                selectedPlace = place
                                withAnimation(.spring()) { showCard = true }
                            } label: {
                                if vistitedPlacesID.contains(place.id){
//                                    MapPinView(place: place, isVisited: true)
                                    VisitedMapPinView(place: place)
                                }else{
                                    MapPinView(place: place)
                                }
                            }
                        }
                    }
                }
                .onMapCameraChange { context in
                    let camera = context.camera
                    self.currentCamera = camera
                    
                    if isAddingPlace {
                        newPlaceCoordinate = camera.centerCoordinate
                    }
                    
                    guard let userLocation = locationManager.userLocation else { return }
                    
                    let mapCenter = CLLocation(
                        latitude: camera.centerCoordinate.latitude,
                        longitude: camera.centerCoordinate.longitude
                    )
                    
                    let distanceFromUser = mapCenter.distance(from: userLocation)
                    let maxPanDistance: Double = maxAltitude
                    
                    if distanceFromUser > maxPanDistance || camera.distance > maxAltitude {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            cameraPosition = .camera(
                                MapCamera(
                                    centerCoordinate: userLocation.coordinate,
                                    distance: min(camera.distance, maxAltitude),
                                    heading: camera.heading,
                                    pitch: camera.pitch
                                )
                            )
                        }
                    }
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
                    }
                }
                .ignoresSafeArea()
                
                if isAddingPlace {
                    VStack {
                        Spacer()
                        
                        Image(systemName: isMapMoving ? "mappin" : "mappin.and.ellipse")
                            .font(.system(size: 44))
                            .foregroundStyle(.appRed)
                            .shadow(radius: 4)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isMapMoving)
                        
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }
                // TOP CONTROLS
                if !isAddingPlace{
                    VStack(spacing: 12) {
                        SearchBarView(text: $searchText)
                        CategoryChipsView(
                            categories: allCategories,
                            selectedCategory: $selectedCategory
                        )
                        
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
                                        }
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                        .fontWeight(.semibold)
                                        .frame(width: 44, height: 44)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .shadow(radius: 4)
                                }
                                
                                Button {
                                    guard let coordinate = locationManager.userLocation?.coordinate else { return }
                                    guard let camera = currentCamera else { return }
                                    withAnimation(.easeInOut) {
                                        cameraPosition = .camera(
                                            MapCamera(
                                                centerCoordinate: coordinate,
                                                distance: 28_000,
                                                heading: 0,          // 🧭 north
                                                pitch: camera.pitch
                                            )
                                        )
                                        //                                    cameraPosition = .camera(
                                        //                                        MapCamera(
                                        //                                            centerCoordinate: coordinate,
                                        //                                            distance: 28_000   // nicely zoomed out
                                        //                                        )
                                        //                                    )
                                    }
                                } label: {
                                    Image(systemName: "location.fill")
                                        .frame(width: 44, height: 44)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .shadow(radius: 4)
                                }
                            }
                        }
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
                        
                        VStack{
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
                AddPlaceView(coordinate: newPlaceCoordinate ?? CLLocationCoordinate2D(
                    latitude: 37.7749,
                    longitude: -122.4194
                )){
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



#Preview{
    MapView()
}
