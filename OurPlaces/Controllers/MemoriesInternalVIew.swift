//
//  MemoriesInternalVIew.swift
//  OurPlaces
//
//  A place's memories for a specific visit:
//   • Polaroid — a swipeable stack of *this visit's* photos
//   • Grid     — *all* the place's photos, segregated by visit (newest first)
//

import SwiftUI
import CoreLocation

// MARK: - Shared palette (kept close to the app's asset colors)

private let memBackground     = Color("Background")
private let memCard           = Color.white
private let memHeading        = Color(red: 0.54, green: 0.09, blue: 0.13) // deep serif maroon
private let memAccent         = Color("AppRed")
private let memTextPrimary    = Color("TextPrimary")
private let memTextSecondary  = Color("TextSecondary")
private let memPlaceholder    = Color("AppSecondaryColor")

/// One visit's photos in the Grid, with a global offset into the flattened list.
private struct MemGridSection: Identifiable {
    let visitId: UUID
    let date: Date
    let images: [VisitImage]
    let startOffset: Int
    var id: UUID { visitId }
}

struct MemoriesInternalVIew: View {

    let visit: TimelineViewModel.VisitWithPlace

    @Environment(\.dismiss) private var dismiss

    @State private var polaroidImages: [VisitImage] = []   // this visit only
    @State private var gridSections: [MemGridSection] = []  // all visits, grouped
    @State private var totalPhotos = 0
    @State private var showLoader = true
    @State private var visitCount = 0
    @State private var mode: DisplayMode = .polaroid
    @State private var selectedIndex: Int? = nil
    @State private var topIndex = 0            // front polaroid → drives the footer date
    @State private var city: String? = nil     // reverse-geocoded

    @Namespace private var pickerNS

    private let supabase = SupabaseAuthVM()
    private let vm = MemoriesViewModel()

    /// When non-nil, the network fetch is skipped (used by previews).
    private let injectedImages: [VisitImage]?

    init(visit: TimelineViewModel.VisitWithPlace,
         previewImages: [VisitImage]? = nil,
         previewVisitCount: Int = 0) {
        self.visit = visit
        self.injectedImages = previewImages
        _polaroidImages = State(initialValue: previewImages ?? [])
        if let imgs = previewImages {
            _gridSections = State(initialValue: [
                MemGridSection(visitId: visit.id, date: visit.visitDate, images: imgs, startOffset: 0)
            ])
            _totalPhotos = State(initialValue: imgs.count)
        } else {
            _gridSections = State(initialValue: [])
            _totalPhotos = State(initialValue: 0)
        }
        _showLoader = State(initialValue: previewImages == nil)
        _visitCount = State(initialValue: previewVisitCount)
    }

    enum DisplayMode: String, CaseIterable, Identifiable {
        case polaroid = "Polaroid"
        case grid = "Grid"
        var id: String { rawValue }
    }

    /// Photos backing the full-screen viewer for the current mode.
    private var activeImages: [VisitImage] {
        mode == .polaroid ? polaroidImages : gridSections.flatMap(\.images)
    }

    // MARK: Body

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top

            ZStack(alignment: .top) {
                memBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    header(topInset: topInset)
                    statsRow
                    modePicker
                    mainContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .fullScreenCover(item: $selectedIndex) { index in
            PhotosView(images: activeImages, place: visit.place, startIndex: index)
        }
        .task {
            if injectedImages == nil {
                await loadImages()
                await loadCount()
            }
            await resolveCity()
        }
    }

    // MARK: - Header

    private func header(topInset: CGFloat) -> some View {
        ZStack(alignment: .top) {
            headerImage
                .frame(height: topInset + 84)
                .frame(maxWidth: .infinity)
                .clipped()
                .opacity(0.6)
                .overlay(
                    LinearGradient(
                        colors: [
                            memBackground.opacity(0.0),
                            memBackground.opacity(0.35),
                            memBackground
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            HStack(spacing: 8) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(memAccent)
                        .frame(width: 40, height: 40)
                }
                .glassEffect(.regular.interactive(), in: Circle())

                Spacer(minLength: 0)
            }
            .overlay(
                Text(visit.place.name)
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(memHeading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 52)
            )
            .padding(.horizontal, 16)
            .padding(.top, topInset + 2)
        }
        .frame(height: topInset + 84)
    }

    @ViewBuilder
    private var headerImage: some View {
        if let first = visit.place.image_urls?.first, let url = URL(string: first) {
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    memPlaceholder
                }
            }
        } else {
            memPlaceholder
        }
    }

    // MARK: - Stats (adapts to the mode)

    private var statsRow: some View {
        HStack(spacing: 6) {
            if mode == .polaroid {
                boldNumber(polaroidImages.count)
                Text(polaroidImages.count == 1 ? "photo" : "photos")
                    .foregroundStyle(memTextSecondary)
                dot
                Text(dateText(visit.visitDate))
                    .foregroundStyle(memTextSecondary)
            } else {
                boldNumber(visitCount)
                Text(visitCount == 1 ? "visit" : "visits")
                    .foregroundStyle(memTextSecondary)
                dot
                boldNumber(totalPhotos)
                Text(totalPhotos == 1 ? "photo" : "photos")
                    .foregroundStyle(memTextSecondary)
            }
        }
        .font(.subheadline)
        .padding(.top, 2)
        .padding(.bottom, 12)
        .animation(.easeInOut(duration: 0.2), value: mode)
    }

    private func boldNumber(_ value: Int) -> some View {
        Text("\(value)").fontWeight(.bold).foregroundStyle(memHeading)
    }

    private var dot: some View {
        Text("·").foregroundStyle(memTextSecondary.opacity(0.6))
    }

    // MARK: - Mode picker

    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(DisplayMode.allCases) { m in
                let selected = m == mode
                Text(m.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selected ? .white : memTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if selected {
                            Capsule()
                                .fill(memAccent)
                                .matchedGeometryEffect(id: "segment", in: pickerNS)
                        }
                    }
                    .contentShape(Capsule())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            mode = m
                        }
                    }
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(memCard)
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        )
        .frame(width: 240)
        .padding(.bottom, 6)
    }

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        if showLoader {
            VStack { Spacer(); ProgressView().tint(memAccent); Spacer() }
        } else {
            Group {
                switch mode {
                case .polaroid:
                    if polaroidImages.isEmpty {
                        emptyState("No photos from this visit")
                    } else {
                        polaroidSection
                    }
                case .grid:
                    if gridSections.isEmpty {
                        emptyState("No memories yet")
                    } else {
                        gridSection
                    }
                }
            }
            .transition(.opacity)
        }
    }

    private func emptyState(_ text: String) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.largeTitle)
                .foregroundStyle(memTextSecondary.opacity(0.6))
            Text(text)
                .foregroundStyle(memTextSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Polaroid section (this visit)

    private var polaroidSection: some View {
        GeometryReader { geo in
            let cardW = min(geo.size.width * 0.72, 300)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                PolaroidStack(
                    images: polaroidImages,
                    cardWidth: cardW,
                    currentIndex: $topIndex,
                    onTapTop: { selectedIndex = $0 }
                )

                if polaroidImages.count > 1 {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.draw")
                        Text("Swipe")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(memAccent.opacity(0.75))
                    .padding(.top, 14)
                }

                Spacer(minLength: 0)

                polaroidFooter
                    .padding(.bottom, 24)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var polaroidFooter: some View {
        VStack(spacing: 8) {
            Text(fullDate(polaroidImages[safe: topIndex]?.created_at_millis))
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(memHeading)
                .contentTransition(.opacity)

            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(memAccent)
                Text(locationLine)
                    .foregroundStyle(memTextPrimary)
            }
            .font(.subheadline)
        }
        .animation(.easeInOut(duration: 0.25), value: topIndex)
    }

    // MARK: - Grid section (all visits, segregated)

    private var gridSection: some View {
        GeometryReader { geo in
            let hPad: CGFloat = 14
            let gutter: CGFloat = 12
            let colW = (geo.size.width - hPad * 2 - gutter) / 2

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 26) {
                    ForEach(gridSections) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(section)
                                .padding(.horizontal, hPad)

                            sectionMasonry(section, columnWidth: colW, gutter: gutter)
                                .padding(.horizontal, hPad)
                        }
                    }
                }
                .padding(.top, 14)
                .padding(.bottom, 36)
            }
        }
    }

    private func sectionHeader(_ section: MemGridSection) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(dateText(section.date))
                .font(.system(.headline, design: .serif))
                .foregroundStyle(memHeading)
            Spacer()
            Text("\(section.images.count) \(section.images.count == 1 ? "photo" : "photos")")
                .font(.caption)
                .foregroundStyle(memTextSecondary)
        }
    }

    private func sectionMasonry(_ section: MemGridSection,
                                columnWidth: CGFloat, gutter: CGFloat) -> some View {
        let cols = balanced(section.images, width: columnWidth)
        return HStack(alignment: .top, spacing: gutter) {
            column(section, cols.left, width: columnWidth)
            column(section, cols.right, width: columnWidth)
        }
    }

    private func column(_ section: MemGridSection, _ local: [Int], width: CGFloat) -> some View {
        LazyVStack(spacing: 16) {
            ForEach(local, id: \.self) { i in
                gridTile(section.images[i], index: i, width: width)
                    .onTapGesture { selectedIndex = section.startOffset + i }
            }
        }
    }

    private func gridTile(_ image: VisitImage, index: Int, width: CGFloat) -> some View {
        // Every photo is a framed polaroid; note-less photos get a slimmer caption strip.
        let hasCaption = !(image.caption ?? "").isEmpty
        let side = width - 20

        return VStack(spacing: 6) {
            gridImage(image, width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 3))

            VStack(spacing: 3) {
                if let caption = image.caption, hasCaption {
                    Text(caption)
                        .font(.system(.footnote, design: .serif).italic())
                        .foregroundStyle(memTextSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }

                Text(relativeDate(image.created_at_millis))
                    .font(.caption2)
                    .foregroundStyle(memTextSecondary.opacity(0.75))
            }
            .frame(width: side)
        }
        .padding(10)
        .padding(.bottom, hasCaption ? 6 : 2)
        .background(memCard)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: memAccent.opacity(0.16), radius: 4, y: 5)
        .rotationEffect(.degrees(index % 2 == 0 ? -2 : 1.5))
    }

    private func gridImage(_ image: VisitImage, width: CGFloat, height: CGFloat) -> some View {
        CachedAsyncImage(url: URL(string: image.image_url)) { phase in
            switch phase {
            case .success(let loaded):
                loaded.resizable().scaledToFill()
            case .empty:
                ZStack { memPlaceholder; ProgressView().tint(memAccent) }
            default:
                ZStack { memPlaceholder; Image(systemName: "photo").foregroundStyle(.gray) }
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }

    // MARK: - Masonry balancing (per section)

    private func balanced(_ imgs: [VisitImage], width: CGFloat) -> (left: [Int], right: [Int]) {
        var left: [Int] = [], right: [Int] = []
        var lh: CGFloat = 0, rh: CGFloat = 0
        for i in imgs.indices {
            let h = tileHeight(imgs[i], width: width)
            if lh <= rh { left.append(i); lh += h } else { right.append(i); rh += h }
        }
        return (left, right)
    }

    private func tileHeight(_ image: VisitImage, width: CGFloat) -> CGFloat {
        let side = width - 20
        let base = side + 16 + 14            // image + top padding + spacing + date line
        if let caption = image.caption, !caption.isEmpty {
            return base + 34 + 6             // + caption strip + bottom padding
        }
        return base + 2                      // slimmer strip when note-less
    }

    // MARK: - Data

    private func loadImages() async {
        showLoader = true
        do {
            let all = try await supabase.fetchPlaceImagesWithVisit(placeId: visit.place.id)
            totalPhotos = all.count

            // Polaroid: only this visit's photos.
            polaroidImages = all
                .filter { $0.visit_id == visit.id }
                .map { VisitImage(image_url: $0.image_url, created_at_millis: $0.created_at_millis, caption: $0.caption) }

            // Grid: group by visit, newest visit first.
            let grouped = Dictionary(grouping: all, by: { $0.visit_id })
            let sections = grouped.compactMap { (vid, rows) -> MemGridSection? in
                guard let first = rows.first else { return nil }
                let date = Date(timeIntervalSince1970: TimeInterval(first.visited_at_millis) / 1000)
                let images = rows
                    .sorted { $0.created_at_millis > $1.created_at_millis }
                    .map { VisitImage(image_url: $0.image_url, created_at_millis: $0.created_at_millis, caption: $0.caption) }
                return MemGridSection(visitId: vid, date: date, images: images, startOffset: 0)
            }
            .sorted { $0.date > $1.date }

            var offset = 0
            gridSections = sections.map { s in
                let out = MemGridSection(visitId: s.visitId, date: s.date, images: s.images, startOffset: offset)
                offset += s.images.count
                return out
            }
        } catch {
            polaroidImages = []
            gridSections = []
            totalPhotos = 0
        }
        topIndex = 0
        showLoader = false
    }

    private func loadCount() async {
        let visits = await vm.fetchPlaceVisitCounts()
        visitCount = visits[visit.place.id] ?? 0
    }

    private func resolveCity() async {
        let location = CLLocation(latitude: visit.place.latitude, longitude: visit.place.longitude)
        if let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first {
            let resolved = placemark.locality
                ?? placemark.subAdministrativeArea
                ?? placemark.administrativeArea
            if let resolved, !resolved.isEmpty {
                city = resolved
            }
        }
    }

    private var locationLine: String {
        if let city, !city.isEmpty { return "\(visit.place.name), \(city)" }
        return visit.place.name
    }

    private func fullDate(_ millis: Int64?) -> String {
        guard let millis else { return "" }
        return dateText(Date(timeIntervalSince1970: TimeInterval(millis) / 1000))
    }

    private func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter.string(from: date)
    }

    private func relativeDate(_ millis: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Polaroid Stack

private struct PolaroidStack: View {

    let images: [VisitImage]
    let cardWidth: CGFloat
    @Binding var currentIndex: Int
    let onTapTop: (Int) -> Void

    @State private var order: [Int] = []
    @State private var drag: CGSize = .zero

    private let maxVisible = 3
    private let backYOffset: [CGFloat] = [0, -10, -18]
    private let backScale:   [CGFloat] = [1.0, 0.95, 0.90]
    private let backRotation: [Double] = [0, 3.5, -4]

    private var cardHeight: CGFloat { (cardWidth - 20) + 76 }

    var body: some View {
        ZStack {
            ForEach(Array(order.enumerated()), id: \.element) { pos, imgIndex in
                if pos < maxVisible {
                    card(imgIndex: imgIndex, pos: pos)
                }
            }
        }
        .frame(width: cardWidth, height: cardHeight + 24)
        .onAppear {
            if order.isEmpty {
                order = Array(images.indices)
                currentIndex = order.first ?? 0
            }
        }
    }

    private func card(imgIndex: Int, pos: Int) -> some View {
        let isTop = pos == 0
        let draggable = isTop && images.count > 1

        return PolaroidPhotoCard(image: images[imgIndex], width: cardWidth)
            .scaleEffect(isTop ? 1 : backScale[pos])
            .rotationEffect(.degrees(isTop ? Double(drag.width / 22) : backRotation[pos]))
            .offset(
                x: isTop ? drag.width : 0,
                y: isTop ? drag.height * 0.12 : backYOffset[pos]
            )
            .zIndex(Double(order.count - pos))
            .allowsHitTesting(isTop)
            .onTapGesture { if isTop { onTapTop(imgIndex) } }
            .gesture(draggable ? dragGesture : nil)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                drag = value.translation
            }
            .onEnded { value in
                if abs(value.translation.width) > 110 {
                    let direction: CGFloat = value.translation.width > 0 ? 1 : -1
                    withAnimation(.easeOut(duration: 0.28)) {
                        drag = CGSize(width: direction * 800, height: value.translation.height)
                    } completion: {
                        advance()
                    }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        drag = .zero
                    }
                }
            }
    }

    /// Cycle the swiped card to the back instantly (it's off-screen, so the swap is invisible).
    private func advance() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            let first = order.removeFirst()
            order.append(first)
            drag = .zero
            currentIndex = order.first ?? 0
        }
    }
}

// MARK: - Polaroid Card

private struct PolaroidPhotoCard: View {

    let image: VisitImage
    let width: CGFloat

    var body: some View {
        let side = width - 20
        let hasCaption = !(image.caption ?? "").isEmpty

        VStack(spacing: hasCaption ? 8 : 0) {
            CachedAsyncImage(url: URL(string: image.image_url)) { phase in
                switch phase {
                case .success(let loaded):
                    loaded.resizable().scaledToFill()
                case .empty:
                    ZStack { memPlaceholder; ProgressView().tint(memAccent) }
                default:
                    ZStack { memPlaceholder; Image(systemName: "photo").foregroundStyle(.gray) }
                }
            }
            .frame(width: side, height: side)
            .clipped()

            if let caption = image.caption, hasCaption {
                Text(caption)
                    .font(.system(.subheadline, design: .serif).italic())
                    .foregroundStyle(memTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: side, height: 30)
            }
        }
        .padding(10)
        .padding(.bottom, hasCaption ? 8 : 22)
        .background(memCard)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: memAccent.opacity(0.2), radius: 7, y: 9)
    }
}

// MARK: - Helpers

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Int: Identifiable {
    public var id: Int { self }
}

// MARK: - Preview

#Preview {
    let place = Place(
        id: UUID(),
        name: "Dolores Park",
        rating: 4.8,
        rating_count: 210,
        description: "Golden-hour picnics.",
        category: "Park",
        latitude: 37.7596,
        longitude: -122.4269,
        phone_number: nil,
        email: nil,
        website: nil,
        image_urls: ["https://picsum.photos/id/1018/900/600"],
        is_visited: true,
        is_private: false,
        created_at: "2023-09-05"
    )

    let visit = TimelineViewModel.VisitWithPlace(
        id: UUID(),
        visitDate: Date(timeIntervalSince1970: 1_693_872_000),
        place: place,
        photos: []
    )

    let images: [VisitImage] = [
        VisitImage(image_url: "https://picsum.photos/id/1025/700/700", created_at_millis: 1_693_872_000_000, caption: nil),
        VisitImage(image_url: "https://picsum.photos/id/1039/700/700", created_at_millis: 1_693_785_600_000, caption: "Dolores Park, SF — Golden Hour Glow"),
        VisitImage(image_url: "https://picsum.photos/id/1043/700/700", created_at_millis: 1_693_699_200_000, caption: nil),
        VisitImage(image_url: "https://picsum.photos/id/1062/700/700", created_at_millis: 1_693_612_800_000, caption: "Sunny fetch — Golden Gate Park, 2008"),
        VisitImage(image_url: "https://picsum.photos/id/1074/700/700", created_at_millis: 1_693_526_400_000, caption: nil),
        VisitImage(image_url: "https://picsum.photos/id/1084/700/700", created_at_millis: 1_693_440_000_000, caption: nil)
    ]

    return NavigationStack {
        MemoriesInternalVIew(visit: visit, previewImages: images, previewVisitCount: 3)
    }
}
