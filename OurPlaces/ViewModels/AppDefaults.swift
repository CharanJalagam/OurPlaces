//
//  AppDefaults.swift
//  OurPlaces
//
//  Created by SAIRAM  on 21/03/26.
//

import Foundation


struct AppDefaults {
    static let distanceKey = "distance_range"
    
    static var distance: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: distanceKey)
            return value == 0 ? 50 : value // default 50
        }
        set {
            UserDefaults.standard.set(newValue, forKey: distanceKey)
        }
    }
}
