//
//  PhotosView.swift
//  OurPlaces
//
//  Immersive full-screen viewer for a place's visit memories:
//  pinch-to-zoom, per-photo notes, dates, swipe-down to dismiss.
//

import SwiftUI

struct PhotosView: View {
    let place: Place
    @State private var images: [VisitImage]
    var startIndex: Int

    @State private var currentIndex = 0
    @State private var isZoomed = false
    @State private var dragDownOffset: CGFloat = 0
    @State private var showCaptionEditor = false
    @State private var captionDraft = ""
    @Environment(\.dismiss) private var dismiss

    init(images: [VisitImage], place: Place, startIndex: Int) {
        self.place = place
        self.startIndex = startIndex
        _images = State(initialValue: images)
        _currentIndex = State(initialValue: startIndex)
    }

    private var current: VisitImage { images[currentIndex] }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Ambient snow — purely decorative, sits behind the photo in the
            // background and fades away while zoomed.
            SnowfallView()
                .opacity(isZoomed ? 0 : 1)
                .animation(.easeInOut(duration: 0.35), value: isZoomed)

            ZoomableImage(
                url: URL(string: current.image_url),
                isZoomed: $isZoomed,
                dragDownOffset: $dragDownOffset,
                onDismiss: { dismiss() }
            )
            .id(currentIndex)
            .transition(.opacity)
            .ignoresSafeArea()

            // Edge tap zones for prev/next (disabled while zoomed).
            HStack {
                navStrip { goPrevious() }
                Spacer()
                navStrip { goNext() }
            }
            .allowsHitTesting(!isZoomed)

            VStack {
                topBar
                Spacer()
                captionBar
            }
            .opacity(isZoomed ? 0 : 1)
            .allowsHitTesting(!isZoomed)
        }
        .offset(y: dragDownOffset)
        .animation(.interactiveSpring(), value: dragDownOffset)
        .animation(.easeInOut(duration: 0.28), value: currentIndex)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Add a note", isPresented: $showCaptionEditor) {
            TextField("e.g. our first coffee here", text: $captionDraft)
            Button("Save") { saveCaption() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("A little note makes this memory yours.")
        }
    }

    // MARK: - Chrome

    private func navStrip(_ action: @escaping () -> Void) -> some View {
        Color.clear
            .frame(width: 72)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }

    private var topBar: some View {
        HStack {
            Text("\(currentIndex + 1) / \(images.count)")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    private var captionBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(longDate(current.created_at_millis))
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundColor(.white)

            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                Text(place.name)
                Text("•")
                Text(timeAgo(from: current.created_at_millis))
            }
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.85))

            if let caption = current.caption, !caption.isEmpty {
                Text("“\(caption)”")
                    .font(.system(.body, design: .serif).italic())
                    .foregroundColor(.white)
                Button {
                    captionDraft = caption
                    showCaptionEditor = true
                } label: {
                    Label("Edit note", systemImage: "pencil")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            } else {
                Button {
                    captionDraft = ""
                    showCaptionEditor = true
                } label: {
                    Label("Add a note", systemImage: "plus.bubble")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .padding(.bottom, 12)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.8)],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    // MARK: - Actions

    private func saveCaption() {
        let text = captionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = current.image_url
        images[currentIndex].caption = text.isEmpty ? nil : text   // optimistic
        Task { try? await SupabaseAuthVM().setCaption(imageURL: url, caption: text) }
    }

    private func goNext() {
        guard currentIndex < images.count - 1 else { return }
        currentIndex += 1
    }

    private func goPrevious() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }

    private func longDate(_ millis: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
        let f = DateFormatter()
        f.dateFormat = "d MMMM yyyy"
        return f.string(from: date)
    }
}

// MARK: - Zoomable image

struct ZoomableImage: View {
    let url: URL?
    @Binding var isZoomed: Bool
    @Binding var dragDownOffset: CGFloat
    var onDismiss: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        CachedAsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .simultaneousGesture(magnify)
                    .gesture(drag)
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) { toggleZoom() }
                    }
            case .empty:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.4)
            default:
                failed
            }
        }
    }

    private var magnify: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 4)
                isZoomed = scale > 1.01
            }
            .onEnded { _ in
                if scale <= 1 { resetZoom() } else { lastScale = scale }
            }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1 {
                    offset = CGSize(width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height)
                } else if value.translation.height > 0 {
                    dragDownOffset = value.translation.height
                }
            }
            .onEnded { value in
                if scale > 1 {
                    lastOffset = offset
                } else if value.translation.height > 150 || value.velocity.height > 500 {
                    onDismiss()
                } else {
                    withAnimation(.spring()) { dragDownOffset = 0 }
                }
            }
    }

    private func toggleZoom() {
        if scale > 1 {
            resetZoom()
        } else {
            scale = 2.5; lastScale = 2.5; isZoomed = true
        }
    }

    private func resetZoom() {
        scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero; isZoomed = false
    }

    private var failed: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundColor(.white.opacity(0.7))
            Text("Couldn't load this memory")
                .foregroundColor(.white)
                .font(.subheadline)
        }
    }
}

func timeAgo(from millis: Int64) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
}

// MARK: - Ambient snowfall

/// A lightweight, non-interactive snow layer drawn with a single Canvas.
/// Each flake gets a randomized size, speed, opacity and horizontal drift, with a
/// subtle depth parallax (near flakes are bigger, faster and brighter) so it reads
/// as real snow while staying quiet in the background.
struct SnowfallView: View {

    private let flakes: [Flake]

    init(count: Int = 80) {
        var rng = SystemRandomNumberGenerator()
        flakes = (0..<count).map { _ in Flake.random(using: &rng) }
    }

    var body: some View {
        SwiftUI.TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let fall = size.height + 40                 // travel distance incl. off-screen margins

                for flake in flakes {
                    // Vertical fall that wraps seamlessly from bottom back to the top.
                    let y = (flake.startY * fall + CGFloat(t) * flake.speed)
                        .truncatingRemainder(dividingBy: fall) - 20

                    // Gentle side-to-side drift.
                    let x = flake.xFraction * size.width
                        + CGFloat(sin(t * flake.swaySpeed + flake.swayPhase)) * flake.swayAmp

                    context.opacity = flake.opacity
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: flake.size, height: flake.size)),
                        with: .color(.white)
                    )
                }
            }
            .blur(radius: 0.6)                              // soften the flakes so they feel real
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)                            // never intercepts touches
    }

    struct Flake {
        var xFraction: CGFloat      // horizontal position as a fraction of width
        var startY: CGFloat         // initial vertical phase (0...1)
        var size: CGFloat
        var speed: CGFloat          // points per second
        var opacity: Double
        var swayAmp: CGFloat
        var swaySpeed: Double
        var swayPhase: Double

        static func random(using rng: inout some RandomNumberGenerator) -> Flake {
            let depth = CGFloat.random(in: 0...1, using: &rng)   // 0 = far, 1 = near
            return Flake(
                xFraction: .random(in: 0...1, using: &rng),
                startY: .random(in: 0...1, using: &rng),
                size: 1.4 + depth * 3.2,                          // 1.4 ... 4.6 pt
                speed: 16 + depth * 42 + .random(in: -4...4, using: &rng),
                opacity: 0.18 + Double(depth) * 0.5,              // near flakes brighter
                swayAmp: .random(in: 5...20, using: &rng),
                swaySpeed: .random(in: 0.4...1.1, using: &rng),
                swayPhase: .random(in: 0...(2 * .pi), using: &rng)
            )
        }
    }
}
