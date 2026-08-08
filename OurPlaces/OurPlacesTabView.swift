//
//  OurPlacesTabView.swift
//  OurPlaces
//
//  Created by SAIRAM  on 03/01/26.
//


import SwiftUI

struct OurPlacesTabView: View {
    
    var body: some View {
        TabView {
            
            
            
            
            // MARK: - Map
            MapView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Map")
                }
            
            // MARK: - Explore
            ExploreView()
                .tabItem {
                    Image(systemName: "safari.fill")
                    Text("Explore")
                }
            
            // MARK: - Memories
            TimelineView()
                .tabItem {
                    Image(systemName: "photo.fill")
                    Text("Memories")
                }
            
            // MARK: - Profile
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
        }
        .tint(.accent) // uses your app accent color
    }
}
