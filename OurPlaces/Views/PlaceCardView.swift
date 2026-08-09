//
//  PlaceCardView.swift
//  OurPlaces
//
//  Bottom sheet shown when a map pin is tapped: the place's photos + info,
//  its visit memories (if any), and a clear "Add a Visit" action.
//

import SwiftUI
import MapKit

struct PlaceCardView: View {

    let place: Place
    var onClose: () -> Void
    var onAddVisit: () -> Void
    var onEdit: () -> Void

    private let authVM = SupabaseAuthVM()
    @State private var isVisited = false
    @State private var memories: [VisitImage] = []

    private var placePhotos: [String] { place.image_urls ?? [] }
    private var trimmedDescription: String {
        (place.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack {
            Spacer()
            card
        }
        .task(id: place.id) { await load() }
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: 16) {
            handle
            hero

            if !trimmedDescription.isEmpty {
                Text(trimmedDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(4)
            }

            if isVisited && !memories.isEmpty {
                Divider()
                MemoriesSectionView(photos: memories, place: place)
            }

            actionButtons
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .padding()
    }

    private var handle: some View {
        ZStack {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
            HStack {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "square.and.pencil")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(.appRed))
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.gray.opacity(0.55))
                }
            }
        }
    }

    // MARK: - Hero (place photos + title)

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            if placePhotos.isEmpty {
                ZStack {
                    LinearGradient(
                        colors: [Color(.appRed).opacity(0.85), Color(.appRed)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Image(systemName: CategoryStore.icon(for: place.category))
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.9))
                }
            } else {
                TabView {
                    ForEach(placePhotos, id: \.self) { urlString in
                        CachedAsyncImage(url: URL(string: urlString)) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .empty:
                                ZStack { Color.gray.opacity(0.2); ProgressView() }
                            default:
                                ZStack {
                                    Color.gray.opacity(0.2)
                                    Image(systemName: "photo").foregroundStyle(.gray)
                                }
                            }
                        }
                        .clipped()
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: placePhotos.count > 1 ? .automatic : .never))
            }

            // Scrim so the title stays legible over any photo.
            LinearGradient(colors: [.clear, .black.opacity(0.6)],
                           startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 6) {
                if isVisited { visitedBadge }
                Text(place.name)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Image(systemName: CategoryStore.icon(for: place.category))
                    Text(place.category)
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
            }
            .padding(14)
        }
        .frame(height: 170)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var visitedBadge: some View {
        Label("Visited", systemImage: "checkmark.seal.fill")
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(.appRed), in: Capsule())
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: onAddVisit) {
                Label(isVisited ? "Add Another Visit" : "Add a Visit",
                      systemImage: "camera.fill")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 46)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(.appRed))

            Button {
                openAppleMapsDirections(
                    toLatitude: place.latitude,
                    longitude: place.longitude,
                    placeName: place.name
                )
            } label: {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(.bordered)
            .tint(.gray)
        }
    }

    // MARK: - Data

    private func load() async {
        isVisited = false
        memories = []
        do {
            let visited = try await authVM.isPlaceVisited(placeId: place.id)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) { isVisited = visited }
            }
            if visited {
                let imgs = (try? await authVM.fetchImagesForPlace(placeId: place.id)) ?? []
                await MainActor.run { memories = imgs }
            }
        } catch {
            print("PlaceCard load error:", error)
        }
    }

    private func openAppleMapsDirections(toLatitude lat: Double, longitude lon: Double, placeName: String) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = placeName
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}
