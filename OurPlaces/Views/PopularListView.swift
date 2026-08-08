//
//  PopularListView.swift
//  OurPlaces
//
//  Created by apple on 10/01/26.
//
import SwiftUI

struct PopularListView: View {
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<3) { _ in
                PopularPlaceRow()
            }
        }
    }
}

struct PopularPlaceRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Image("sample_place")
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Neon Ramen Bar")
                    .font(.headline)
                
                Text("Tokyo District • $$")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("📍 Show on Map")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            Spacer()
            
            Image(systemName: "heart")
                .foregroundColor(.gray)
        }
    }
}
