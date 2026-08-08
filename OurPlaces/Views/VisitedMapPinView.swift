//
//  VisitedMapPinView.swift
//  OurPlaces
//
//  Created by SAIRAM  on 18/03/26.
//

import SwiftUI

struct VisitedMapPinView: View {
    let place: Place
    @State private var imageURL: String? = ""
    let size: CGFloat = 50
    let authVM  = SupabaseAuthVM()
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Circle with image
            ZStack {
                
                // Triangle (BACK)
                Triangle()
                    .fill(Color.white)
                    .frame(width: 14, height: 12)
                    .shadow(radius: 2)
                    .offset(y: size / 2) // push below circle
                
                // Circle (FRONT)
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: size, height: size)
                        .shadow(radius: 4)
                    
                    CachedAsyncImage(url: URL(string: imageURL ?? "")) { phase in
                        switch phase {
                        case .empty:
                            defaultImage
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            defaultImage
                        @unknown default:
                            defaultImage
                        }
                    }
                    .frame(width: size - 6, height: size - 6)
                    .clipShape(Circle())
                }
            }
            
            // Pointer
            Triangle()
                .fill(Color.white)
                .frame(width: 12, height: 10)
                .shadow(radius: 2)
                .offset(y: -1)
        }
        .task(id: place.id) {
                do {
                    let visitImg = try await authVM.fetchImagesForPlace(placeId: place.id).first
                    imageURL = visitImg?.image_url
                    } catch {
                        print("Failed to fetch images:", error)
                    }
        }
    }
    
    var defaultImage: some View {
        Image(systemName: "photo")
            .resizable()
            .scaledToFit()
            .padding(10)
            .foregroundColor(.gray)
    }
}

//#Preview {
//    VisitedMapPinView()
//}
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY)) // bottom
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY)) // left
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY)) // right
        path.closeSubpath()
        
        return path
    }
}
