//
//  TimelineViewModel.swift
//  OurPlaces
//
//  Created by apple on 16/02/26.
//


import SwiftUI

@MainActor
final class TimelineViewModel: ObservableObject {
    
    // MARK: - Published
    
    @Published var groupedVisits: [(date: Date, visits: [VisitWithPlace])] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Timeline Model
    
    struct VisitWithPlace: Identifiable, Hashable {
        let id: UUID
        let visitDate: Date
        let place: Place
        var photos: [Photo]
    }
    
    // MARK: - Fetch Timeline
    
    func fetchTimeline() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            guard let userId = SupabaseManager.shared.client.auth.currentUser?.id else {
                return
            }
            
            // 🔥 1️⃣ Fetch visits with place JOIN
            let visitsResponse: [VisitWithPlaceResponse] = try await SupabaseManager.shared.client
                .from("visits")
                .select("""
                        id,
                        visited_at_millis,
                        place:places (*)
                        """)
                .eq("user_id", value: userId)
                .execute()
                .value
            
            // 🔥 2️⃣ Fetch all photos in one call
            let photos: [Photo] = try await SupabaseManager.shared.client
                .from("visit_images")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            
            let photosByVisit = Dictionary(grouping: photos) { $0.visit_id }
            
            // 🔥 3️⃣ Convert to UI Model
            let visits: [VisitWithPlace] = visitsResponse.map { item in
                VisitWithPlace(
                    id: item.id,
                    visitDate: dateFromMilliseconds(item.visited_at_millis),
                    place: item.place,
                    photos: photosByVisit[item.id] ?? []
                )
            }
            
            let sorted = visits.sorted { $0.visitDate > $1.visitDate }
            
            let grouped = Dictionary(grouping: sorted) {
                Calendar.current.startOfDay(for: $0.visitDate)
            }
            
            self.groupedVisits = grouped
                .map { (date: Date, visits: [VisitWithPlace]) in
                    (date: date, visits: visits)
                }
                .sorted { $0.date > $1.date }
            
        } catch {
            errorMessage = error.localizedDescription
            print("Timeline fetch error:", error)
        }
    }
    
    // MARK: - Helpers
    
    private func dateFromMilliseconds(_ milliseconds: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}
