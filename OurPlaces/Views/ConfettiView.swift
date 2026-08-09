//
//  ConfettiView.swift
//  OurPlaces
//
//  A lightweight, self-contained confetti burst (no dependencies).
//  Plays once when it appears — pieces fall, spin, drift, and fade out.
//

import SwiftUI

struct ConfettiView: View {
    var pieceCount: Int = 110
    @State private var isActive = false
    private let pieces: [ConfettiPiece]

    init(pieceCount: Int = 110) {
        self.pieceCount = pieceCount
        self.pieces = (0..<pieceCount).map { ConfettiPiece(id: $0) }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    piece.shape
                        .position(
                            x: geo.size.width * piece.startX + (isActive ? piece.drift : 0),
                            y: isActive ? geo.size.height + 60 : -60
                        )
                        .rotationEffect(.degrees(isActive ? piece.spin : 0))
                        .opacity(isActive ? 0 : 1)
                        .animation(
                            .easeIn(duration: piece.duration).delay(piece.delay),
                            value: isActive
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear { isActive = true }
    }
}

private struct ConfettiPiece: Identifiable {
    let id: Int
    let startX: CGFloat
    let drift: CGFloat
    let spin: Double
    let duration: Double
    let delay: Double
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let isCircle: Bool

    init(id: Int) {
        self.id = id
        startX = .random(in: 0.02...0.98)
        drift = .random(in: -80...80)
        spin = .random(in: 240...960) * (Bool.random() ? 1 : -1)
        duration = .random(in: 2.2...3.6)
        delay = .random(in: 0...0.5)
        let palette: [Color] = [Color(.appRed), .orange, .yellow, .pink, .purple, .teal, .mint, .blue]
        color = palette.randomElement() ?? Color(.appRed)
        let w = CGFloat.random(in: 6...11)
        width = w
        height = CGFloat.random(in: 9...16)
        isCircle = Bool.random()
    }

    @ViewBuilder
    var shape: some View {
        Group {
            if isCircle {
                Circle().fill(color).frame(width: width, height: width)
            } else {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(color)
                    .frame(width: width, height: height)
            }
        }
        .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
    }
}
