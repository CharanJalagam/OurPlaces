//
//  CaptureMomentView.swift
//  OurPlaces
//
//  Add a visit: a warm two-step flow — "When were you here?" → "Add your photos".
//

import SwiftUI
import PhotosUI
import Supabase
import WidgetKit

struct CaptureMomentView: View {

    enum Step { case when, photos }

    let place: Place
    var onPlaceAdded: (() -> Void)?
    let authVM = SupabaseAuthVM()

    @State private var step: Step = .when
    @State private var selectedDate = Date()
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var capturedImages: [UIImage] = []
    @State private var showCamera = false
    @State private var showLoader = false
    @State private var showPopup = false
    @State private var showConfetti = false
    @State private var visitId = UUID()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var allImages: [UIImage] { capturedImages + selectedImages }

    var body: some View {
        ZStack {
            Color(.background).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScrollView(showsIndicators: false) {
                    Group {
                        switch step {
                        case .when:   whenStep
                        case .photos: photosStep
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }

            if showLoader {
                Color.black.opacity(0.2).ignoresSafeArea()
                ProgressView().scaleEffect(1.2)
            }

            if showPopup {
                PopupOverlay(popup: MemorySavedPopup(placeName: place.name) {
                    withAnimation { showPopup = false; showConfetti = false; dismiss() }
                })
            }

            // Celebratory confetti over everything (non-interactive).
            if showConfetti {
                ConfettiView()
                    .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in capturedImages.append(image) }
                .ignoresSafeArea()
        }
        .onChange(of: selectedItems) { _, items in loadSelectedImages(items) }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { back() } label: {
                Image(systemName: step == .when ? "xmark" : "chevron.left")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            Spacer()
            stepDots
            Spacer()
            Color.clear.frame(width: 40, height: 40)   // balances the leading button
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var stepDots: some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(step == .when ? Color(.appRed) : Color.gray.opacity(0.3))
                .frame(width: step == .when ? 22 : 8, height: 8)
            Capsule()
                .fill(step == .photos ? Color(.appRed) : Color.gray.opacity(0.3))
                .frame(width: step == .photos ? 22 : 8, height: 8)
        }
        .animation(.spring(response: 0.3), value: step)
    }

    private func back() {
        if step == .photos { withAnimation { step = .when } }
        else { dismiss() }
    }

    // MARK: - Step 1: When

    private var whenStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                heroIcon("calendar.badge.clock")
                Text("When were you here?")
                    .font(.system(.title, design: .serif).weight(.bold))
                    .foregroundColor(Color(.textPrimary))
                Text("Let’s mark your moment at \(place.name).")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 12)

            Button {
                proceed(millis: Date().millisecondsSince1970)
            } label: {
                choiceCard(icon: "clock.fill", title: "Right now",
                           subtitle: "I’m here today", prominent: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("OR PICK THE DAY")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(.secondary)

                DatePicker("", selection: $selectedDate, in: ...Date(), displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .tint(Color(.appRed))
                    .labelsHidden()
                    .padding(8)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 3)

                Button {
                    proceed(millis: selectedDate.millisecondsSince1970)
                } label: {
                    Text("Use \(shortDate(selectedDate))")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(SoftButtonStyle())
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Step 2: Photos

    private var photosStep: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                heroIcon("photo.stack.fill")
                Text("Add your photos")
                    .font(.system(.title, design: .serif).weight(.bold))
                    .foregroundColor(Color(.textPrimary))
                Text("From \(place.name) • \(shortDate(selectedDate))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 12)

            HStack(spacing: 14) {
                Button { showCamera = true } label: {
                    captureOption(icon: "camera.fill", title: "Take a Photo")
                }
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 10, matching: .images) {
                    captureOption(icon: "photo.on.rectangle.angled", title: "From Library")
                }
            }

            if allImages.isEmpty {
                emptyPhotos
            } else {
                selectedStrip
            }

            Button { uploadImgs() } label: {
                Text(allImages.isEmpty ? "Save Visit" : "Save Memory")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(PrimaryButtonStyle())

            Text("Your photos are pinned to this place and saved to your memories.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 30)
        }
    }

    // MARK: - Reusable pieces

    private func heroIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 30, weight: .semibold))
            .foregroundColor(Color(.appRed))
            .frame(width: 72, height: 72)
            .background(Color(.appRed).opacity(0.12), in: Circle())
    }

    private func choiceCard(icon: String, title: String, subtitle: String, prominent: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(prominent ? .white : Color(.appRed))
                .frame(width: 48, height: 48)
                .background(prominent ? Color.white.opacity(0.2) : Color(.appRed).opacity(0.12),
                           in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                    .foregroundColor(prominent ? .white : .primary)
                Text(subtitle).font(.subheadline)
                    .foregroundColor(prominent ? .white.opacity(0.9) : .secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(prominent ? .white.opacity(0.9) : .secondary)
        }
        .padding(18)
        .background(prominent ? Color(.appRed) : Color.white,
                    in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: prominent ? Color(.appRed).opacity(0.3) : .black.opacity(0.06),
                radius: 8, y: 4)
    }

    private func captureOption(icon: String, title: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color(.appRed))
            Text(title)
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 96)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color(.appRed).opacity(0.15)))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 3)
    }

    private var emptyPhotos: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.plus")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("No photos yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Add a couple to remember this visit — or save without photos.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                .foregroundColor(.gray.opacity(0.4))
        )
    }

    private var selectedStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(allImages.count) photo\(allImages.count == 1 ? "" : "s")")
                .font(.subheadline).fontWeight(.medium)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(allImages.indices, id: \.self) { index in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: allImages[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 110, height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            Button { removeImage(at: index) } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white, .black.opacity(0.6))
                                    .padding(5)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Data flow

    private func proceed(millis: Int64) {
        showLoader = true
        Task {
            do {
                let visit = try await authVM.insertVisit(placeId: place.id, visitedAtMillis: millis)
                await MainActor.run {
                    showLoader = false
                    guard let id = visit?.id else { return }
                    visitId = id
                    selectedDate = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { step = .photos }
                }
            } catch {
                await MainActor.run { showLoader = false }
                print("Visit insert failed:", error)
            }
        }
    }

    private func uploadImgs() {
        showLoader = true
        Task {
            do {
                let images = allImages
                var urls: [String] = []
                for image in images {
                    let url = try await uploadVisitImage(image: image, visitId: visitId)
                    urls.append(url)
                }
                if !urls.isEmpty {
                    try await authVM.insertVisitImages(
                        visitId: visitId,
                        imageURLs: urls,
                        timeStamp: selectedDate.millisecondsSince1970
                    )
                }
                if let latest = images.last {
                    WidgetDataManager.shared.saveLastImage(latest)
                    WidgetCenter.shared.reloadAllTimelines()
                }
                await MainActor.run {
                    showLoader = false
                    onPlaceAdded?()
                    withAnimation { showPopup = true }
                    if !reduceMotion {
                        withAnimation { showConfetti = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) {
                            withAnimation { showConfetti = false }
                        }
                    }
                }
            } catch {
                await MainActor.run { showLoader = false }
                print("Upload failed:", error)
            }
        }
    }

    private func removeImage(at index: Int) {
        if index < capturedImages.count {
            capturedImages.remove(at: index)
        } else {
            let libIndex = index - capturedImages.count
            if libIndex < selectedItems.count {
                selectedItems.remove(at: libIndex)   // triggers reload of selectedImages
            } else if libIndex < selectedImages.count {
                selectedImages.remove(at: libIndex)
            }
        }
    }

    private func loadSelectedImages(_ items: [PhotosPickerItem]) {
        Task {
            var images: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    images.append(image)
                }
            }
            await MainActor.run { selectedImages = images }
        }
    }

    private func uploadVisitImage(image: UIImage, visitId: UUID) async throws -> String {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id else {
            throw NSError(domain: "Auth", code: 401)
        }
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "Image", code: 400)
        }

        let fileName = "\(UUID().uuidString).jpg"
        let filePath = "\(userId.uuidString)/\(visitId.uuidString)/\(fileName)"

        try await SupabaseManager.shared.client.storage
            .from("visit-images")
            .upload(filePath, data: imageData,
                    options: FileOptions(contentType: "image/jpeg", upsert: false))

        let publicURL = try SupabaseManager.shared.client.storage
            .from("visit-images")
            .getPublicURL(path: filePath)

        return publicURL.absoluteString
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}

// MARK: - Button styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .background(Color(.appRed), in: RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .shadow(color: Color(.appRed).opacity(0.25), radius: 8, x: 0, y: 6)
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(Color(.appRed))
            .background(Color(.appRed).opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

extension Date {
    var millisecondsSince1970: Int64 {
        Int64(self.timeIntervalSince1970 * 1000)
    }
}
