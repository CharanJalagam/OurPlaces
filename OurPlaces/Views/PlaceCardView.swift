//
//  PlaceCardView.swift
//  OurPlaces
//
//  Created by apple on 10/01/26.
//

import SwiftUI
import MapKit

struct PlaceCardView: View {
    
    let place: Place
    let onClose: () -> Void
    let authVM  = SupabaseAuthVM()
    @State private var isVisited: Bool = true
    @State private var showLoader: Bool = false
    @State private var images: [VisitImage] = []
    var body: some View {
        ZStack{
            
                VStack(spacing: 16) {
                    
                    // Drag Indicator
                    Capsule()
                        .frame(width: 40, height: 5)
                        .foregroundColor(.gray.opacity(0.4))
                        .padding(.top, 8)
                    
                    
                    if isVisited && !images.isEmpty {
                        MemoriesSectionView(photos: images, place: place)
                            .transition(
                                .move(edge: .top)
                                .combined(with: .opacity)
                            )
                    }
                    if isVisited && !images.isEmpty {
                        Capsule()
                            .frame(height: 0.5)
                            .foregroundColor(.gray.opacity(0.4))
                            .padding(.top, 8)
                    }
                    
                    // PLACE DETAILS
                    HStack {
                        
                        VStack(alignment: .leading, spacing: 6) {
                            if isVisited{
                                HStack(spacing: 6) {
                                    Text("VISITED")
                                        .font(.caption.bold())
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.orange.opacity(0.15))
                                )
                            }
                            Text(place.name)
                                .font(.headline)
                            
                            //                    Text("\(place.category) • \(place.distance)")
                            Text("\(place.category)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.orange)
                                Text("\(place.rating ?? 0, specifier: "%.1f")")
                                Text("(\(place.rating_count) reviews)")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                            
                        }
                        
                        Spacer()
                        
                        //                RoundedRectangle(cornerRadius: 12)
                        //                    .fill(Color.gray.opacity(0.3))
                        //                    .frame(width: 64, height: 64)
                        TabView {
                            ForEach(place.image_urls ?? [], id: \.self) { urlString in
                                CachedAsyncImage(url: URL(string: urlString)) { phase in
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
                                            .scaledToFill()
                                        
                                    case .failure:
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.gray.opacity(0.3))
                                            Image(systemName: "photo.fill")
                                                .foregroundStyle(.gray)
                                        }
                                        
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .frame(width: 84, height: 84)
                                .clipped()
                                .cornerRadius(12)
                            }
                        }
                        .tabViewStyle(.page)
                        .frame(width: 84, height: 84)
                        
                        
                    }
                    
                    // ACTION BUTTONS
                    HStack(spacing: 14) {
                        Button {
                            openAppleMapsDirections(
                                toLatitude: place.latitude,
                                longitude: place.longitude,
                                placeName: place.name
                            )
                        } label: {
                            Label("Directions", systemImage: "location.fill")
                                .frame(maxWidth: .infinity, maxHeight: 34)
                        }
                        .buttonStyle(.borderedProminent)
                        if place.phone_number ?? "" != "" {
                            Button {
                                if let phone = place.phone_number {
                                    callPhoneNumber(phone)
                                }
                            } label: {
                                Image(systemName: "phone.fill")
                                    .frame(width: 44, height: 44)
                                    .background(Color.gray.opacity(0.15))
                                    .clipShape(Circle())
                            }
                        }
                        if place.email ?? "" != ""{
                            Button {
                                if let email = place.email {
                                    openMail(
                                        to: email,
                                        subject: "Enquiry about \(place.name)",
                                        body: "Hello,\n\nI would like to know more about \(place.name).\n"
                                    )
                                }
                            } label: {
                                Image(systemName: "mail.fill")
                                    .frame(width: 44, height: 44)
                                    .background(Color.gray.opacity(0.15))
                                    .clipShape(Circle())
                            }
                        }
                        
                    }
                    
//                    if showLoader {
//                        ProgressView()
//                            .scaleEffect(1.2)
//                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(24)
                .shadow(radius: 10)
                .padding()
                .frame(maxHeight: .infinity, alignment: .bottom)
                
        }
        .task(id: place.id) {
            showLoader = true
            
            do {
                let visited = try await authVM.isPlaceVisited(placeId: place.id)
                
                withAnimation(.easeInOut(duration: 0.25)) {
                    isVisited = visited
                }
                
                showLoader = false
                if isVisited{
                    do {
                        images = try await authVM.fetchImagesForPlace(placeId: place.id)
                    } catch {
                        print("Failed to fetch images:", error)
                    }
                }
            } catch {
                showLoader = false
                print("Failed to check visit status:", error)
            }
        }
    }
    
    func callPhoneNumber(_ number: String) {
        let cleanNumber = number
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        
        if let url = URL(string: "tel://\(cleanNumber)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    func openMail(to email: String, subject: String? = nil, body: String? = nil) {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        
        var queryItems: [URLQueryItem] = []
        
        if let subject = subject {
            queryItems.append(URLQueryItem(name: "subject", value: subject))
        }
        
        if let body = body {
            queryItems.append(URLQueryItem(name: "body", value: body))
        }
        
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        
        guard let url = components.url else { return }
        
        UIApplication.shared.open(url)
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

}
struct CircleIconButton: View {
    let icon: String
    
    var body: some View {
        Button {
        } label: {
            Image(systemName: icon)
                .frame(width: 44, height: 44)
                .background(Color.gray.opacity(0.15))
                .clipShape(Circle())
        }
    }
}

//#Preview {
//    PlaceCardView(place: Place(id: UUID(), name: "Charminar", rating: 234, rating_count: 23, description: nil, category: "food", latitude:1223, longitude: 12323, phone_number: "8977", email: "ahbdkjad", website: "asdjakj", image_urls: [], is_visited: true, created_at: "asd")) {
//        
//    }
//}


