//
//  SavedPlacesViewModel.swift
//  OurPlaces
//
//  Created by SAIRAM  on 21/03/26.
//

import Foundation


@MainActor
final class SavedPlacesViewModel: ObservableObject {
    
    @Published var places: [Place] = []
    
    @Published var isLoading = false
    @Published var isDeleting = false
    
    @Published var showDeleteAlert = false
    @Published var selectedPlace: Place?
    
    @Published var showSuccessToast = false
    @Published var successMessage = ""
    
    private let supabase = SupabaseManager.shared.client
    // MARK: - Fetch
    func fetchPlaces() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let user = try? await supabase.auth.session.user else {
                        print("User not logged in")
                        return
                    }
            let places: [Place] = try await supabase
                       .from("places")
                       .select()
                       .eq("user_id", value: user.id.uuidString)
                       .order("created_at", ascending: false)
                       .execute()
                       .value
            
            self.places = places
            
        } catch {
            print("Fetch error:", error.localizedDescription)
        }
    }
    
    // MARK: - Delete
    func deletePlace() async {
        guard let place = selectedPlace else { return }
        
        isDeleting = true
        defer { isDeleting = false }
        
        do {
            try await supabase
                .from("places")
                .delete()
                .eq("id", value: place.id)
                .execute()
            
            places.removeAll { $0.id == place.id }
            
            successMessage = "Place deleted successfully"
            showSuccessToast = true
            
        } catch {
            print("Delete error:", error.localizedDescription)
        }
    }
}
