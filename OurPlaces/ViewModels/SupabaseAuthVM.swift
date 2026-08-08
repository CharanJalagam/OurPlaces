//
//  SupabaseAuthVM.swift
//  OurPlaces
//
//  Created by SAIRAM  on 27/12/25.
//


import Foundation
import Supabase
import CoreData
import UIKit

final class SupabaseAuthVM {

    private let supabase = SupabaseManager.shared.client

    // MARK: - SIGN UP
    func signUp(
        email: String,
        password: String,
        userName: String,
        onLoading: @escaping (Bool) -> Void,
        onSuccess: @escaping () -> Void,
        onError: @escaping (String) -> Void
    ) {

        DispatchQueue.main.async {
            onLoading(true)
        }

        Task {
            do {
                let response = try await supabase.auth.signUp(
                    email: email,
                    password: password
                )
                print(response)
                 let userID = response.user.id
                    try await supabase
                        .from("users")
                        .update(["full_name": userName])
                        .eq("id", value: userID)
                        .execute()
                

                await MainActor.run {
                    onLoading(false)
                    onSuccess()
                }

            } catch {
                await MainActor.run {
                    onLoading(false)
                    onError(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - LOGIN
    func login(
        email: String,
        password: String,
        onLoading: @escaping (Bool) -> Void,
        onSuccess: @escaping () -> Void,
        onError: @escaping (String) -> Void
    ) {

        DispatchQueue.main.async {
            onLoading(true)
        }

        Task {
            do {
                try await supabase.auth.signIn(
                    email: email,
                    password: password
                )

                await MainActor.run {
                    onLoading(false)
                    onSuccess()
                }

            } catch {
                await MainActor.run {
                    onLoading(false)
                    onError(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - LOGOUT
    func logout(
        onSuccess: @escaping () -> Void,
        onError: @escaping (String) -> Void
    ) {

        Task {
            do {
                try await supabase.auth.signOut()

                await MainActor.run {
                    onSuccess()
                }

            } catch {
                await MainActor.run {
                    onError(error.localizedDescription)
                }
            }
        }
    }
    func isUserLoggedIn() async -> Bool {
        do {
            let session = try await supabase.auth.session
            return session != nil
        } catch {
            return false
        }
    }
    func fetchUser() async throws -> users {
        
        guard let userId = supabase.auth.currentUser?.id else {
            throw NSError(domain: "Auth", code: 401)
        }
        
        let response = try await supabase
            .from("users")
            .select("*")
            .eq("id", value: userId)
            .limit(1)
            .execute()
        
        let user = try JSONDecoder().decode([users].self, from: response.data)
        return user.first!
    }
    
    func fetchPlaces() async {
        do {
            
            guard let userId = supabase.auth.currentUser?.id else {
                print("User not logged in")
                return
            }
            
            let fetchedPlaces: [Place] = try await supabase
                .from("places")
                .select()
                .or("user_id.is.null,user_id.eq.\(userId.uuidString)")
                .order("is_private", ascending: true)   // Public first
                .order("rating", ascending: false, nullsFirst: false)
                .execute()
                .value
            
            print("Fetched Places:", fetchedPlaces)
            
            CoreDataLayer.shared.deleteAllPlaces()
            CoreDataLayer.shared.addPlaces(fetchedPlaces)
            
        } catch {
            print("Error fetching places:", error)
        }
    }
    
    func insertVisit(
        placeId: UUID,
        visitedAtMillis: Int64
    )  async throws -> Visit? {
        
        guard let userId = supabase.auth.currentUser?.id else {
            throw NSError(domain: "Auth", code: 401)
        }
        
        let visit = VisitInsert(
            user_id: userId,
            place_id: placeId,
            visited_at_millis: visitedAtMillis
        )
        
        try await supabase
            .from("visits")
            .insert(visit)
            .execute()
        
        return try await fetchVisit(placeId: placeId, visitedAtMillis: visitedAtMillis) ?? nil
    }
    func fetchVisit(
        placeId: UUID,
        visitedAtMillis: Int64
    ) async throws -> Visit? {
        
        guard let userId = supabase.auth.currentUser?.id else {
            throw NSError(domain: "Auth", code: 401)
        }
        
        let response = try await supabase
            .from("visits")
            .select("*")
            .eq("user_id", value: userId)
            .eq("place_id", value: placeId)
            .eq("visited_at_millis", value: Int(visitedAtMillis))
            .limit(1)
            .execute()
        
        let visits = try JSONDecoder().decode([Visit].self, from: response.data)
        return visits.first
    }

    func isPlaceVisited(placeId: UUID) async throws -> Bool {
        guard let userId = supabase.auth.currentUser?.id else {
            return false
        }
        
        let response = try await supabase
            .from("visits")
            .select("id", count: .exact)
            .eq("user_id", value: userId)
            .eq("place_id", value: placeId)
            .limit(1)
            .execute()
        
        return (response.count ?? 0) > 0
    }
    func insertVisitImages(
        visitId: UUID,
        imageURLs: [String],
        timeStamp: Int64
    ) async throws {
        
        guard let userId = supabase.auth.currentUser?.id else {
            throw NSError(domain: "Auth", code: 401)
        }
        
//        let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
        
        let rows = imageURLs.map {
            VisitImageInsert(
                visit_id: visitId,
                user_id: userId,
                image_url: $0,
                created_at_millis: timeStamp
            )
        }
        
        try await supabase
            .from("visit_images")
            .insert(rows)
            .execute()
    }
    func fetchImagesForPlace(
        placeId: UUID
    ) async throws -> [VisitImage] {
        
        guard let userId = supabase.auth.currentUser?.id else {
            throw NSError(domain: "Auth", code: 401)
        }
        
        let response = try await supabase
            .from("visit_images")
            .select("""
            image_url,
            created_at_millis,
            visits!inner(place_id)
        """)
            .eq("user_id", value: userId)
            .eq("visits.place_id", value: placeId)
            .order("created_at_millis", ascending: false)
            .execute()
        
        return try JSONDecoder().decode([VisitImage].self, from: response.data)
    }
    
    func uploadProfilePhoto(
        userId: UUID,
        image: UIImage,
        userName: String
    ) async throws {
        
        // 1️⃣ Convert image
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "ImageConversion", code: 0)
        }
        
        let userIdString = userId.uuidString
        
        // 2️⃣ Create file path
        let fileName = "\(UUID().uuidString).jpg"
        let filePath = "\(userIdString)/\(fileName)"
        
        // 3️⃣ Upload to Supabase Storage (bucket: userProfiles)
        try await supabase.storage
            .from("userProfiles")
            .upload(
                filePath,
                data: imageData,
                options: FileOptions(
                    contentType: "image/jpeg",
                    upsert: true // allow replacing profile photo
                )
            )
        
        // 4️⃣ Get public URL
        let publicURL = try supabase.storage
            .from("userProfiles")
            .getPublicURL(path: filePath)
        
        // 5️⃣ Update users table
        try await supabase
            .from("users")
            .update([
                "avatar_url": publicURL.absoluteString,
                "full_name": userName
            ])
            .eq("id", value: userIdString)
            .execute()
    }
    func updateUserName(userId: UUID, name: String) async throws {
        
        try await supabase
            .from("users")
            .update([
                "full_name": name
            ])
            .eq("id", value: userId.uuidString)
            .execute()
    }
    func imageToData(_ image: UIImage) -> Data? {
        return image.jpegData(compressionQuality: 0.7)
    }

    
    func fetchUniqueVisitedPlaces() async -> [UUID] {
        do {
            guard let userId = SupabaseManager.shared.client.auth.currentUser?.id else { return [] }
            
            let visits: [Visit] = try await SupabaseManager.shared.client
                .from("visits")
                .select("place_id")
                .eq("user_id", value: userId)
                .execute()
                .value
            
            let uniquePlaceIds = Array(Set(visits.map { $0.place_id }))
            
            return uniquePlaceIds as? [UUID] ?? []
            
        } catch {
            print("Error fetching unique places:", error)
            return []
        }
    }
    func addPrivatePlace(
        name: String,
        latitude: Double,
        longitude: Double,
        category: String,
        description: String
    ) async throws {
        
        guard let user = try? await supabase.auth.session.user else {
            throw NSError(domain: "UserNotLoggedIn", code: 401)
        }
        
        let newPlace = PrivatePlaceInsert(
            name: name,
            latitude: latitude,
            longitude: longitude,
            category: category,
            user_id: user.id,
            description: description,
            image_urls: [],
            is_private: true
        )
        
        try await supabase
            .from("places")
            .insert(newPlace)
            .execute()
    }
}
