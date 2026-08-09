//
//  EmojiPickerButton.swift
//  OurPlaces
//
//  A round button showing the current location-indicator emoji. Tapping it
//  slides out a full-width glass strip of emoji choices; picking one updates
//  the indicator and collapses back to the button.
//

import SwiftUI

struct EmojiPickerButton: View {
    @Binding var selected: String
    let options: [String]

    @State private var expanded = false

    var body: some View {
        HStack(spacing: 0) {
            if expanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(options, id: \.self) { emoji in
                            Button {
                                selected = emoji
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                                    expanded = false
                                }
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 28))
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .fill(selected == emoji
                                                  ? Color(.appRed).opacity(0.22)
                                                  : Color.clear)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .glassEffect(.regular, in: Capsule())
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                Spacer(minLength: 0)
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                        expanded = true
                    }
                } label: {
                    Text(selected)
                        .font(.system(size: 24))
                        .frame(width: 52, height: 52)
                }
                .glassEffect(.regular.interactive(), in: Circle())
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}
