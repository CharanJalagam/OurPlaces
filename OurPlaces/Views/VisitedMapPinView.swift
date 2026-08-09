//
//  VisitedMapPinView.swift
//  OurPlaces
//
//  Created by SAIRAM  on 18/03/26.
//

import SwiftUI

struct VisitedMapPinView: View {
    let place: Place
    /// Preloaded by MapView in one batched query — no per-pin network call.
    var imageURL: String?
    let size: CGFloat = 50

    var body: some View {
        VStack(spacing: 0) {

            // Photo bubble with a white gap + brand ring.
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: size, height: size)

                if let imageURL, !imageURL.isEmpty, let url = URL(string: imageURL) {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            placeholder
                        }
                    }
                    .frame(width: size - 6, height: size - 6)
                    .clipShape(Circle())
                } else {
                    placeholder
                        .frame(width: size - 6, height: size - 6)
                        .clipShape(Circle())
                }
            }
            .overlay(
                Circle().stroke(Color(.appRed), lineWidth: 3)
            )

            // Single pointer, same brand color, tucked under the ring.
            Triangle()
                .fill(Color(.appRed))
                .frame(width: 15, height: 12)
                .offset(y: -3)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.28), radius: 4, y: 3)
    }

    // Shown when a place has no photo — the category icon on a soft brand tint.
    var placeholder: some View {
        ZStack {
            Color(.appRed).opacity(0.15)
            Image(systemName: categoryIcon)
                .foregroundColor(Color(.appRed))
                .font(.system(size: size * 0.34, weight: .semibold))
        }
    }

    private var categoryIcon: String {
        switch place.category.lowercased() {
        case "food":          return "fork.knife"
        case "cafe":          return "cup.and.saucer.fill"
        case "historic":      return "building.columns.fill"
        case "nature":        return "leaf.fill"
        case "shopping":      return "bag.fill"
        case "religious":     return "sparkles"
        case "entertainment": return "theatermasks.fill"
        default:              return "mappin"
        }
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
