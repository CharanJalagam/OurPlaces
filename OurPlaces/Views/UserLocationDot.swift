//
//  UserLocationDot.swift
//  OurPlaces
//
//  Custom "you are here" indicator: a chosen emoji planted on the map, with a
//  brand-colored live-location radar pulse ringing out from its feet.
//

import SwiftUI

struct UserLocationDot: View {
    var emoji: String = "🧍🏼‍♂️"
    @State private var pulse = false

    var body: some View {
        VStack(spacing: -9) {
            Text(emoji)
                .font(.system(size: 32))

            // Ground contact: radar ping + a tight shadow right under the feet.
            ZStack {
                Circle()
                    .fill(Color(.appRed).opacity(0.5))
                    .frame(width: 20, height: 20)
                    .scaleEffect(pulse ? 2.8 : 0.5)   // scaleEffect doesn't change layout
                    .opacity(pulse ? 0 : 0.6)

                Ellipse()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 20, height: 6)
                    .blur(radius: 1.5)
            }
            .frame(width: 20, height: 10)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.9).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}
