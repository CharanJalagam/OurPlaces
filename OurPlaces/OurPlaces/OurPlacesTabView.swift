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
            
            // MARK: - Explore
            ExploreView()
                .tabItem {
                    Image(systemName: "safari.fill")
                    Text("Explore")
                }
            
            // MARK: - Map
            MapView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Map")
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
