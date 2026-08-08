//
//  Place.swift
//  OurPlaces
//
//  Created by apple on 10/01/26.
//


import MapKit
import SwiftUI

struct Place: Identifiable, Decodable, Hashable {
    let id: UUID
    let name: String
    let rating: Double?
    let rating_count: Int
    let description: String?
    let category: String
    let latitude: Double
    let longitude: Double
    let phone_number: String?
    let email: String?
    let website: String?
    let image_urls: [String]?
    let is_visited: Bool
    let is_private: Bool
    let created_at: String
}
struct PlaceCategory: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let icon: String
}

struct VisitInsert: Encodable {
    let user_id: UUID
    let place_id: UUID
    let visited_at_millis: Int64
}
struct Visit: Decodable {
    let id: UUID?
    let user_id: UUID?
    let place_id: UUID?
    let visited_at_millis: Int64?
}
struct VisitImageInsert: Encodable {
    let visit_id: UUID
    let user_id: UUID
    let image_url: String
    let created_at_millis: Int64
}
struct VisitImage: Decodable, Hashable {
    let image_url: String
    let created_at_millis: Int64
}
struct users: Codable{
    let id: UUID
    let full_name: String?
    let email: String?
    let avatar_url: String?
    let created_at: String?
}
struct PrivatePlaceInsert: Encodable {
    let name: String
    let latitude: Double
    let longitude: Double
    let category: String
    let user_id: UUID
    let description: String
    let image_urls: [String]
    let is_private: Bool
}
