//
//  VisitCardView.swift
//  OurPlaces
//
//  Created by apple on 16/01/26.
//
import SwiftUI
import MapKit

struct VisitCardView: View {
    
    let visit: MemoriesViewModel.VisitWithPlace
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            StaticMapView(
                coordinate: CLLocationCoordinate2D(
                    latitude: visit.place.latitude,
                    longitude: visit.place.longitude
                )
            )
            
            Text(visit.place.name)
                .font(.headline)
                .padding()
                .padding(.bottom)
            
            
        }
//        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 4)
    }
}


