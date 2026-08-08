//
//  StaticMapView.swift
//  OurPlaces
//
//  Created by apple on 16/01/26.
//


import SwiftUI
import MapKit

struct StaticMapView: View {
    
    let pin: MapPinItem
    
    @State private var region: MKCoordinateRegion
    
    init(coordinate: CLLocationCoordinate2D) {
        let pin = MapPinItem(coordinate: coordinate)
        self.pin = pin
        
        _region = State(
            initialValue: MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        )
    }
    
    var body: some View {
        Map(
            coordinateRegion: $region,
            interactionModes: [],
            annotationItems: [pin]
        ) { item in
            MapMarker(
                coordinate: item.coordinate,
                tint: .red
            )
        }
        .frame(height: 200)
        .cornerRadius(12)
        .allowsHitTesting(false)
    }
}
struct MapPinItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

