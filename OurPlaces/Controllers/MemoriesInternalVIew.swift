//
//  MemoriesInternalVIew.swift
//  OurPlaces
//
//  Created by apple on 14/02/26.
//

import SwiftUI

import SwiftUI

struct MemoriesInternalVIew: View {
    
    let visit: TimelineViewModel.VisitWithPlace
    @State private var images: [VisitImage] = []
    @State private var showLoader = true
    @State private var placeImg = true
    @State private var visitCount = 0
    @State private var selectedIndex: Int? = nil
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    let supabase = SupabaseAuthVM()
    let vm = MemoriesViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                
                // MARK: - Header Image
                ZStack(alignment: .top) {
                    
                    if let first = visit.place.image_urls?.first,
                       let url = URL(string: first) {
                        
                        CachedAsyncImage(url: url) { phase in
                            switch phase {
                                
                            case .empty:
                                // 👇 Reserve same height while loading
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 380)
                                
                            case .success(let image):
                                GeometryReader { geo in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: geo.size.width, height: 380)
                                        .clipped()
                                }
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 380)
                                
                            case .failure:
                                Image("testImg")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 380)
                                    .clipped()
                                
                            @unknown default:
                                EmptyView()
                            }
                        }
                        
                    } else {
                        Image("testImg")
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 380)
                            .clipped()
                    }
                   
                }
                
                // MARK: - Info Card
                VStack(alignment: .leading, spacing: 16) {
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(visit.place.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Hyderabad")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    
                    HStack(spacing: 30) {
                        StatView(title: "Photos", value: "\(images.count)")
                        StatView(title: "Vists", value: "\(visitCount)")
                        StatView(title: "Last Visit Date", value: formatDate(visit.visitDate))
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(25)
                .shadow(radius: 10)
                .offset(y: -40)
                .padding(.horizontal)
                
                
                if showLoader {
                    VStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if images.isEmpty {
                    VStack {
                        Spacer()
                        Text("No memories yet")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                } else {
                    // MARK: Captured Moments
                    VStack(alignment: .leading) {
                        Text("Captured Moments")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: columns, spacing: 12) {
//                            ForEach(images, id: \.self) { image in
//                                GridImageView(urlString: image.image_url)
//                            }
                            ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                                GridImageView(urlString: image.image_url)
                                    .onTapGesture {
                                        selectedIndex = index
                                    }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)

                    }
                    .padding(.top, -20)
                }
            }
        }
        .fullScreenCover(item: $selectedIndex) { index in
            PhotosView(images: images, place: visit.place, startIndex: index)
        }
        .task {
            await loadImages()
            await loadCount()
        }
        .toolbar(.hidden, for: .tabBar)
        .ignoresSafeArea(edges: .top)
        .background(Color(.systemGroupedBackground))
    }
    private func loadImages() async {
        showLoader = true
        do {
            images = try await supabase.fetchImagesForPlace(placeId: visit.place.id)
        } catch {
            images = []
        }
        showLoader = false
    }
    private func loadCount() async {
       
            let visits = await vm.fetchPlaceVisitCounts()
        visitCount = visits[visit.place.id] ?? 0
    }
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}
struct GridImageView: View {
    
    let urlString: String
    
    var body: some View {
        GeometryReader { geo in
            CachedAsyncImage(url: URL(string: urlString)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: geo.size.width, height: 220)
                case .success(let loadedImage):
                    loadedImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: 220)
                        .clipped()
                case .failure:
                    Color.gray.opacity(0.3)
                        .frame(width: geo.size.width, height: 220)
                @unknown default:
                    EmptyView()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .frame(height: 220)
    }
}

struct StatView: View {
    var title: String
    var value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}
extension Int: Identifiable {
    public var id: Int { self }
}
//#Preview {
//    MemoriesInternalVIew()
//}
