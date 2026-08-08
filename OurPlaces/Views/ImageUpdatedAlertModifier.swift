//
//  ImageUpdatedAlertModifier.swift
//  OurPlaces
//
//  Created by apple on 26/01/26.
//

import SwiftUI

struct MemorySavedPopup: View {
    
    let placeName: String
    let onDone: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            
            // Check Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.accent)
                .padding(.top, 12)
            
            Text("Memory Saved")
                .font(.title2)
                .fontWeight(.semibold)
            
            
            Text("Your memory at \(placeName) has been updated successfully.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                onDone()
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(.accent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(maxWidth: 320)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 20)
    }
}
struct PopupOverlay<PopupContent: View>: View {
    
    let popup: PopupContent
    
    var body: some View {
        ZStack {
            // Blur background (blocks all interactions)
            Rectangle()
                .fill(.black.opacity(0.35))
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
                .allowsHitTesting(true)
            
            popup
        }
    }
}
