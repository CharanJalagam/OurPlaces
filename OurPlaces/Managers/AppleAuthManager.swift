//
//  AppleAuthManager.swift
//  OurPlaces
//
//  Native Sign in with Apple → Supabase session.
//
//  Apple returns a signed ID token (and, only on the FIRST authorization, the
//  user's name). We generate a nonce, send its SHA256 to Apple, and pass the raw
//  nonce to Supabase's `signInWithIdToken` so the token can be verified.
//  (Keep "Skip nonce checks" OFF for the Apple provider — unlike Google, we
//  supply a real nonce here.)
//

import Foundation
import AuthenticationServices
import CryptoKit
import UIKit
import Supabase

final class AppleAuthManager: NSObject {

    static let shared = AppleAuthManager()

    enum AppleAuthError: LocalizedError {
        case missingIDToken
        var errorDescription: String? {
            "Apple didn't return a valid token. Please try again."
        }
    }

    private var currentNonce: String?
    private var continuation: CheckedContinuation<Bool, Error>?

    /// Presents Sign in with Apple and exchanges the result for a Supabase session.
    /// - Returns: `true` on success, `false` if the user cancelled.
    @MainActor
    func signIn() async throws -> Bool {
        let nonce = Self.randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - Nonce helpers

    private static func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - Delegate

extension AppleAuthManager: ASAuthorizationControllerDelegate {

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8),
            let nonce = currentNonce
        else {
            continuation?.resume(throwing: AppleAuthError.missingIDToken)
            continuation = nil
            return
        }

        // Apple only sends the name on the very first authorization.
        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")

        let cont = continuation
        continuation = nil

        Task {
            do {
                try await SupabaseManager.shared.client.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
                )
                await SupabaseAuthVM().backfillProfileIfNeeded(
                    fullName: fullName.isEmpty ? nil : fullName,
                    avatarURL: nil
                )
                cont?.resume(returning: true)
            } catch {
                cont?.resume(throwing: error)
            }
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        // User cancelled — treat as a no-op, not an error.
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            continuation?.resume(returning: false)
        } else {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }
}

// MARK: - Presentation

extension AppleAuthManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return scene?.keyWindow ?? ASPresentationAnchor()
    }
}
