//
//  PhotosView.swift
//  OurPlaces
//
//  Created by apple on 25/01/26.
//

import Foundation
import SwiftUI


//
//  PhotosView.swift
//  OurPlaces
//

import SwiftUI

struct PhotosView: View {
    let place: Place
    let images: [VisitImage]
    var startIndex: Int
    @State private var currentIndex = 0
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0

    init(images: [VisitImage], place: Place, startIndex: Int) {
        self.images = images
        self.place = place
        self.startIndex = startIndex
        _currentIndex = State(initialValue: startIndex)
    }
    
    var body: some View {
        ZStack {
            
            // Dim background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            // MARK: - Image Loader
            CachedAsyncImage(url: URL(string: images[currentIndex].image_url)) { phase in
                switch phase {
                case .empty:
                    // Loader
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea()
                    
                case .failure:
                    VStack {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("Failed to load image")
                            .foregroundColor(.white)
                            .font(.subheadline)
                    }
                    
                @unknown default:
                    EmptyView()
                }
            }
            
            // MARK: - Tap Areas (behind UI)
            HStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        goPrevious()
                    }
                
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        goNext()
                    }
            }
            
            // MARK: - Overlay UI
            VStack(spacing: 12) {
                
                // Progress Bars
                HStack(spacing: 4) {
                    ForEach(images.indices, id: \.self) { index in
                        Capsule()
                            .fill(index <= currentIndex ? Color.white : Color.white.opacity(0.3))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Header
                HStack(spacing: 12) {
                    
                    CachedAsyncImage(url: URL(string: place.image_urls?.first ?? "")) { phase in
                        switch phase {
                        case .empty:
                            // Loader
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                        case .success(let image):
                            image
                                .resizable()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                            
                        case .failure:
                            VStack {
                                Image(systemName: "photo")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            
                            }
                            
                        @unknown default:
                            EmptyView()
                        }
                    }                        
                    
                    VStack(alignment: .leading) {
                        Text(place.name)
                            .foregroundColor(.white)
                            .font(.title3)
                        
                        Text(timeAgo(from: images[currentIndex].created_at_millis))
                            .foregroundColor(.white)
                            .font(.subheadline)
                    }
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 150 || value.velocity.height > 500 {
                        dismiss()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .animation(.interactiveSpring(), value: dragOffset)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.hidden, for: .navigationBar)
    }
    
    // MARK: - Navigation Logic
    private func goNext() {
        guard currentIndex < images.count - 1 else { return }
        withAnimation(.easeInOut) {
            currentIndex += 1
        }
    }
    
    private func goPrevious() {
        guard currentIndex > 0 else { return }
        withAnimation(.easeInOut) {
            currentIndex -= 1
        }
    }
}
func timeAgo(from millis: Int64) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
}
