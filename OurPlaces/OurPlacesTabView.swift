//
//  OurPlacesTabView.swift
//  OurPlaces
//
//  Created by SAIRAM  on 03/01/26.
//


import SwiftUI

struct OurPlacesTabView: View {

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        // Soft warm coral tint so the bar reads distinct from the screen.
        appearance.backgroundColor = UIColor(red: 0.99, green: 0.90, blue: 0.90, alpha: 1.0)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

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
