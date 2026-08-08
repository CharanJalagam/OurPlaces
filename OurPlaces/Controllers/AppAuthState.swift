//
//  AppAuthState.swift
//  OurPlaces
//
//  Created by apple on 17/01/26.
//

import Foundation


final class AppAuthState: ObservableObject {
    @Published var isLoggedIn: Bool = false
}
