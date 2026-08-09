//
//  EditPlaceView.swift
//  OurPlaces
//
//  Edit a saved place: name, category, description, and photos.
//  (Location is shown read-only.)
//

import SwiftUI
import MapKit
import PhotosUI

struct EditPlaceView: View {
    let place: Place
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var categoryStore = CategoryStore.shared
    private let supabaseVM = SupabaseAuthVM()

    @State private var name: String
    @State private var description: String
    @State private var selectedCategory: String
    @State private var existingURLs: [String]
    @State private var newItems: [PhotosPickerItem] = []
    @State private var newImages: [UIImage] = []

    @State private var isAddingCategory = false
    @State private var newCategory = ""
    @FocusState private var categoryFieldFocused: Bool

    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let descriptionLimit = 200
    private let photoLimit = 6

    init(place: Place, onSaved: @escaping () -> Void) {
        self.place = place
        self.onSaved = onSaved
        _name = State(initialValue: place.name)
        _description = State(initialValue: place.description ?? "")
        _selectedCategory = State(initialValue: place.category)
        _existingURLs = State(initialValue: place.image_urls ?? [])
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var totalPhotos: Int { existingURLs.count + newImages.count }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        mapPreview
                        formCard
                        photoSection
                        saveButton
                    }
                    .padding(.vertical)
                }

                if isSaving {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView("Saving…")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .navigationTitle("Edit Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Something Went Wrong", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onChange(of: newItems) { _, items in
                Task { await loadNewImages(items) }
            }
        }
    }

    // MARK: - Map preview (read-only)

    private var mapPreview: some View {
        let coordinate = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        return Map(initialPosition: .region(
            MKCoordinateRegion(center: coordinate,
                               span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        )) {
            Marker(place.name, coordinate: coordinate)
        }
        .allowsHitTesting(false)
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .padding(.horizontal)
    }

    // MARK: - Form

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            field(title: "PLACE NAME") {
                TextField("Place name", text: $name)
                    .padding(12)
                    .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }

            field(title: "CATEGORY") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(categoryStore.all, id: \.self) { category in
                            categoryChip(category)
                        }
                        addCategoryChip
                    }
                    .padding(.vertical, 4)
                }
            }

            field(title: "DESCRIPTION") {
                VStack(spacing: 4) {
                    ZStack(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("Why is this place special?")
                                .foregroundColor(.gray.opacity(0.6))
                                .padding(14)
                        }
                        TextEditor(text: $description)
                            .frame(height: 90)
                            .padding(8)
                            .onChange(of: description) { _, value in
                                if value.count > descriptionLimit {
                                    description = String(value.prefix(descriptionLimit))
                                }
                            }
                    }
                    .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                    HStack {
                        Spacer()
                        Text("\(description.count)/\(descriptionLimit)")
                            .font(.caption2)
                            .foregroundColor(description.count >= descriptionLimit ? .red : .gray)
                    }
                }
            }
        }
        .padding()
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    private func field<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundColor(.gray)
            content()
        }
    }

    // MARK: - Category chips

    private func categoryChip(_ category: String) -> some View {
        Button {
            selectedCategory = category
        } label: {
            HStack(spacing: 6) {
                Image(systemName: CategoryStore.icon(for: category)).font(.caption)
                Text(category).font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selectedCategory == category ? .accent : Color.gray.opacity(0.15))
            .foregroundColor(selectedCategory == category ? .white : .primary)
            .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var addCategoryChip: some View {
        if isAddingCategory {
            HStack(spacing: 6) {
                TextField("New category", text: $newCategory)
                    .focused($categoryFieldFocused)
                    .frame(width: 100)
                    .submitLabel(.done)
                    .onSubmit { commitNewCategory() }
                Button { commitNewCategory() } label: {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.accent)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Color.gray.opacity(0.15))
            .clipShape(Capsule())
            .onAppear { categoryFieldFocused = true }
        } else {
            Button {
                withAnimation { isAddingCategory = true }
            } label: {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.gray.opacity(0.15))
                    .foregroundColor(.accent)
                    .clipShape(Capsule())
            }
        }
    }

    private func commitNewCategory() {
        let n = newCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        newCategory = ""
        isAddingCategory = false
        guard !n.isEmpty else { return }
        categoryStore.add(n)
        selectedCategory = n
    }

    // MARK: - Photos

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Photos").font(.headline)
                Spacer()
                Text("\(totalPhotos)/\(photoLimit)").font(.caption).foregroundColor(.gray)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if totalPhotos < photoLimit {
                        PhotosPicker(
                            selection: $newItems,
                            maxSelectionCount: max(1, photoLimit - existingURLs.count),
                            matching: .images
                        ) {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                                .frame(width: 80, height: 80)
                                .foregroundColor(.gray)
                                .overlay(
                                    VStack(spacing: 4) {
                                        Image(systemName: "plus"); Text("Add").font(.caption2)
                                    }.foregroundColor(.gray)
                                )
                        }
                    }

                    // Existing (already-uploaded) photos
                    ForEach(Array(existingURLs.enumerated()), id: \.offset) { idx, urlString in
                        thumb {
                            CachedAsyncImage(url: URL(string: urlString)) { phase in
                                switch phase {
                                case .success(let image): image.resizable().scaledToFill()
                                default: ZStack { Color.gray.opacity(0.2); ProgressView() }
                                }
                            }
                        } onRemove: {
                            existingURLs.remove(at: idx)
                        }
                    }

                    // Newly picked photos (not yet uploaded)
                    ForEach(Array(newImages.enumerated()), id: \.offset) { idx, image in
                        thumb {
                            Image(uiImage: image).resizable().scaledToFill()
                        } onRemove: {
                            if idx < newItems.count { newItems.remove(at: idx) }
                            else if idx < newImages.count { newImages.remove(at: idx) }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func thumb<Content: View>(@ViewBuilder content: () -> Content, onRemove: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            content()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .padding(4)
            }
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        VStack(spacing: 8) {
            if trimmedName.isEmpty {
                Text("Enter a place name to save")
                    .font(.caption).foregroundColor(.gray)
            }
            Button { save() } label: {
                Text(isSaving ? "Saving…" : "Save Changes")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(trimmedName.isEmpty ? Color.gray : Color(.appRed))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(isSaving || trimmedName.isEmpty)
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
    }

    private func save() {
        guard !trimmedName.isEmpty else {
            errorMessage = "Place name cannot be empty."
            showError = true
            return
        }
        isSaving = true
        Task {
            do {
                try await supabaseVM.updatePlace(
                    id: place.id,
                    name: trimmedName,
                    category: selectedCategory,
                    description: description,
                    keptImageURLs: existingURLs,
                    newImages: newImages
                )
                await supabaseVM.fetchPlaces()
                await MainActor.run {
                    isSaving = false
                    onSaved()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func loadNewImages(_ items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let ui = UIImage(data: data) {
                images.append(ui)
            }
        }
        await MainActor.run { newImages = images }
    }
}
