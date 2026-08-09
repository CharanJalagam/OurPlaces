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
    @State private var pop = false

    var body: some View {
        VStack(spacing: 18) {

            // Hero
            ZStack {
                Circle()
                    .fill(Color(.appRed).opacity(0.12))
                    .frame(width: 84, height: 84)
                Image(systemName: "heart.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(Color(.appRed))
                    .scaleEffect(pop ? 1 : 0.5)
            }
            .padding(.top, 6)

            VStack(spacing: 6) {
                Text("Memory Saved")
                    .font(.system(.title2, design: .serif).weight(.bold))

                Text("Your moment at \(placeName) is now on your map.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                onDone()
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(.appRed), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundColor(.white)
            }
            .shadow(color: Color(.appRed).opacity(0.25), radius: 8, y: 5)
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
        .sensoryFeedback(.success, trigger: pop)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.05)) {
                pop = true
            }
        }
    }
}
struct PopupOverlay<PopupContent: View>: View {

    let popup: PopupContent
    @State private var shown = false

    var body: some View {
        ZStack {
            // Dim backdrop fades in softly (no blur, no scaling).
            Color.black
                .opacity(shown ? 0.35 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(true)
                .animation(.easeOut(duration: 0.25), value: shown)

            // Card springs in on top.
            popup
                .scaleEffect(shown ? 1 : 0.92)
                .opacity(shown ? 1 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.72), value: shown)
        }
        .onAppear { shown = true }
    }
}
