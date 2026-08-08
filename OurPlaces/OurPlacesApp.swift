//
//  OurPlacesApp.swift
//  OurPlaces
//
//  Created by SAIRAM  on 26/12/25.
//

import SwiftUI

@main
struct OurPlacesApp: App {
    let persistenceController = PersistenceController.shared
    init() {
        OurPlacesShortcuts.updateAppShortcutParameters()
        ImageCache.shared.clearExpired(olderThan: 30)
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
