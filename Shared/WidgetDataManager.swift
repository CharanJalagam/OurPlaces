//
//  WidgetDataManager.swift
//  OurPlaces
//
//  Created by SAIRAM  on 27/03/26.
//

import Foundation
import UIKit


enum AppConstants {
    static let appGroupID = "group.com.OurPlaces.shared"
}

final class WidgetDataManager {
    
    static let shared = WidgetDataManager()
    
    private let sharedDefaults = UserDefaults(suiteName: AppConstants.appGroupID)
    
    private init() {}
    
    // MARK: - Keys
    private enum Keys {
        static let isLoggedIn = "isLoggedIn"
        static let lastImagePath = "lastImagePath"
    }
    
    // MARK: - Login State
    
    func setLoginState(_ isLoggedIn: Bool) {
        sharedDefaults?.set(isLoggedIn, forKey: Keys.isLoggedIn)
    }
    
    func getLoginState() -> Bool {
        return sharedDefaults?.bool(forKey: Keys.isLoggedIn) ?? false
    }
    
    // MARK: - Save Image
    
    func saveLastImage(_ image: UIImage) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
        ) else { return }
        
        let fileURL = containerURL.appendingPathComponent("lastImage.png")
        
        if let data = image.pngData() {
            do {
                try data.write(to: fileURL)
//                sharedDefaults?.set(fileURL.path, forKey: Keys.lastImagePath)
                sharedDefaults?.set("lastImage.png", forKey: Keys.lastImagePath)
            } catch {
                print("Error saving image:", error)
            }
        }
    }
    
    // MARK: - Get Image Path
    
    func getLastImagePath() -> String? {
        guard
            let filename = sharedDefaults?.string(forKey: Keys.lastImagePath),
            let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: AppConstants.appGroupID
            )
        else { return nil }
        
        return containerURL.appendingPathComponent(filename).path
    }
    
    // MARK: - Load Image
    
    func getLastImage() -> UIImage? {
        guard let path = getLastImagePath() else { return nil }
        return UIImage(contentsOfFile: path)
    }
}
