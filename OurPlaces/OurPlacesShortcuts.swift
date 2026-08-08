//
//  OurPlacesShortcuts.swift
//  OurPlaces
//
//  Created by apple on 13/02/26.
//


import AppIntents

struct OurPlacesShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .blue
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PickRandomPlaceIntent(),
            phrases: [
                "Pick a place to go tonight in \(.applicationName)",
                "Suggest a random place in \(.applicationName)",
                "Where should I go tonight in \(.applicationName)"
            ],
            shortTitle: "Pick Place",
            systemImageName: "mappin.and.ellipse"
        )
    }
}
