//
//  ProfileView.swift
//  OurPlaces
//
//  Created by SAIRAM  on 03/01/26.
//


import SwiftUI
import PhotosUI
import WidgetKit

struct ProfileView: View {
    
    @State private var isEditing = false
    @State private var name: String = "--"
    @State private var email: String = "--"
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var profileUIImage: UIImage? = UIImage(named: "profile_placeholder")
    @State private var showLoader = false
    @EnvironmentObject var authState: AppAuthState
    @State private var showDistancePicker = false
    @State private var selectedDistance = AppDefaults.distance
    @State private var originalName: String = ""
    @State private var originalImageData: Data?
    
    @State private var userObj: users?
    let authVm = SupabaseAuthVM()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.background)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        
                        profileImageSection
                        nameSection
                        editButton
                        
                        preferencesSection
                        accountSection
                        
                        logoutButton
                        appVersion
                    }
                    .padding(.top, 24)
                }

                if showLoader {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()

                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.accent)
                        .scaleEffect(1.2)
                }
            }
        }
        .onAppear{
            Task{
                do{
                    userObj = try await authVm.fetchUser()
                    name = userObj?.full_name ?? "--"
                    email = userObj?.email ?? "--"
                    
                    // 🔥 Load profile image from URL
                    if let urlString = userObj?.avatar_url,
                       let url = URL(string: urlString) {
                        
                        let (data, _) = try await URLSession.shared.data(from: url)
                        
                        if let uiImage = UIImage(data: data) {
                            await MainActor.run {
                                profileUIImage = uiImage
                                profileImage = Image(uiImage: uiImage)
                            }
                        }
                    }
                    
                }catch{
                    print(error)
                }
            }
        }
    }
}
private extension ProfileView {
    
    var profileImageSection: some View {
        ZStack(alignment: .bottomTrailing) {
            
            (profileImage ?? Image("profile_placeholder"))
                .resizable()
                .scaledToFill()
                .frame(width: 110, height: 110)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color(.systemGray4), lineWidth: 2)
                )

            if isEditing {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Image(systemName: "pencil")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                }
                .onChange(of: selectedItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            profileImage = Image(uiImage: uiImage)
                            profileUIImage = uiImage
                        }
                    }
                }
            }
        }
    }
}
private extension ProfileView {
    
    var nameSection: some View {
        VStack(spacing: 4) {
            
            if isEditing {
                TextField("Name", text: $name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 40)
            } else {
                Text(name)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Text(email)
                .foregroundColor(.gray)
                .font(.subheadline)
        }
    }
}
private extension ProfileView {
    
    var editButton: some View {
        Button {
            if isEditing {
                Task {
                    showLoader = true
                    
                    do {
                        let isNameChanged = name != originalName
                        
                        let currentImageData = profileUIImage?.jpegData(compressionQuality: 0.8)
                        let isImageChanged = currentImageData != originalImageData
                        
                        let isDefaultImage = profileUIImage == UIImage(named: "profile_placeholder")
                        
                        // 🔥 CASE 1: Only name changed
                        if isNameChanged && (!isImageChanged || isDefaultImage) {
                            
                            try await authVm.updateUserName(
                                userId: userObj?.id ?? UUID(),
                                name: name
                            )
                        }
                        
                        // 🔥 CASE 2: Image changed (and not default)
                        else if isImageChanged && !isDefaultImage {
                            
                            try await authVm.uploadProfilePhoto(
                                userId: userObj?.id ?? UUID(),
                                image: profileUIImage!,
                                userName: name
                            )
                        }
                        
                        // 🔥 CASE 3: Nothing changed → do nothing
                        
                        await MainActor.run {
                            withAnimation {
                                isEditing = false
                                showLoader = false
                            }
                        }
                        
                    } catch {
                        print("❌ Update failed:", error)
                        showLoader = false
                    }
                }
            } else {
                withAnimation {
                    isEditing = true
                }
            }
        } label: {
            Text(isEditing ? "Done" : "Edit Profile")
                .fontWeight(.semibold)
                .frame(maxWidth: 120)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(30)
        }
        .padding(.horizontal, 24)
    }

}
private extension ProfileView {
    
    var preferencesSection: some View {
        SectionCard(title: "Preferences") {
           
            NavigationLink {
                SavedPlacesView()
                    .navigationTitle("Your Places")
                    .toolbar(.hidden, for: .tabBar)
            } label: {
                RowItem(icon: "heart.fill", title: "Your Places")
            }
            VStack(spacing: 8) {
                
                Button {
                    withAnimation {
                        showDistancePicker.toggle()
                    }
                } label: {
                    RowItem(
                        icon: "location.fill",
                        title: "Distance Range",
                        trailing: "\(AppDefaults.distance) km"
                    )
                }
                
                if showDistancePicker {
                    Picker("Distance", selection: $selectedDistance) {
                        ForEach(10...100, id: \.self) { value in
                            Text("\(value) km").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                    .clipped()
                    .onChange(of: selectedDistance) { newValue in
                        AppDefaults.distance = newValue
                    }
                }
            }
        }
    }
    
    var accountSection: some View {
        SectionCard(title: "Account") {
            RowItem(icon: "bookmark.fill", title: "Saved Places")
            NavigationLink {
                MemoriesView()
                    .navigationTitle("All Memories")
                    .toolbar(.hidden, for: .tabBar)
            } label: {
                RowItem(icon: "arrow.down.circle.fill", title: "All Memories")
            }
        }
    }
    
    
//    var settingsSection: some View {
//        SectionCard(title: "Settings") {
//            HStack {
//                RowItem(icon: "bell.fill", title: "Notifications",trailing: "")
//                Spacer()
//                Toggle("", isOn: .constant(false))
//                    .labelsHidden()
//            }
//            RowItem(icon: "lock.fill", title: "Privacy & Security")
//        }
//    }
}
private extension ProfileView {
    
    var logoutButton: some View {
        Button(role: .destructive) {
            Task {
                await authVm.logout {
                    authState.isLoggedIn = false
                    CoreDataLayer.shared.deleteAllPlaces()
                    ImageCache.shared.clearAll()
                    WidgetDataManager.shared.setLoginState(false)
                    WidgetCenter.shared.reloadAllTimelines()
                } onError: { _ in
                    
                }
            }

        } label: {
            Text("Log Out")
                .frame(maxWidth: .infinity)
                .padding()
        }
        .background(Color(.white))
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }
    
    var appVersion: some View {
        Text("App Version 1.0.2")
            .foregroundColor(.gray)
            .font(.footnote)
            .padding(.top, 12)
    }
}
struct SectionCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundColor(.gray)
            
            VStack(spacing: 12) {
                content
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(14)
        }
        .padding(.horizontal, 24)
    }
}

struct RowItem: View {
    let icon: String
    let title: String
    var trailing: String? = nil
    
    var body: some View {
        VStack{
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accent)
                
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                
                if let trailing {
                    Text(trailing)
                        .foregroundColor(.gray)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
        }.padding(.vertical, 6)
    }
}
#Preview {
    ProfileView()
}
