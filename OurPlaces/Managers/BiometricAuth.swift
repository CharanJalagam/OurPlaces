//
//  BiometricAuth.swift
//  OurPlaces
//
//  Face ID / Touch ID confirmation (falls back to the device passcode).
//  Used as the final gate before destructive actions like account deletion.
//

import Foundation
import LocalAuthentication

enum BiometricAuth {

    /// Prompts Face ID / Touch ID, falling back to the device passcode.
    /// - Returns: `true` if the user authenticated, `false` otherwise (cancel/fail).
    static func confirm(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Enter Passcode"

        var error: NSError?
        // `.deviceOwnerAuthentication` = biometrics with automatic passcode fallback.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
        } catch {
            return false
        }
    }
}
