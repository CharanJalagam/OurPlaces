//
//  MapPinView.swift
//  OurPlaces
//
//  Created by apple on 10/01/26.
//

import SwiftUI


struct MapPinView: View {
    let place: Place
    var isVisited: Bool = false
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if !isVisited{
                    Circle()
                        .fill(isVisited ? .appRed : Color.orange)
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: pinIcon)
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .semibold))
                }else{
                    Image(systemName: "heart.fill")
                        .foregroundColor(.appRed)
                        .font(.system(size: 24, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
            }
            .shadow(radius: 4)
        }
    }
}
private extension MapPinView {
    
    var pinIcon: String {
        switch place.category.lowercased() {
        case "food":
            return "fork.knife"
        case "cafe" :
            return "cup.and.saucer.fill"
        case "historic":
            return "building.columns.fill"
        case "nature":
            return "leaf.fill"
        case "shopping":
            return "bag.fill"
        case "religious":
            return "sparkles"
        case "entertainment":
            return "theatermasks.fill"
        default:
            return "mappin.fill"
        }
    }
    
    var pinColor: Color {
        switch place.category.lowercased() {
        case "food", "cafe":
            return .orange
        case "historic":
            return .brown
        case "nature":
            return .green
        case "shopping":
            return .pink
        case "religious":
            return .purple
        case "entertainment":
            return .red
        default:
            return .blue
        }
    }
}

