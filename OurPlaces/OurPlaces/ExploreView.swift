//
//  ExploreView.swift
//  OurPlaces
//
//  Created by SAIRAM  on 03/01/26.
//


import SwiftUI

struct Category: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
}


struct ExploreView: View {
    let categories: [Category] = [
        Category(title: "Nature", icon: "tree"),
        Category(title: "Food", icon: "fork.knife"),
        Category(title: "Cafe", icon: "cup.and.saucer"),
        Category(title: "Hotels", icon: "bed.double"),
        Category(title: "Shopping", icon: "bag"),
        Category(title: "Culture", icon: "building.columns")
    ]

    @State private var selectedCategoryID: UUID?

    var body: some View {
        ZStack {
            // App background
            Color(.background)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                
                // Header
                ZStack() {
                    Color(.accent)
                    
                    VStack(spacing: 16) {
                        ProfileLabelView()
                            .padding(.top, 55)
                        
                        HStack() {
                            TextField("Search", text: .constant(""))
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(10)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button {
                                
                            } label: {
                                Image(systemName: "bookmark")
                                    .padding(13)
                                    .foregroundColor(.white)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white, lineWidth: 1)
                                    )
                                
                            }
                            
                        }
                        .padding(.leading, 20)
                        .padding(.trailing, 20)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                Spacer(minLength: 10)
                                
                                ForEach(categories) { category in
                                    CategoryView(
                                        category: category,
                                        isSelected: selectedCategoryID == category.id
                                    )
                                    .onTapGesture {
                                        selectedCategoryID = category.id
                                    }
                                }
                                
                                Spacer(minLength: 20)
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
                .frame(height: 240)
                .ignoresSafeArea()
                
                ScrollView{
                    
                    VStack{
                        Rectangle().frame(height: 100)
                        Rectangle().frame(height: 100)
                        Rectangle().frame(height: 100)
                        Rectangle().frame(height: 100)
                        Rectangle().frame(height: 100)
                            
                    }
                }
                

                
            }
        }
    }
}

#Preview {
    ExploreView()
}

struct ProfileLabelView: View {
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Good Evening, Charan")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Button {
                    // profile action
                } label: {
                    Image(systemName: "person.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
            }

            HStack {
                Text("Discover places that matter")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
            }
        }
        .padding(.horizontal, 20)
    }
}

struct CategoryView: View {
    let category: Category
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: category.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)

            Text(category.title)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(isSelected ? .accent : .white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
                   RoundedRectangle(cornerRadius: 10)
                       .fill(isSelected ? Color.white : Color.clear)
               )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white, lineWidth: 1)
        )

    }
}

