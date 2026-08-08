//
//  MemoriesView.swift
//  OurPlaces
//
//  Created by apple on 16/01/26.
//

import SwiftUI

struct MemoriesView: View {
    

    @StateObject private var viewModel = MemoriesViewModel()
    var body: some View {
        NavigationStack{
            ZStack {
                VStack(spacing: 16) {
//                    ScrollView {
                        PhotosListView(viewModel: viewModel)
//                    }
                }
                
//                FloatingAddButton()
            }
        }
    }
}
struct HeaderView: View {
    var body: some View {
        
        HStack {
            Spacer()
            Text("All Memories")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
//            Image(systemName: "magnifyingglass")
//                .font(.title3)
        }
        .padding(.horizontal)
    }
}
struct PlacesListView: View {
    
    var viewModel :MemoriesViewModel
    @State private var showLoader = false
    @State private var selectedPlaceForDetails: MemoriesViewModel.VisitWithPlace?
    var body: some View {
        ZStack{
            
                ScrollView {
                    VStack(spacing: 24) {
                        ForEach(viewModel.groupedVisits, id: \.date) { section in
                            VStack(alignment: .leading, spacing: 12) {
                                
                                Text(section.date.formatted(date: .long, time: .omitted))
                                    .font(.headline)
                                
                                ForEach(section.visits) { visit in
                                    VisitCardView(visit: visit)
                                        .onTapGesture {
                                            navigateToInternal(visit)
                                        }
                                }
                            }
                        }
                    }
                    .padding()
                }
            if showLoader{
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            showLoader = true
            await viewModel.fetchVisits()
            showLoader = false
        }
        .navigationDestination(item: $selectedPlaceForDetails) { visit in
//            MemoriesInternalVIew(visit: visit)
        }
    }
    private func navigateToInternal(_ visit: MemoriesViewModel.VisitWithPlace) {
        
            selectedPlaceForDetails = visit
    }
}

struct MemoryPlaceSection: View {
    
    let title: String
    let tripTitle: String
    let date: String
    let placesCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            Text(title)
                .font(.headline)
            
            VStack(spacing: 0) {
//                MapSnapshotView()
                
                PlaceCard(
                    title: tripTitle
                )
            }
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 4)
        }
    }
}
struct PlaceCard: View {
    
    let title: String
   
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
            }
            
            Spacer()
        }
        .padding()
    }
}
struct PhotosListView: View {
    
    var viewModel: MemoriesViewModel
    @State private var showLoader = false
    
    var body: some View {
        ZStack {
            
            ScrollView {
                VStack(spacing: 24) {
                    ForEach(viewModel.groupedPhotos, id: \.date) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            
                            Text(section.date.formatted(date: .long, time: .omitted))
                                .font(.headline)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(section.photos) { photo in
                                        PhotoCardView(photo: photo)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            
            if showLoader {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            showLoader = true
            await viewModel.fetchPhotos()
            showLoader = false
        }
    }
}

struct PhotoSection: View {
    
    let timestamp: String
    let photos: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            Text(timestamp)
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(photos.indices, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 160)
                    }
                }
            }
        }
    }
}

struct PhotoCardView: View {
    
    let photo: Photo
    
    var body: some View {
        CachedAsyncImage(url: URL(string: photo.image_url)) { phase in
            switch phase {
            case .empty:
                Color.gray.opacity(0.3)
                
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                
            case .failure:
                Color.gray.opacity(0.3)
            }
        }
        .frame(width: 120, height: 160)
        .clipped()
        .cornerRadius(12)
    }
}


#Preview {
    MemoriesView()
}
