//
//  FeaturedCarouselView.swift
//  OurPlaces
//
//  Created by apple on 10/01/26.
//

import SwiftUI

struct FeaturedCarouselView: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(0..<3) { _ in
                    FeaturedPlaceCard()
                }
            }
        }
    }
}

struct FeaturedPlaceCard: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image("sample_place") // placeholder image
                .resizable()
                .scaledToFill()
                .frame(width: 260, height: 320)
                .clipped()
            
            VStack(alignment: .leading, spacing: 6) {
                Text("4.9 ★  Cafe • 0.2 mi")
                    .font(.caption)
                    .padding(6)
                    .background(Color.orange)
                    .cornerRadius(6)
                
                Text("The Azure Cafe")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Experience the finest artisanal coffee...")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding()
        }
        .cornerRadius(20)
    }
}
