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
            // Best-effort server sign-out. We clear local auth state regardless
            // (see caller), so logout works even when the device is offline.
            try? await supabase.auth.signOut()

            await MainActor.run {
                onSuccess()
            }
        }
    }

    /// Offline check — reflects the locally-stored session only (no network
    /// call), so it is safe to call while offline.
    func isUserLoggedIn() -> Bool {
        supabase.auth.currentUser != nil
    }

    // MARK: - PASSWORD RESET (OTP)

    /// Sends a 6-digit recovery code to the given email.
    func sendPasswordResetCode(email: String) async throws {
        let normalized = Validators.normalizeEmail(email)
        print("🔐 [Reset] Sending reset code to \(normalized)")
        do {
            try await supabase.auth.resetPasswordForEmail(normalized)
            print("🔐 [Reset] Reset code sent ✅")
        } catch {
            print("🔐 [Reset] Send failed ❌: \(error)")
            throw error
        }
    }

    /// Verifies the recovery code. On success the user has a valid session,
    /// which lets us update the password immediately.
    func verifyPasswordResetCode(email: String, code: String) async throws {
        let normalized = Validators.normalizeEmail(email)
        let token = code.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔐 [Reset] Verifying code \(token) for \(normalized)")
        do {
            try await supabase.auth.verifyOTP(email: normalized, token: token, type: .recovery)
            print("🔐 [Reset] Code verified, session established ✅ (user: \(supabase.auth.currentUser?.email ?? "nil"))")
        } catch {
            print("🔐 [Reset] Verify failed ❌: \(error)")
            throw error
        }
    }

    /// Updates the currently signed-in (recovery) user's password.
    func updatePassword(newPassword: String) async throws {
        print("🔐 [Reset] Updating password…")
        do {
            _ = try await supabase.auth.update(user: UserAttributes(password: newPassword))
            print("🔐 [Reset] Password updated ✅")
        } catch {
            print("🔐 [Reset] Password update failed ❌: \(error)")
            throw error
        }
    }

    /// Permanently deletes the current user's account and all their data.
    /// The actual deletion runs in the `delete-account` Edge Function (service
    /// role) — the client can't delete an auth user directly. The user's JWT is
    /// sent automatically so the function only deletes the caller's own account.
    func deleteAccount() async throws {
        print("🔐 [Account] Requesting account deletion…")
        do {
            try await supabase.functions.invoke("delete-account")
            // The account is gone — clear the now-invalid local session too.
            try? await supabase.auth.signOut()
            print("🔐 [Account] Account deleted ✅")
        } catch {
            print("🔐 [Account] Deletion failed ❌: \(error)")
            throw error
        }
    }

    /// After a social sign-in, fill the profile's name/avatar from the provider —
    /// but only fields the user hasn't set yet, so we never overwrite an edit.
    func backfillProfileIfNeeded(fullName: String?, avatarURL: String?) async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        do {
            let rows: [users] = try await supabase
                .from("users")
                .select("*")
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            let existing = rows.first

            var updates: [String: String] = [:]
            if (existing?.full_name ?? "").isEmpty,
               let fullName, !fullName.isEmpty {
                updates["full_name"] = fullName
            }
            if (existing?.avatar_url ?? "").isEmpty,
               let avatarURL, !avatarURL.isEmpty {
                updates["avatar_url"] = avatarURL
            }

            guard !updates.isEmpty else {
                print("🔐 [Social] Profile already set — no backfill needed")
                return
            }

            try await supabase
                .from("users")
                .update(updates)
                .eq("id", value: userId)
                .execute()
            print("🔐 [Social] Backfilled profile: \(updates.keys.joined(separator: ", "))")
        } catch {
            print("🔐 [Social] Profile backfill failed: \(error)")
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

    
    /// One representative (most recent) image URL per visited place, fetched in
    /// a single query — so map pins don't each make their own network call.
    func fetchVisitedPlaceThumbnails() async -> [UUID: String] {
        guard let userId = supabase.auth.currentUser?.id else { return [:] }
        do {
            let response = try await supabase
                .from("visit_images")
                .select("image_url, created_at_millis, visits!inner(place_id)")
                .eq("user_id", value: userId)
                .order("created_at_millis", ascending: false)
                .execute()

            let rows = try JSONDecoder().decode([VisitImageWithPlace].self, from: response.data)
            var map: [UUID: String] = [:]
            for row in rows where map[row.visits.place_id] == nil {
                map[row.visits.place_id] = row.image_url   // first = most recent
            }
            return map
        } catch {
            print("Error fetching visited thumbnails:", error)
            return [:]
        }
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
        description: String,
        images: [UIImage] = []
    ) async throws {

        guard let user = try? await supabase.auth.session.user else {
            throw NSError(domain: "UserNotLoggedIn", code: 401)
        }

        // Upload any selected photos first, then save their URLs with the place.
        let imageURLs = try await uploadPlaceImages(images, userId: user.id)

        let newPlace = PrivatePlaceInsert(
            name: name,
            latitude: latitude,
            longitude: longitude,
            category: category,
            user_id: user.id,
            description: description,
            image_urls: imageURLs,
            is_private: true
        )

        try await supabase
            .from("places")
            .insert(newPlace)
            .execute()
    }

    /// Uploads place photos to storage and returns their public URLs.
    private func uploadPlaceImages(_ images: [UIImage], userId: UUID) async throws -> [String] {
        var urls: [String] = []
        for image in images {
            guard let data = image.jpegData(compressionQuality: 0.8) else { continue }
            // User ID must be the FIRST folder to satisfy the Storage RLS policy
            // (same convention as profile/visit uploads).
            let path = "\(userId.uuidString)/places/\(UUID().uuidString).jpg"
            try await supabase.storage
                .from("visit-images")
                .upload(
                    path,
                    data: data,
                    options: FileOptions(contentType: "image/jpeg", upsert: true)
                )
            let publicURL = try supabase.storage
                .from("visit-images")
                .getPublicURL(path: path)
            urls.append(publicURL.absoluteString)
        }
        return urls
    }
}

/// Decodes a visit_images row joined with its visit's place_id (for batch thumbnails).
private struct VisitImageWithPlace: Decodable {
    let image_url: String
    let created_at_millis: Int64
    let visits: VisitRef
    struct VisitRef: Decodable { let place_id: UUID }
}
