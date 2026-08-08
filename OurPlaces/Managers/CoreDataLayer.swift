//
//  CoreDataLayer.swift
//  OurPlaces
//
//  Created by apple on 25/01/26.
//

import Foundation
import CoreData

final class CoreDataLayer {
    
    static let shared = CoreDataLayer()
    private init() {}
    
    var selectedPlace: Place?
    // MARK: - Persistent Container
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "OurPlaces")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data load failed: \(error)")
            }
        }
        return container
    }()
    
    // MARK: - Context
    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    // MARK: - Save
    func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Core Data save error:", error)
        }
    }
}
extension CoreDataLayer {
    
    func addPlaces(_ places: [Place]) {
        
        for place in places {
            let cdPlace = Places(context: context)
            cdPlace.id = place.id
            cdPlace.name = place.name
            cdPlace.latitude = place.latitude
            cdPlace.longitude = place.longitude
            cdPlace.category = place.category
            cdPlace.created_at = place.created_at
            cdPlace.desc = place.description
            cdPlace.email = place.email
            if let data = try? JSONEncoder().encode(place.image_urls),
               let jsonString = String(data: data, encoding: .utf8) {
                cdPlace.image_urls = jsonString
            }
            cdPlace.is_visited = place.is_visited
            cdPlace.phone_number = place.phone_number
            cdPlace.rating = place.rating ?? 0
            cdPlace.rating_count = Int32(place.rating_count)
        }
        
        saveContext()
    }
    
    func fetchPlaces() -> [Place] {
        let request: NSFetchRequest<Places> = Places.fetchRequest()
        
        do {
            return try context.fetch(request).map {
                Place(
                    id: $0.id ?? UUID(),
                    name: $0.name ?? "",
                    rating: $0.rating,
                    rating_count: Int($0.rating_count),
                    description: $0.desc,
                    category: $0.category ?? "" ,
                    latitude: $0.latitude,
                    longitude: $0.longitude,
                    phone_number: $0.phone_number ?? "",
                    email: $0.email ?? "",
                    website: $0.website ?? "",
                    image_urls:($0.image_urls ?? "").toStringArray(),
                    is_visited: $0.is_visited, is_private: $0.is_private,
                    created_at: $0.created_at ?? ""
                )
            }
        } catch {
            print("Fetch error:", error)
            return []
        }
    }
    func fetchPlace(by name: String) -> Place? {
        let request: NSFetchRequest<Places> = Places.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "name ==[c] %@", name)
        
        do {
            if let place = try context.fetch(request).first {
                return Place(
                    id: place.id ?? UUID(),
                    name: place.name ?? "",
                    rating: place.rating,
                    rating_count: Int(place.rating_count),
                    description: place.desc,
                    category: place.category ?? "",
                    latitude: place.latitude,
                    longitude: place.longitude,
                    phone_number: place.phone_number ?? "",
                    email: place.email ?? "",
                    website: place.website ?? "",
                    image_urls: (place.image_urls ?? "").toStringArray(),
                    is_visited: place.is_visited,
                    is_private: place.is_private,
                    created_at: place.created_at ?? ""
                )
            }
        } catch {
            print("Fetch single place error:", error)
        }
        
        return nil
    }

    func deleteAllPlaces() {
        let request: NSFetchRequest<NSFetchRequestResult> = Places.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try context.execute(deleteRequest)
            saveContext()
        } catch {
            print("Delete error:", error)
        }
    }
}

extension String {
    func toStringArray() -> [String] {
        guard
            let data = self.data(using: .utf8),
            let array = try? JSONDecoder().decode([String].self, from: data)
        else {
            return []
        }
        return array
    }
}
