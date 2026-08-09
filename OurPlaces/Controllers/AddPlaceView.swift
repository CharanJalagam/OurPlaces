import SwiftUI
import MapKit
import PhotosUI

struct AddPlaceView: View {
    
    // MARK: - Data
    var coordinate = CLLocationCoordinate2D(
        latitude: 37.7749,
        longitude: -122.4194
    )
    
    /// Optional name suggested from the picked location's address.
    var suggestedName: String = ""
    /// Optional category suggested from the picked location's Apple Maps POI type.
    var suggestedCategory: String? = nil

    private let descriptionLimit = 200
    private let photoLimit = 5

    @State private var placeName = ""
    @State private var description = ""
    @State private var selectedCategory = "Cafe"
    var supabaseVM = SupabaseAuthVM()
    @ObservedObject private var categoryStore = CategoryStore.shared
    @State private var isAddingCategory = false
    @State private var newCategory = ""
    @FocusState private var categoryFieldFocused: Bool
    @State private var isSaving = false
    @State private var showErrorAlert = false
    @State private var showDuplicateAlert = false
    @State private var showSuccessAlert = false
    @State private var showDeleteBlocked = false
    @State private var deleteBlockedMessage = ""
    @State private var errorMessage = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @Environment(\.dismiss) private var dismiss
    var onPlaceAdded: (() -> Void)?

    private var trimmedName: String {
        placeName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Body
    var body: some View {
        ZStack{
            ScrollView {
                VStack(spacing: 20) {
                    mapSection
                    formCard
                    photoSection
                    saveButton
                }
                .padding(.top)
            }
            if isSaving {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()

                ProgressView("Saving Place...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Add Place Details")
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if placeName.isEmpty { placeName = suggestedName }
            if let suggestedCategory, categoryStore.all.contains(suggestedCategory) {
                selectedCategory = suggestedCategory
            }
            Task { await categoryStore.refresh() }
        }
        .alert("Place Added 🎉", isPresented: $showSuccessAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("Place added to your map successfully.")
        }
        .alert("Something Went Wrong", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Possible Duplicate", isPresented: $showDuplicateAlert) {
            Button("Save Anyway") { performSave() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You already saved a place with this name nearby.")
        }
        .alert("Category In Use", isPresented: $showDeleteBlocked) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteBlockedMessage)
        }
    }
}

// MARK: - Sections
private extension AddPlaceView {
    
    // 🗺️ Map
    var mapSection: some View {
        Map(
            initialPosition: .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
        ) {
            Marker("Location", coordinate: coordinate)
        }
        .allowsHitTesting(false)
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .padding(.horizontal)
    }
    
    // 🧾 Form Card
    var formCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            placeNameField
            categorySelector
            descriptionField
            coordinateRow
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }
    
    // ✏️ Place Name
    var placeNameField: some View {
        labeledTextField(
            title: "PLACE NAME",
            placeholder: "E.g. Sunny Morning Cafe",
            text: $placeName
        )
    }
    
    // 🏷️ Category Selector
    var categorySelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CATEGORY")
                .font(.caption)
                .foregroundColor(.gray)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(categoryStore.all, id: \.self) { category in
                        categoryButton(category)
                    }
                    addCategoryChip
                }
                .padding(.vertical, 4)
            }
        }
    }

    func categoryButton(_ category: String) -> some View {
        Button {
            selectedCategory = category
        } label: {
            HStack(spacing: 6) {
                Image(systemName: CategoryStore.icon(for: category))
                    .font(.caption)
                Text(category)
                    .font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                selectedCategory == category
                ? .accent
                : Color.gray.opacity(0.15)
            )
            .foregroundColor(
                selectedCategory == category
                ? .white
                : .primary
            )
            .clipShape(Capsule())
        }
        .contextMenu {
            if categoryStore.isCustom(category) {
                Button(role: .destructive) {
                    attemptDeleteCategory(category)
                } label: {
                    Label("Delete Category", systemImage: "trash")
                }
            }
        }
    }

    /// Blocks deletion of a custom category if any place still uses it.
    private func attemptDeleteCategory(_ category: String) {
        Task {
            let count = await supabaseVM.placeCount(usingCategory: category)
            await MainActor.run {
                if count > 0 {
                    deleteBlockedMessage = "\(count) place\(count == 1 ? "" : "s") still use “\(category)”. Recategorize or remove them before deleting this category."
                    showDeleteBlocked = true
                } else {
                    if selectedCategory == category { selectedCategory = "Cafe" }
                    categoryStore.remove(category)
                }
            }
        }
    }

    // "+" chip → inline text field to add a custom category (persisted).
    @ViewBuilder
    var addCategoryChip: some View {
        if isAddingCategory {
            HStack(spacing: 6) {
                TextField("New category", text: $newCategory)
                    .focused($categoryFieldFocused)
                    .frame(width: 100)
                    .submitLabel(.done)
                    .onSubmit { commitNewCategory() }
                Button {
                    commitNewCategory()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.15))
            .clipShape(Capsule())
            .onAppear { categoryFieldFocused = true }
        } else {
            Button {
                withAnimation { isAddingCategory = true }
            } label: {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.15))
                    .foregroundColor(.accent)
                    .clipShape(Capsule())
            }
        }
    }

    private func commitNewCategory() {
        let name = newCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        newCategory = ""
        isAddingCategory = false
        guard !name.isEmpty else { return }
        categoryStore.add(name)
        selectedCategory = name   // select the newly added category
    }
    
    // 📝 Description
    var descriptionField: some View {
        labeledTextEditor(
            title: "DESCRIPTION",
            placeholder: "Why is this place special? (optional)",
            text: $description,
            maxLength: descriptionLimit
        )
    }
    
    // 📍 Coordinates
    var coordinateRow: some View {
        HStack(spacing: 12) {
            coordinateBox(title: "LATITUDE", value: coordinate.latitude)
            coordinateBox(title: "LONGITUDE", value: coordinate.longitude)
        }
    }
    
    // 🖼️ Photos
    var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Add Place Photos")
                    .font(.headline)
                Spacer()
                Text(selectedImages.isEmpty ? "Optional" : "\(selectedImages.count)/\(photoLimit)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            if !selectedImages.isEmpty {
                Text("First photo is the map pin. Long-press a photo to set it as cover.")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: photoLimit,
                        matching: .images
                    ) {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                            .frame(width: 80, height: 80)
                            .foregroundColor(.gray)
                            .overlay(
                                VStack(spacing: 4) {
                                    Image(systemName: "plus")
                                    Text("Add").font(.caption2)
                                }
                                .foregroundColor(.gray)
                            )
                    }

                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { idx, image in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(alignment: .bottomLeading) {
                                    if idx == 0 {
                                        Text("Cover")
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color(.appRed), in: Capsule())
                                            .foregroundColor(.white)
                                            .padding(4)
                                    }
                                }

                            Button {
                                removePhoto(at: idx)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white, .black.opacity(0.6))
                                    .padding(4)
                            }
                        }
                        .contextMenu {
                            if idx != 0 {
                                Button {
                                    setAsCover(idx)
                                } label: {
                                    Label("Set as cover", systemImage: "star")
                                }
                            }
                            Button(role: .destructive) {
                                removePhoto(at: idx)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .onChange(of: selectedItems) { _, items in
            Task { await loadImages(items) }
        }
    }

    private func loadImages(_ items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let ui = UIImage(data: data) {
                images.append(ui)
            }
        }
        await MainActor.run { selectedImages = images }
    }

    private func removePhoto(at idx: Int) {
        if idx < selectedItems.count { selectedItems.remove(at: idx) }
        if idx < selectedImages.count { selectedImages.remove(at: idx) }
    }

    private func setAsCover(_ idx: Int) {
        guard idx > 0, idx < selectedImages.count else { return }
        let img = selectedImages.remove(at: idx)
        selectedImages.insert(img, at: 0)
        if idx < selectedItems.count {
            let item = selectedItems.remove(at: idx)
            selectedItems.insert(item, at: 0)
        }
    }
    
    // 💾 Save Button
    var saveButton: some View {
        VStack(spacing: 8) {
            if trimmedName.isEmpty {
                Text("Enter a place name to save")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Button {
                savePlace()
            } label: {
                Text(isSaving ? "Saving…" : "Save Place ✓")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(trimmedName.isEmpty ? Color.gray : .accent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(isSaving || trimmedName.isEmpty)
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
    
    private func savePlace() {
        guard !trimmedName.isEmpty else {
            errorMessage = "Place name cannot be empty."
            showErrorAlert = true
            return
        }
        if hasNearbyDuplicate() {
            showDuplicateAlert = true
            return
        }
        performSave()
    }

    /// True if a place with the same name already exists within ~50 m.
    private func hasNearbyDuplicate() -> Bool {
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let name = trimmedName
        return CoreDataLayer.shared.fetchPlaces().contains { p in
            p.name.caseInsensitiveCompare(name) == .orderedSame &&
            CLLocation(latitude: p.latitude, longitude: p.longitude).distance(from: target) < 50
        }
    }

    private func performSave() {
        isSaving = true

        Task {
            do {
                try await supabaseVM.addPrivatePlace(
                    name: trimmedName,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    category: selectedCategory,
                    description: description,
                    images: selectedImages
                )

                await supabaseVM.fetchPlaces()

                await MainActor.run {
                    isSaving = false
                    onPlaceAdded?()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Reusable Components
private extension AddPlaceView {
    
    func labeledTextField(
        title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            TextField(placeholder, text: text)
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    func labeledTextEditor(
        title: String,
        placeholder: String,
        text: Binding<String>,
        maxLength: Int? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                if let maxLength {
                    Text("\(text.wrappedValue.count)/\(maxLength)")
                        .font(.caption2)
                        .foregroundColor(text.wrappedValue.count >= maxLength ? .red : .gray)
                }
            }

            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(14)
                }

                TextEditor(text: text)
                    .frame(height: 100)
                    .padding(8)
                    .onChange(of: text.wrappedValue) { _, newValue in
                        if let maxLength, newValue.count > maxLength {
                            text.wrappedValue = String(newValue.prefix(maxLength))
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                hideKeyboard()
                            }
                        }
                    }
            }
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    func coordinateBox(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(String(format: "%.6f", value))
                .font(.footnote)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
}
func hideKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil
    )
}

// MARK: - Preview
#Preview {
    NavigationStack {
        AddPlaceView()
    }
}
