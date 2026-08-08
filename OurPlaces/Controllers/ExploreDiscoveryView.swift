//
//  ExploreDiscoveryView.swift
//  OurPlaces
//
//  Created by apple on 07/02/26.
//

import SwiftUI
import MapKit


struct ExploreDiscoveryView: View {
    
    let place: Place
    var body: some View {
        ZStack {
            if place.image_urls?.count ?? 0 > 0 {
                CachedAsyncImage(url: URL(string: place.image_urls?.first ?? "")) { phase in
                    switch phase {
                        
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.3))
                            ProgressView()
                        }
                        
                    case .success(let image):
                        image
                            .resizable()
                            .ignoresSafeArea()
                        
                    case .failure:
//                        ZStack {
//                            RoundedRectangle(cornerRadius: 12)
//                                .fill(Color.gray.opacity(0.3))
//                            Image(systemName: "photo.fill")
//                                .foregroundStyle(.gray)
//                        }
//
                        Image("testImg")
                            .resizable()
                            .ignoresSafeArea()
                    @unknown default:
                        EmptyView()
                    }
                }
            }else{
                Image("testImg")
                    .resizable()
                    .ignoresSafeArea()
            }
            GradientOverlay()
                .ignoresSafeArea()
            ContentOverlay(place: place)
        }
        .toolbar(.hidden, for: .tabBar)
    }
}
struct GradientOverlay: View {
    var body: some View {
        LinearGradient(
            colors: [
                .clear,
                Color.black.opacity(0.55)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
struct ContentOverlay: View {
    @Environment(\.dismiss) private var dismiss
    let place: Place
    let supabase = SupabaseAuthVM()
    @State private var isVisted: Bool = false
    @State private var dataLoaded: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            
            if dataLoaded{
                if !isVisted{
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                        Text("NEW DISCOVERY")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.orange)
                }else{
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                        Text("VISIT AGAIN")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.orange)
                }
            }
            
            Text(place.name)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineSpacing(4)
            
            HStack(spacing: 8) {
                InfoTag(icon: "mountain.2.fill", text: "Epic Views")
                InfoTag(icon: "speaker.slash.fill", text: "Quiet Spot")
//                InfoTag(icon: "sun.max.fill", text: "Best at Golden Hour")
            }
            .padding(.bottom)
            
            
            
            HStack(spacing: 12) {
                Button(action: {
                    openAppleMapsDirections(
                        toLatitude: place.latitude,
                        longitude: place.longitude,
                        placeName: place.name
                    )
                }) {
                    HStack {
                        Text("Let's Go")
                            .font(.headline)
                            .fontWeight(.bold)
                        Image(systemName: "arrow.right")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .padding()
                    .background(.orangeCustom)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .fontWeight(.bold)
                        .frame(width: 60, height: 70)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(30)
        .padding(.bottom, 20)
        .task {
            do {
                let visited = try await supabase.isPlaceVisited(placeId: place.id)
                
                withAnimation(.easeInOut(duration: 0.25)) {
                    isVisted = visited
                    dataLoaded = true
                }
               
            } catch {
               dataLoaded = false
            }
        }
    }
}

struct InfoTag: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}
func openAppleMapsDirections(
    toLatitude lat: Double,
    longitude lon: Double,
    placeName: String
) {
    let destinationCoordinate = CLLocationCoordinate2D(
        latitude: lat,
        longitude: lon
    )
    
    let placemark = MKPlacemark(coordinate: destinationCoordinate)
    let mapItem = MKMapItem(placemark: placemark)
    mapItem.name = placeName
    
    let launchOptions = [
        MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
    ]
    
    mapItem.openInMaps(launchOptions: launchOptions)
}

