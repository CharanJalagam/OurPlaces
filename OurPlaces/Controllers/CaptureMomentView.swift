//
//  CaptureMomentView.swift
//  OurPlaces
//
//  Created by apple on 15/01/26.
//


import SwiftUI
import PhotosUI
import Supabase
import WidgetKit

fileprivate let visitedExampleDate: Date = {
    var comps = DateComponents()
    comps.year = 2023; comps.month = 10; comps.day = 24
    return Date()
//    Calendar.current.date(from: comps) ?? Date()
}()

fileprivate let dateFormatterLong: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .long
    return f
}()
struct CaptureMomentView: View {
    // MARK: - Image Selection
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var capturedImages: [UIImage] = []
    @State private var showCamera = false
    
    // MARK: - Visit Flow
    @State private var showPastSelected = false
    @State private var selectedDate: Date = Date()
    @State private var showSheet = false
    @State private var showLoader = false
    @State private var showPopup = false
    var onPlaceAdded: (() -> Void)?
    let place: Place
    let authVM = SupabaseAuthVM()
    @State private var visit_id = UUID()
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - UI
    var body: some View {
        ZStack {
            Color(.background)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                headerView
                actionButtons
                RecentMemoriesSection(
                    images: (capturedImages + selectedImages).map { Image(uiImage: $0) }, onUpload: {
                        uploadImgs()
                    }, isUploadEnabled: !(capturedImages + selectedImages).isEmpty
                )
                FooterNoteView()
            }
            .padding(.horizontal)
            
            if showPopup{
                PopupOverlay(
                    popup: MemorySavedPopup(
                        placeName: place.name
                    ) {
                        withAnimation {
                            showPopup = false
                            dismiss()
                        }
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
            
            if showSheet {
                Color.black.opacity(0.5).ignoresSafeArea()
                bottomSheet
            }
            
            if showLoader {
                Color.black.opacity(0.2).ignoresSafeArea()
                ProgressView().scaleEffect(1.2)
            }
        }
        .task {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                showSheet = true
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                capturedImages.append(image)
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedItems) { _, newItems in
            loadSelectedImages(newItems)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
    }
    
    // MARK: - Header
    private var headerView: some View {
        ZStack(alignment: .top) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    if !showSheet {
                        Image(systemName: "xmark")
                            .font(.title2)
                    }
                }
                Spacer()
            }
            
            VStack(spacing: 8) {
                Text("Capture the Moment")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.accent)
                    Text("AT \(place.name)")
                        .foregroundColor(.accent)
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 20) {
            Button {
                showCamera = true
            } label: {
                ActionCardView(
                    icon: "camera.fill",
                    iconColor: .orange,
                    title: "Take a Photo",
                    subtitle: "Capture the view right now"
                )
            }
            
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 10,
                matching: .images
            ) {
                ActionCardView(
                    icon: "photo.on.rectangle",
                    iconColor: .black,
                    title: "Upload from Library",
                    subtitle: "Add photos from your roll"
                )
            }
        }
    }
    
    // MARK: - Bottom Sheet
    private var bottomSheet: some View {
        VStack {
            Spacer()
            BottomVisitSheet(
                isPastSelected: $showPastSelected,
                selectedDate: $selectedDate,
                onConfirm: {
                    handleVisitConfirmation(
                        millis: selectedDate.millisecondsSince1970
                    )
                },
                onHereNow: {
                    handleVisitConfirmation(
                        millis: Date().millisecondsSince1970
                    )
                },
                onCancel: {
                    showSheet = false
                }
            )
            .transition(.move(edge: .bottom))
        }
    }
    
    // MARK: - Visit + Image Flow
    private func handleVisitConfirmation(millis: Int64) {
        showLoader = true
        
        Task {
            do {
                // 1️⃣ Insert visit
                let visit = try await authVM.insertVisit(
                    placeId: place.id,
                    visitedAtMillis: millis
                )
                
                guard let visitId = visit?.id else {
                    return
                }
                visit_id = visitId
               
                
                showLoader = false
                showSheet = false
                
            } catch {
                showLoader = false
                print("Visit flow failed:", error)
            }
        }
    }
    
    private func uploadImgs() {
        
        Task {
            showLoader = true
            do {
                
                // 1️⃣ Insert visit
               
                // 2️⃣ Upload images
                let images = capturedImages + selectedImages
                var urls: [String] = []
                
                for image in images {
                    let url = try await uploadVisitImage(
                        image: image,
                        visitId: visit_id
                    )
                    urls.append(url)
                }
                
                // 3️⃣ Insert visit_images rows
                if !urls.isEmpty {
                    try await authVM.insertVisitImages(
                        visitId: visit_id,
                        imageURLs: urls, timeStamp: selectedDate.millisecondsSince1970
                    )
                }
                if let latestImage = images.last {
                    WidgetDataManager.shared.saveLastImage(latestImage)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
                showLoader = false
                
                showSheet = false
                showPopup = true
                onPlaceAdded?()
            } catch {
                showLoader = false
                print("Visit flow failed:", error)
            }
        }
    }
    // MARK: - Load PhotosPicker Images
    private func loadSelectedImages(_ items: [PhotosPickerItem]) {
        Task {
            selectedImages.removeAll()
            
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImages.append(image)
                }
            }
//            uploadImgs()
        }
    }
    func jpegData(from image: UIImage, compression: CGFloat = 0.8) -> Data? {
        image.jpegData(compressionQuality: compression)
    }
    func uploadVisitImage(
        image: UIImage,
        visitId: UUID
    ) async throws -> String {
        
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
            .upload(
                filePath,
                data: imageData,
                options: FileOptions(
                    contentType: "image/jpeg",
                    upsert: false
                )
            )
        
        // Public URL
        let publicURL = try SupabaseManager.shared.client.storage
            .from("visit-images")
            .getPublicURL(path: filePath)
        
        return publicURL.absoluteString
    }
    

}

struct ActionCardView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            HStack{
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 62, height: 62)
                    
                    
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .font(.title2)
                }
                Spacer()
            }
            HStack{
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .gray.opacity(0.5), radius: 4, x: 0, y: 4)
        )
    }
}
struct RecentMemoriesSection: View {
    let images: [Image]
    let onUpload: () -> Void
    let isUploadEnabled: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            HStack {
                Text("Selected Memories here")
                    .font(.headline)
                
                Spacer()
                
                Button("Upload") {
                    onUpload()
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
                .disabled(!isUploadEnabled)
                .opacity(isUploadEnabled ? 1 : 0.5)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    
                    if images.isEmpty {
                        PlaceholderMemoryCard()
                    } else {
                        ForEach(images.indices, id: \.self) { index in
                            images[index]
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 160)
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: 16,
                                        style: .continuous
                                    )
                                )
                        }
                    }
                }
            }
        }
    }
}
struct PlaceholderMemoryCard: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 120, height: 160)
            
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundColor(.gray)
                
                Text("No memories yet")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}


struct MemoryCardView: View {
    let title: String
    let image: String
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(image)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white)
                .padding(8)
        }
        .frame(width: 120, height: 160) 
    }
}

struct FooterNoteView: View {
    var body: some View {
        Text("Photos added here will be pinned to your personal map and will be added to your memories.")
            .font(.footnote)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }
}
struct BottomVisitSheet: View {
    
    @Environment(\.dismiss) private var dismiss
    @Binding var isPastSelected: Bool
    @Binding var selectedDate: Date
    
    let onConfirm: () -> Void
    let onHereNow: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Top small handle and cancel X
            HStack{
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            Spacer()
            // Sheet content card
            VStack(spacing: 18) {
//                Capsule()
//                    .frame(width: 40, height: 4)
//                    .foregroundColor(Color.gray)
//                    .padding(.top, -8)
                
                Text("When did you visit?")
                    .font(.headline)
                    .padding(.top, 20)
                
                if isPastSelected {
                    PastSelectedView(selectedDate: $selectedDate,
                                     onConfirm: onConfirm,
                                     onHereNow: {
                        // in past mode, also let them press I'm Here Now
                        isPastSelected = false
                        onHereNow()
                    })
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
                } else {
                    InitialVisitView(
                        onHereNow: onHereNow,
                        onSelectPast: {
                            withAnimation(.spring()) {
                                isPastSelected = true
                            }
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 66)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.background)
                    .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
            )
//            .padding(.horizontal)
//            .padding(.bottom, safeAreaBottom())
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
//        .background(
//            // translucent background to dim content behind the sheet
//            Color.black.opacity(0.22)
//                .ignoresSafeArea()
//                .onTapGesture {
//                    onCancel()
//                }
//        )
    }
    
    private func safeAreaBottom() -> CGFloat {
        UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 12
    }
}

// MARK: - Initial Visit View
struct InitialVisitView: View {
    let onHereNow: () -> Void
    let onSelectPast: () -> Void
    
    var body: some View {
        VStack(spacing: 18) {
            // Primary "I'm Here Now"
            Button(action: onHereNow) {
                Text("I'm Here Now")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(PrimaryButtonStyle())
            
            // OR divider
            HStack {
                Capsule().frame(height: 1).foregroundColor(.gray)
                Text("OR")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Capsule().frame(height: 1).foregroundColor(.gray)
            }
            
            // Past Visits header
            VStack(alignment: .leading, spacing: 12) {
                Text("Past Visits")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Example past visit card (tap to open date selector)
                Button(action: onSelectPast) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Visited on")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(dateFormatterLong.string(from: visitedExampleDate))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "calendar")
                                .foregroundColor(.orange)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(UIColor.secondarySystemBackground)))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Past Selected View
struct PastSelectedView: View {
    @Binding var selectedDate: Date
    let onConfirm: () -> Void
    let onHereNow: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Header small label
            VStack(alignment: .leading, spacing: 6) {
                Text("PAST VISIT SELECTED")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fontWeight(.semibold)
                
                HStack {
                    Text(dateFormatterLong.string(from: selectedDate))
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    // calendar icon button (could be used to toggle something)
                    Button(action: {}) {
                        Image(systemName: "calendar.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(Color.accent))
                    }
                }
            }
            .padding(.horizontal, 6)
            
            // Card containing calendar (Graphical DatePicker)
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    VStack(spacing: 8) {
                        // Month title row
//                        HStack {
//                            Text(monthYearString(from: selectedDate))
//                                .font(.subheadline)
//                                .fontWeight(.semibold)
//                            Spacer()
//                        }
//                        .padding(.horizontal)
                        
                        // Graphical DatePicker (shows calendar grid)
                        DatePicker(
                            "",
                            selection: $selectedDate,
                            in: ...Date(),
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .padding(.horizontal, 6)
                    }
                        .padding(.vertical, 10)
                )
                .frame(maxWidth: .infinity)
            
            // Confirm button
            Button(action: onConfirm) {
                Text("Confirm Visit")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(PrimaryButtonStyle())
            
            // Secondary "I'm Here Now"
            Button(action: onHereNow) {
                Text("I'm Here Now")
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .foregroundColor(.primary)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemGray6))
            )
        }
    }
    
    private func monthYearString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.accent)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .shadow(color: Color.accent.opacity(0.25), radius: 8, x: 0, y: 6)
    }
}

//#Preview {
//    CaptureMomentView(place: Place(id: UUID(), name: "India", rating: 34, rating_count: 345, description: "asd", category: "food", latitude: 324, longitude: 2342, phone_number: "asda", email: "asda", website: "adsa", image_urls: [], is_visited: false, created_at: "asd"))
//}
extension Date {
    var millisecondsSince1970: Int64 {
        Int64(self.timeIntervalSince1970 * 1000)
    }
}
