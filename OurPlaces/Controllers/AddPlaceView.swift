import SwiftUI
import MapKit

struct AddPlaceView: View {
    
    // MARK: - Data
    var coordinate = CLLocationCoordinate2D(
        latitude: 37.7749,
        longitude: -122.4194
    )
    
    @State private var placeName = ""
    @State private var description = ""
    @State private var selectedCategory = "Cafe"
    var supabaseVM = SupabaseAuthVM()
    private let categories = ["Cafe","Food","Historic","Nature","Shopping","Religious","Entertainment"]
    @State private var isSaving = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    var onPlaceAdded: (() -> Void)?
    
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
        .alert("Place Added 🎉", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Place added to your map successfully.")
        }
        
        .alert("Something Went Wrong", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
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
                    ForEach(categories, id: \.self) { category in
                        categoryButton(category)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    func categoryButton(_ category: String) -> some View {
        Button {
            selectedCategory = category
        } label: {
            Text(category)
                .font(.subheadline)
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
    }
    
    // 📝 Description
    var descriptionField: some View {
        labeledTextEditor(
            title: "DESCRIPTION",
            placeholder: "Tell us why this place is special...",
            text: $description
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
                Text("Add Photos")
                    .font(.headline)
                Spacer()
                Text("Optional")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            HStack(spacing: 12) {
                photoUploadBox()
                photoPlaceholder()
                photoPlaceholder()
            }
        }
        .padding(.horizontal)
    }
    
    // 💾 Save Button
    var saveButton: some View {
        Button {
            savePlace()
        } label: {
            Text(isSaving ? "Saving..." : "Save Place ✓")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(placeName.isEmpty ? Color.gray : .accent)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(isSaving || placeName.isEmpty)
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
    
    private func savePlace() {
        guard !placeName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Place name cannot be empty."
            showErrorAlert = true
            return
        }
        
        isSaving = true
        
        Task {
            do {
                try await supabaseVM.addPrivatePlace(
                    name: placeName,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    category: selectedCategory,
                    description: description
                )
                
                await supabaseVM.fetchPlaces()
                
                isSaving = false
                showSuccessAlert = true
                onPlaceAdded?()
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
                showErrorAlert = true
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
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(14)
                }
                
                TextEditor(text: text)
                    .frame(height: 100)
                    .padding(8)
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
    
    func photoUploadBox() -> some View {
        RoundedRectangle(cornerRadius: 14)
            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
            .frame(width: 80, height: 80)
            .overlay(
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundColor(.gray)
            )
    }
    
    func photoPlaceholder() -> some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.gray.opacity(0.2))
            .frame(width: 80, height: 80)
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
