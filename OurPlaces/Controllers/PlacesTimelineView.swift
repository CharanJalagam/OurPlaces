//
//  PlacesTimelineView.swift
//  OurPlaces
//
//  The "Memories" tab — a Grove-style memory tree:
//   • Empty state  → "Your tree is just beginning"
//   • Populated    → a meandering vine with polaroid memories alternating sides,
//                    "X months later…" markers across large time gaps
//   • Bottom       → "Where it all began" — the origin / first memory
//

import SwiftUI

// MARK: - Palette & type (built-in iOS fonts, app colors)

private let treeCoral      = Color("AppRed")
private let treeBackground = Color("Background")
private let treeCard       = Color.white
private let treeInk        = Color("TextPrimary")
private let treeInkSoft    = Color("TextSecondary")
private let treeMaroon     = Color(red: 0.54, green: 0.09, blue: 0.13)

/// Casual handwriting for place names / dates (Caveat stand-in).
private func handFont(_ size: CGFloat) -> Font { .custom("Bradley Hand", size: size) }
/// High-contrast display serif for headlines (Playfair stand-in).
private func serifFont(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
    .custom("Didot", size: size).weight(weight)
}

// MARK: - Helpers

private func dateLabel(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "MMM dd, yyyy"
    return f.string(from: date)
}

/// A "much of a gap" label between two memories, or nil when they're close together.
private func gapLabel(from older: Date, to newer: Date) -> String? {
    let comps = Calendar.current.dateComponents([.year, .month], from: older, to: newer)
    let months = (comps.year ?? 0) * 12 + (comps.month ?? 0)
    let years = months / 12
    if years >= 1 {
        return "\(years) year\(years == 1 ? "" : "s") later…"
    } else if months >= 2 {
        return "\(months) months later…"
    }
    return nil
}

private func coverURL(for memory: TimelineViewModel.VisitWithPlace) -> URL? {
    if let s = memory.place.image_urls?.first, let u = URL(string: s) { return u }
    if let s = memory.photos.first?.image_url, let u = URL(string: s) { return u }
    return nil
}

// MARK: - Root view

struct TimelineView: View {

    @StateObject private var viewModel = TimelineViewModel()
    @State private var selected: TimelineViewModel.VisitWithPlace?

    /// When non-nil the network fetch is skipped and these are shown (previews only).
    private let previewMemories: [TimelineViewModel.VisitWithPlace]?

    init(previewMemories: [TimelineViewModel.VisitWithPlace]? = nil) {
        self.previewMemories = previewMemories
    }

    /// Flattened newest → oldest.
    private var memories: [TimelineViewModel.VisitWithPlace] {
        viewModel.groupedVisits.flatMap(\.visits).sorted { $0.visitDate > $1.visitDate }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                treeBackground.ignoresSafeArea()
                DotGridBackground()

                VStack(spacing: 0) {
                    MemoriesHeader()
                    stateContent
                }
            }
            .navigationDestination(item: $selected) { visit in
                MemoriesInternalVIew(visit: visit)
            }
            .task {
                if let previewMemories {
                    viewModel.groupedVisits = [(Calendar.current.startOfDay(for: Date()), previewMemories)]
                } else {
                    await viewModel.fetchTimeline()
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var stateContent: some View {
        if memories.isEmpty {
            if viewModel.isLoading {
                VStack { Spacer(); ProgressView().tint(treeCoral); Spacer() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                MemoriesEmptyState()
            }
        } else {
            MemoryTree(
                memories: memories,
                onTap: { selected = $0 },
                onRefresh: { await viewModel.fetchTimeline() }
            )
        }
    }
}

// MARK: - Header

private struct MemoriesHeader: View {
    var body: some View {
        HStack {
            Image(systemName: "leaf.fill")
                .font(.title3)
                .foregroundStyle(treeCoral)
                .frame(width: 40, height: 40)

            Spacer()

            Text("Memories")
                .font(serifFont(28))
                .foregroundStyle(treeMaroon)

            Spacer()

            Circle()
                .fill(treeCoral.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: "person.fill").foregroundStyle(treeCoral))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Empty state

private struct MemoriesEmptyState: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(treeCoral.opacity(0.10))
                    .frame(width: 200, height: 200)
                    .overlay(
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(treeCoral.opacity(0.85))
                    )

                Circle()
                    .fill(treeCard)
                    .frame(width: 56, height: 56)
                    .overlay(Image(systemName: "sparkles").foregroundStyle(treeMaroon))
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                    .offset(x: 6, y: 6)
            }
            .padding(.bottom, 36)

            Text("Your tree is just beginning")
                .font(serifFont(30))
                .foregroundStyle(treeInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text("Add your first shared memory to see your tree grow.")
                .font(.system(size: 17))
                .foregroundStyle(treeInkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
                .padding(.top, 12)

            Button { } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle")
                    Text("Grow").font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 34)
                .padding(.vertical, 15)
                .background(Capsule().fill(treeCoral))
            }
            .padding(.top, 30)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Memory tree

private struct MemoryTree: View {
    let memories: [TimelineViewModel.VisitWithPlace]
    let onTap: (TimelineViewModel.VisitWithPlace) -> Void
    let onRefresh: () async -> Void

    private let rotations: [Double] = [-3, 2, -5, 4, -2, 5]
    private let tapeRotations: [Double] = [-6, 8, -12, 10]

    /// Distinct calendar years that have a memory.
    private var yearsGrowth: Int {
        Set(memories.map { Calendar.current.component(.year, from: $0.visitDate) }).count
    }

    /// All photos across every visit, combined.
    private var totalPhotos: Int {
        memories.reduce(0) { $0 + $1.photos.count }
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    nodes(width: width)
                    OriginSection(first: memories.last, onTap: onTap)
                        .padding(.bottom, 130) // clear the FAB + tab bar
                }
            }
            .refreshable { await onRefresh() }
        }
    }

    private func nodes(width: CGFloat) -> some View {
        VStack(spacing: 30) {
            MemoryStatsCard(
                visits: "\(memories.count)",
                years: "\(yearsGrowth)",
                memories: "\(totalPhotos)"
            )
            .padding(.bottom, 4)

            ForEach(Array(memories.enumerated()), id: \.element.id) { index, memory in
                nodeRow(memory, index: index, width: width)
                if let gap = gapAfter(index) {
                    gapMarker(gap)
                }
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 20)
        .background(VineView())
    }

    private func nodeRow(_ memory: TimelineViewModel.VisitWithPlace,
                         index: Int, width: CGFloat) -> some View {
        let isLeft = index % 2 == 0
        let cardW = min(width * 0.42, 172)

        return HStack(spacing: 0) {
            if !isLeft { Spacer(minLength: 0) }

            PolaroidNode(
                memory: memory,
                cardWidth: cardW,
                rotation: rotations[index % rotations.count],
                tapeRotation: tapeRotations[index % tapeRotations.count]
            )
            .contentShape(Rectangle())
            .onTapGesture { onTap(memory) }
            .frame(width: width * 0.5, alignment: isLeft ? .trailing : .leading)

            if isLeft { Spacer(minLength: 0) }
        }
        .padding(.horizontal, 14)
    }

    private func gapMarker(_ label: String) -> some View {
        VStack(spacing: 6) {
            Capsule().fill(treeCoral.opacity(0.3)).frame(width: 60, height: 3).blur(radius: 0.5)
            Text(label)
                .font(handFont(18)).italic()
                .foregroundStyle(treeCoral.opacity(0.65))
            Capsule().fill(treeCoral.opacity(0.2)).frame(width: 44, height: 3).blur(radius: 0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private func gapAfter(_ index: Int) -> String? {
        guard index + 1 < memories.count else { return nil }
        return gapLabel(from: memories[index + 1].visitDate, to: memories[index].visitDate)
    }
}

// MARK: - Stats summary card

private struct MemoryStatsCard: View {
    let visits: String
    let years: String
    let memories: String

    var body: some View {
        HStack(spacing: 0) {
            stat(visits, "Visits")
            divider
            stat(years, "Years Growth")
            divider
            stat(memories, "Memories")
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(treeCard)
                .shadow(color: treeCoral.opacity(0.12), radius: 20, y: 8)
        )
        .padding(.horizontal, 20)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(serifFont(28))
                .foregroundStyle(treeCoral)
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(treeInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(treeCoral.opacity(0.25))
            .frame(width: 1, height: 44)
    }
}

// MARK: - Polaroid node

private struct PolaroidNode: View {
    let memory: TimelineViewModel.VisitWithPlace
    let cardWidth: CGFloat
    let rotation: Double
    let tapeRotation: Double

    var body: some View {
        let side = cardWidth - 20

        VStack(spacing: 6) {
            polaroid(side: side)
                .rotationEffect(.degrees(rotation))

            Text(dateLabel(memory.visitDate))
                .font(handFont(19))
                .foregroundStyle(treeCoral.opacity(0.85))
        }
    }

    private func polaroid(side: CGFloat) -> some View {
        VStack(spacing: 8) {
            CachedAsyncImage(url: coverURL(for: memory)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                case .empty:
                    ZStack { treeCoral.opacity(0.08); ProgressView().tint(treeCoral) }
                default:
                    ZStack { treeCoral.opacity(0.08); Image(systemName: "photo").foregroundStyle(treeCoral.opacity(0.5)) }
                }
            }
            .frame(width: side, height: side)
            .clipped()

            Text(memory.place.name)
                .font(handFont(min(26, cardWidth * 0.15)))
                .foregroundStyle(treeCoral)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: side)
        }
        .padding(10)
        .padding(.bottom, 4)
        .background(treeCard)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(treeCoral.opacity(0.18))
                .frame(width: 46, height: 20)
                .overlay(Rectangle().stroke(treeCoral.opacity(0.3), lineWidth: 0.5))
                .rotationEffect(.degrees(tapeRotation))
                .offset(y: -8)
        }
        .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
    }
}

// MARK: - Origin ("Where it all began")

private struct OriginSection: View {
    let first: TimelineViewModel.VisitWithPlace?
    let onTap: (TimelineViewModel.VisitWithPlace) -> Void

    var body: some View {
        VStack(spacing: 20) {
            RootsGraphic()
                .frame(width: 220, height: 210)

            VStack(spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                    Text("PLANTING DAY").tracking(1)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(treeMaroon)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Capsule().fill(treeCoral.opacity(0.12)))

                Text("Where it all began")
                    .font(serifFont(32))
                    .foregroundStyle(treeInk)
                    .multilineTextAlignment(.center)

                Text("Every grand journey starts from a single moment. Here lies the quiet beginning of your shared story.")
                    .font(.system(size: 16))
                    .foregroundStyle(treeInkSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 30)

                if let first {
                    firstMemoryCard(first).padding(.top, 6)
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
    }

    private func firstMemoryCard(_ memory: TimelineViewModel.VisitWithPlace) -> some View {
        HStack(spacing: 14) {
            CachedAsyncImage(url: coverURL(for: memory)) { phase in
                if case .success(let img) = phase {
                    img.resizable().scaledToFill()
                } else {
                    treeCoral.opacity(0.08)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text("OUR FIRST MEMORY")
                    .font(.system(size: 11, weight: .semibold)).tracking(1)
                    .foregroundStyle(treeCoral)
                Text(memory.place.name)
                    .font(serifFont(18))
                    .foregroundStyle(treeInk)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(treeCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
        .rotationEffect(.degrees(-2))
        .contentShape(Rectangle())
        .onTapGesture { onTap(memory) }
    }
}

// MARK: - Roots graphic

private struct RootsGraphic: View {
    var body: some View {
        Canvas { context, size in
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x / 200 * size.width, y: y / 220 * size.height)
            }

            // A touch bolder than the vine (wider + more opaque) so the roots anchor
            // the origin, while still reading as the same line.
            let line = StrokeStyle(lineWidth: 3, lineCap: .round)

            // Trunk continues straight from the vine, then flows into the taproot + seed.
            var main = Path()
            main.move(to: pt(100, 0))
            main.addLine(to: pt(100, 60))
            main.addCurve(to: pt(100, 150), control1: pt(99, 100), control2: pt(102, 125))
            main.addCurve(to: pt(100, 200), control1: pt(106, 172), control2: pt(96, 190))
            context.stroke(main, with: .color(treeCoral.opacity(0.72)), style: line)

            // Left root.
            var left = Path()
            left.move(to: pt(100, 62))
            left.addCurve(to: pt(32, 178), control1: pt(90, 100), control2: pt(50, 145))
            context.stroke(left, with: .color(treeCoral.opacity(0.72)), style: line)

            // Right root (dashed, for a subtle hand-drawn feel).
            var right = Path()
            right.move(to: pt(100, 62))
            right.addCurve(to: pt(168, 172), control1: pt(110, 100), control2: pt(150, 145))
            context.stroke(right, with: .color(treeCoral.opacity(0.6)),
                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [7, 5]))

            // Seed node.
            let seed = pt(100, 200)
            let r: CGFloat = 6
            context.fill(
                Path(ellipseIn: CGRect(x: seed.x - r, y: seed.y - r, width: 2 * r, height: 2 * r)),
                with: .color(treeCoral.opacity(0.8))
            )
        }
    }
}

// MARK: - Meandering vine (behind the nodes)

private struct VineView: View {
    var body: some View {
        Canvas { context, size in
            let midX = size.width / 2
            let amp: CGFloat = 14
            let wave: CGFloat = 260

            // Meander that eases to dead-center at the top and bottom so it flows
            // straight into the header above and the roots trunk below.
            func offset(at y: CGFloat) -> CGFloat {
                let t = min(max(y / max(size.height, 1), 0), 1)
                let taper = sin(Double(t) * .pi)
                return CGFloat(sin(Double(y / wave) * 2 * .pi) * taper) * amp
            }

            var path = Path()
            path.move(to: CGPoint(x: midX, y: 0))
            var y: CGFloat = 0
            while y <= size.height {
                path.addLine(to: CGPoint(x: midX + offset(at: y), y: y))
                y += 8
            }
            context.stroke(path, with: .color(treeCoral.opacity(0.5)),
                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

            // Leaves along the vine, alternating to the left and right of it.
            var ly: CGFloat = 60
            var i = 0
            while ly < size.height - 30 {
                let lx = midX + offset(at: ly)
                let toLeft = (i % 2 == 1)
                var leaf = context
                leaf.translateBy(x: lx, y: ly)
                leaf.rotate(by: .degrees(toLeft ? -35 : 35))
                let rect = toLeft
                    ? CGRect(x: -15, y: -3.75, width: 15, height: 7.5)
                    : CGRect(x: 0, y: -3.75, width: 15, height: 7.5)
                leaf.fill(Path(ellipseIn: rect), with: .color(treeCoral.opacity(0.45)))
                ly += 78
                i += 1
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Dotted paper background

private struct DotGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 24
            let r: CGFloat = 1.1
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                        with: .color(treeCoral.opacity(0.10))
                    )
                    x += spacing
                }
                y += spacing
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Previews

private func previewPlace(_ name: String, _ image: String, _ lat: Double, _ lon: Double) -> Place {
    Place(
        id: UUID(), name: name, rating: 4.7, rating_count: 88,
        description: nil, category: "Park",
        latitude: lat, longitude: lon,
        phone_number: nil, email: nil, website: nil,
        image_urls: [image], is_visited: true, is_private: false,
        created_at: "2023-01-01"
    )
}

private func previewMemory(_ name: String, _ image: String, daysAgo: Int,
                           lat: Double, lon: Double, photos: Int) -> TimelineViewModel.VisitWithPlace {
    let id = UUID()
    let pics = (0..<photos).map { _ in
        Photo(id: UUID(), image_url: image, created_at_millis: 0, visit_id: id)
    }
    return TimelineViewModel.VisitWithPlace(
        id: id,
        visitDate: Date(timeIntervalSinceNow: -Double(daysAgo) * 86_400),
        place: previewPlace(name, image, lat, lon),
        photos: pics
    )
}

#Preview("Memory Tree") {
    TimelineView(previewMemories: [
        previewMemory("Golden Gate", "https://picsum.photos/id/1018/500/500", daysAgo: 8,   lat: 37.807, lon: -122.475, photos: 8),
        previewMemory("Dolores Park", "https://picsum.photos/id/1039/500/500", daysAgo: 40,  lat: 37.759, lon: -122.427, photos: 12),
        previewMemory("Sightglass", "https://picsum.photos/id/225/500/500", daysAgo: 150,    lat: 37.764, lon: -122.409, photos: 6), // ~4 mo gap
        previewMemory("Muir Woods", "https://picsum.photos/id/1043/500/500", daysAgo: 210,   lat: 37.895, lon: -122.571, photos: 9),
        previewMemory("The Old House", "https://picsum.photos/id/1062/500/500", daysAgo: 600, lat: 34.052, lon: -118.243, photos: 7) // ~1 yr gap
    ])
}

#Preview("Empty State") {
    TimelineView(previewMemories: [])
}
