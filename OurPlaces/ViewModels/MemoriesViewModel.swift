import SwiftUI
struct Photo: Identifiable, Decodable, Hashable {
    let id: UUID
    let image_url: String
    let created_at_millis: Int64
    let visit_id: UUID
}
struct VisitWithPlaceResponse: Decodable {
    let id: UUID
    let visited_at_millis: Int64
    let place: Place
}


@MainActor
final class MemoriesViewModel: ObservableObject {
    
    @Published var groupedVisits: [(date: Date, visits: [VisitWithPlace])] = []
    @Published var groupedPhotos: [(date: Date, photos: [Photo])] = []
    
    @Published var isLoadingVisits = false
    @Published var isLoadingPhotos = false
    
    struct VisitWithPlace: Identifiable, Hashable {
        let id: UUID
        let visitDate: Date
        let place: Place
    }
    
    func fetchVisits() async {
        guard !isLoadingVisits else { return }
        isLoadingVisits = true
        defer { isLoadingVisits = false }
        do {
            let userId = SupabaseManager.shared.client.auth.currentUser?.id
            let visits: [Visit] = try await SupabaseManager.shared.client
                .from("visits")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            
            let sortedVisits = visits.sorted { (lhs: Visit, rhs: Visit) in
                lhs.visited_at_millis ?? 0 > rhs.visited_at_millis ?? 0
            }

            
            var visitWithPlaces: [VisitWithPlace] = []
            
            for visit in sortedVisits {
                let place: Place = try await SupabaseManager.shared.client
                    .from("places")
                    .select()
                    .eq("id", value: visit.place_id)
                    .single()
                    .execute()
                    .value
                
                visitWithPlaces.append(
                    VisitWithPlace(
                        id: visit.id!,
                        visitDate: dateFromMilliseconds(visit.visited_at_millis ?? 0),
                        place: place
                    )
                )
            }
            
            let grouped = Dictionary(grouping: visitWithPlaces) {
                Calendar.current.startOfDay(for: $0.visitDate)
            }
            
            self.groupedVisits = grouped
                .map { (date: Date, visits: [VisitWithPlace]) in
                    (date: date, visits: visits)
                }
                .sorted { $0.date > $1.date }
            
        } catch {
            print("Supabase error:", error)
        }
    }
    func fetchPlaceVisitCounts() async -> [UUID: Int] {
        do {
            guard let userId = SupabaseManager.shared.client.auth.currentUser?.id else {
                return [:]
            }
            
            let visits: [Visit] = try await SupabaseManager.shared.client
                .from("visits")
                .select("place_id")
                .eq("user_id", value: userId)
                .execute()
                .value
            
            let grouped = Dictionary(grouping: visits, by: { $0.place_id })
            
            let visitCounts = grouped.mapValues { $0.count }
            
            return visitCounts as? [UUID : Int] ?? [UUID() : 0]
            
        } catch {
            print("Error fetching visit counts:", error)
            return [:]
        }
    }

    func dateFromMilliseconds(_ milliseconds: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
    func fetchPhotos() async {
        guard !isLoadingPhotos else { return }
        isLoadingPhotos = true
        defer { isLoadingPhotos = false }

        do {
            guard let userId = SupabaseManager.shared.client.auth.currentUser?.id else {
                return
            }
            
            let photos: [Photo] = try await SupabaseManager.shared.client
                .from("visit_images")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            
            // Sort by latest first
            let sortedPhotos = photos.sorted { (lhs: Photo, rhs: Photo) in
                lhs.created_at_millis > rhs.created_at_millis
            }
            
            // Group by date
            let grouped = Dictionary(grouping: sortedPhotos) {
                Calendar.current.startOfDay(
                    for: dateFromMilliseconds($0.created_at_millis)
                )
            }
            
            self.groupedPhotos = grouped
                .map { (date: Date, photos: [Photo]) in
                    (date: date, photos: photos)
                }
                .sorted { $0.date > $1.date }
            
        } catch {
            print("Photo fetch error:", error)
        }
    }

    func fetchVisitPhotos(visitId: String) async -> [Photo] {
        do {
            guard let userId = SupabaseManager.shared.client.auth.currentUser?.id else {
                return []
            }
            
            let photos: [Photo] = try await SupabaseManager.shared.client
                .from("visit_images")
                .select()
                .eq("user_id", value: userId)
                .eq("visit_id", value: visitId)
                .execute()
                .value

            return photos
           
        } catch {
            print("Photo fetch error:", error)
            return []
        }
    }
}
