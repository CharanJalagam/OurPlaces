//
//  MemoriesGridView.swift
//  OurPlaces
//
//  "Relive" — a scrapbook-style masonry collage of a place's memory photos.
//

import SwiftUI

struct MemoriesGridView: View {
    let photos: [VisitImage]
    let place: Place

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex: Int? = nil

    private let hPad: CGFloat = 14
    private let colSpacing: CGFloat = 12

    // Balanced two-column masonry (assign each photo to the shorter column).
    private var split: (left: [Int], right: [Int]) {
        var left: [Int] = [], right: [Int] = []
        var lh: CGFloat = 0, rh: CGFloat = 0
        for i in photos.indices {
            let h = tileHeight(for: i)
            if lh <= rh { left.append(i); lh += h } else { right.append(i); rh += h }
        }
        return (left, right)
    }

    var body: some View {
        GeometryReader { geo in
            let columnWidth = (geo.size.width - hPad * 2 - colSpacing) / 2

            ZStack(alignment: .top) {
                background

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        header
                        HStack(alignment: .top, spacing: colSpacing) {
                            column(split.left, width: columnWidth)
                            column(split.right, width: columnWidth)
                        }
                        .padding(.horizontal, hPad)
                        .padding(.bottom, 40)
                    }
                }

                closeButton
            }
        }
        .fullScreenCover(item: $selectedIndex) { index in
            PhotosView(images: photos, place: place, startIndex: index)
        }
    }

    // MARK: - Pieces

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.96, blue: 0.93),
                Color(red: 0.96, green: 0.92, blue: 0.89)
            ],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.title3)
                .foregroundColor(Color(.appRed))

            Text("Your Memories")
                .font(.system(.largeTitle, design: .serif).weight(.bold))
                .foregroundColor(Color(red: 0.25, green: 0.18, blue: 0.15))

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(Color(red: 0.45, green: 0.38, blue: 0.34))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 64)
    }

    private var closeButton: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.25, green: 0.18, blue: 0.15))
                    .padding(12)
                    .background(Color.white, in: Circle())
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func column(_ indices: [Int], width: CGFloat) -> some View {
        VStack(spacing: 12) {
            ForEach(indices, id: \.self) { i in
                tile(photos[i], width: width, height: tileHeight(for: i))
                    .onTapGesture { selectedIndex = i }
            }
        }
        .frame(width: width)
    }

    private func tile(_ photo: VisitImage, width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(url: URL(string: photo.image_url)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .empty:
                    ZStack { Color.gray.opacity(0.15); ProgressView() }
                default:
                    ZStack { Color.gray.opacity(0.15); Image(systemName: "photo").foregroundStyle(.gray) }
                }
            }
            .frame(width: width, height: height)
            .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.55)],
                           startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 2) {
                if let caption = photo.caption, !caption.isEmpty {
                    Text("“\(caption)”")
                        .font(.system(.footnote, design: .serif).italic())
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
                Text(dateString(photo.created_at_millis))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(10)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
    }

    // MARK: - Helpers

    private var subtitle: String {
        let n = photos.count
        let noun = n == 1 ? "moment" : "moments"
        if let earliest = photos.map(\.created_at_millis).min() {
            let date = Date(timeIntervalSince1970: TimeInterval(earliest) / 1000)
            let f = DateFormatter(); f.dateFormat = "MMM yyyy"
            return "\(n) \(noun) at \(place.name)\nsince \(f.string(from: date))"
        }
        return "\(n) \(noun) at \(place.name)"
    }

    private func dateString(_ millis: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
        let f = DateFormatter(); f.dateFormat = "d MMM yyyy"
        return f.string(from: date)
    }

    /// Repeating height pattern for a natural, collage-like rhythm.
    private func tileHeight(for index: Int) -> CGFloat {
        let pattern: [CGFloat] = [210, 150, 240, 170, 200, 160]
        return pattern[index % pattern.count]
    }
}
