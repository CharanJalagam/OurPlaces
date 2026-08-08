//
//  CategoryChipsView.swift
//  OurPlaces
//
//  Created by apple on 10/01/26.
//

import SwiftUI


struct CategoryChipsView: View {
    

    
    let categories: [PlaceCategory]
    @Binding var selectedCategory: PlaceCategory
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories) { category in
                    HStack(spacing: 6) {
                        Image(systemName: category.icon)
                        Text(category.title)
                    }
                    .frame(minWidth: 60)
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        selectedCategory == category
                        ? .accent
                        : Color.white
                    )
                    .foregroundColor(
                        selectedCategory == category
                        ? .white
                        : .black
                    )
                    .cornerRadius(20)
                    .shadow(radius: 3)
                    .onTapGesture {
                        withAnimation {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

