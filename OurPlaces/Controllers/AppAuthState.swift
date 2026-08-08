//
//  AppAuthState.swift
//  OurPlaces
//
//  Created by apple on 17/01/26.
//

import Foundation
import WidgetKit


/// Offline-first source of truth for whether the user is signed in.
///
/// The flag is persisted locally (in the shared App Group store, so the widget
/// stays in sync) and restored **synchronously** on launch. This means the app
/// can route to the correct screen immediately, without waiting on any network
/// or Supabase session API call.
final class AppAuthState: ObservableObject {

    @Published var isLoggedIn: Bool

    init() {
        // Restore the last known auth state synchronously — no network / API.
        self.isLoggedIn = WidgetDataManager.shared.getLoginState()
    }

    /// Mark the user as signed in and persist it locally.
    func signIn() {
        persist(true)
    }

    /// Mark the user as signed out and persist it locally.
    func signOut() {
        persist(false)
    }

    private func persist(_ value: Bool) {
        isLoggedIn = value
        WidgetDataManager.shared.setLoginState(value)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
