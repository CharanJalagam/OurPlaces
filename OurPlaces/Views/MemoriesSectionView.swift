//
//  MemoriesSectionView.swift
//  OurPlaces
//
//  Created by apple on 10/01/26.
//

import SwiftUI


struct MemoriesSectionView: View {
    
    let photos: [VisitImage]
    let place: Place
    @State private var selectedIndex: Int? = nil
    var body: some View {
        NavigationStack{
            VStack(alignment: .leading, spacing: 12) {
                
                // Header
                HStack {
                    Text("Your Memories")
                        .font(.headline)
                    
                    Text("\(photos.count) PHOTOS")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
//                    NavigationLink {
//                        PhotosView(images: photos, place: place, startIndex: 0)
//                    } label: {
                        Label("Relive", systemImage: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .onTapGesture {
                                selectedIndex = 0
                            }
//                    }

                }
                
                // Photos
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
//                            NavigationLink {
//                                PhotosView(
//                                    images: photos, place: place,
//                                    startIndex: index
//                                )
//                            } label: {
                                MemoryImageCard(photo: photo)
                                .onTapGesture {
                                    selectedIndex = index
                                }
//                            }
                            .buttonStyle(.plain) // removes blue highlight
                        }
                    }
                }
            }
            .fullScreenCover(item: $selectedIndex) { index in
                PhotosView(images: photos, place: place, startIndex: index)
            }
        }
    }
}
struct MemoryImageCard: View {
    
    let photo: VisitImage
    
    var body: some View {
        CachedAsyncImage(url: URL(string: photo.image_url)) { phase in
            switch phase {
            case .empty:
                placeholder
                
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                
            case .failure:
                placeholder
                
            @unknown default:
                placeholder
            }
        }
        .frame(width: 110, height: 150)
        .cornerRadius(18)
        .clipped()
        .overlay(
            VStack {
                Spacer()
                Text(timeAgo(from: photo.created_at_millis))
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                    .padding(6)
            },
            alignment: .bottomLeading
        )
    }
    
    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.gray.opacity(0.3))
            
            ProgressView()
        }
    }
    
    func timeAgo(from millis: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
