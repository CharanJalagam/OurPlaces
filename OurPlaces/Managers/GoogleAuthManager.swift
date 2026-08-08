//
//  GoogleAuthManager.swift
//  OurPlaces
//
//  Native Google Sign-In → Supabase session.
//
//  Flow: GoogleSignIn shows the native account picker and returns an ID token,
//  which we exchange for a Supabase session via `signInWithIdToken`. Because the
//  iOS SDK's token has no nonce we can supply, "Skip nonce checks" is enabled on
//  the Supabase Google provider.
//

import Foundation
import UIKit
import GoogleSignIn
import Supabase

@MainActor
enum GoogleAuthManager {

    enum GoogleAuthError: LocalizedError {
        case noPresenter
        case missingIDToken

        var errorDescription: String? {
            switch self {
            case .noPresenter:   return "Couldn't open Google Sign-In. Please try again."
            case .missingIDToken: return "Google didn't return a valid token. Please try again."
            }
        }
    }

    /// Runs native Google sign-in and exchanges the result for a Supabase session.
    /// - Returns: `true` on success, `false` if the user cancelled the Google sheet.
    @discardableResult
    static func signIn() async throws -> Bool {
        guard let presenter = rootViewController() else {
            throw GoogleAuthError.noPresenter
        }

        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        } catch {
            // User dismissed the Google sheet — treat as a no-op, not an error.
            if let gidError = error as? GIDSignInError, gidError.code == .canceled {
                return false
            }
            throw error
        }

        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleAuthError.missingIDToken
        }
        let accessToken = result.user.accessToken.tokenString

        try await SupabaseManager.shared.client.auth.signInWithIdToken(
            credentials: .init(provider: .google, idToken: idToken, accessToken: accessToken)
        )

        // Fill the profile name/avatar from the Google account (first sign-in only).
        let profile = result.user.profile
        await SupabaseAuthVM().backfillProfileIfNeeded(
            fullName: profile?.name,
            avatarURL: profile?.imageURL(withDimension: 200)?.absoluteString
        )
        return true
    }

    /// The top-most view controller to present the Google sheet from.
    private static func rootViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let window = scene?.keyWindow ?? scene?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
