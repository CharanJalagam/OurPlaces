//
//  PickRandomPlaceIntent.swift
//  OurPlaces
//
//  Created by apple on 13/02/26.
//

import AppIntents
import SwiftUI

struct PickRandomPlaceIntent: AppIntent {
    
    // MARK: - Intent Metadata
   
    static var title: LocalizedStringResource = "Pick Random Place"
    
    static var description = IntentDescription(
        "Suggests a random place to visit tonight."
    )
    
    static var openAppWhenRun: Bool = true   // Opens app after Siri response
    
    // MARK: - Perform
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        
        // Call your shared service
        let service = PlaceSuggestionService.shared
        
        guard let place = try await service.pickRandomPlace() else {
            return .result(
                dialog: "I couldn't find any places right now. Try again later."
            )
        }
        
        // Build spoken response
        let spokenResponse = "How about \(place.name)? It’s a great choice for tonight."
        CoreDataLayer.shared.selectedPlace = place
        return .result(
            dialog: IntentDialog(stringLiteral: spokenResponse)
        )
    }
}
final class PlaceSuggestionService {
    
    static let shared = PlaceSuggestionService()
    private let supabase = SupabaseAuthVM()
    
    private init() {}
    
    func pickRandomPlace() async throws -> Place? {
        // Fetch places (local DB / API / Supabase)
        let places = try await fetchPlaces()
        return places.randomElement()
    }
    
    private func fetchPlaces() async throws -> [Place] {
        if  await supabase.isUserLoggedIn(){
            let places = CoreDataLayer.shared.fetchPlaces()
            if !places.isEmpty{
                return places
            }else{
                await supabase.fetchPlaces()
                return CoreDataLayer.shared.fetchPlaces()
                
            }
        }
       return []
    }
}
