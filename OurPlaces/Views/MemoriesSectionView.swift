//
//  MemoriesSectionView.swift
//  OurPlaces
//
//  "Your Memories" — a nostalgic polaroid strip of a place's visit photos.
//

import SwiftUI

struct MemoriesSectionView: View {

    let photos: [VisitImage]
    let place: Place
    @State private var selectedIndex: Int? = nil
    @State private var showGrid = false

    private var earliestMillis: Int64? { photos.map { $0.created_at_millis }.min() }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Memories")
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    showGrid = true
                } label: {
                    Label("Relive", systemImage: "heart.fill")
                        .font(.caption.bold())
                        .foregroundColor(Color(.appRed))
                }
                .fullScreenCover(isPresented: $showGrid) {
                    MemoriesGridView(photos: photos, place: place)
                }
            }

            // Polaroid strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                        PolaroidCard(photo: photo, angle: angle(for: index))
                            .onTapGesture { selectedIndex = index }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 10)   // breathing room for the rotated corners
            }
        }
        .fullScreenCover(item: $selectedIndex) { index in
            PhotosView(images: photos, place: place, startIndex: index)
        }
    }

    private var subtitle: String {
        let n = photos.count
        let noun = n == 1 ? "moment" : "moments"
        if let earliestMillis {
            let date = Date(timeIntervalSince1970: TimeInterval(earliestMillis) / 1000)
            let f = DateFormatter()
            f.dateFormat = "MMM yyyy"
            return "\(n) \(noun) • since \(f.string(from: date))"
        }
        return "\(n) \(noun)"
    }

    /// Gentle, repeating tilt so the photos feel scattered on a table.
    private func angle(for index: Int) -> Double {
        let angles = [-3.0, 2.5, -1.5, 3.0, -2.0]
        return angles[index % angles.count]
    }
}

// MARK: - Polaroid

struct PolaroidCard: View {
    let photo: VisitImage
    var angle: Double

    var body: some View {
        VStack(spacing: 8) {
            CachedAsyncImage(url: URL(string: photo.image_url)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .empty:
                    ZStack { Color.gray.opacity(0.2); ProgressView() }
                default:
                    ZStack { Color.gray.opacity(0.2); Image(systemName: "photo").foregroundStyle(.gray) }
                }
            }
            .frame(width: 128, height: 138)
            .clipped()

            VStack(spacing: 3) {
                if let caption = photo.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.system(.footnote, design: .serif).italic())
                        .foregroundColor(Color(red: 0.22, green: 0.16, blue: 0.13))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                Text(dateString)
                    .font(.system(.caption2, design: .serif))
                    .foregroundColor(Color(red: 0.5, green: 0.44, blue: 0.4))
                    .lineLimit(1)
            }
            .frame(width: 128)
        }
        .padding(8)
        .padding(.bottom, 6)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(0.18), radius: 4, y: 3)
        .rotationEffect(.degrees(angle))
    }

    private var dateString: String {
        let date = Date(timeIntervalSince1970: TimeInterval(photo.created_at_millis) / 1000)
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return f.string(from: date)
    }
}
