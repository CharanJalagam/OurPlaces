//
//  Validators.swift
//  OurPlaces
//
//  Shared input validation used by the auth screens.
//

import Foundation

enum Validators {

    /// Minimum length required when setting a new password.
    static let minPasswordLength = 6

    /// Basic email format check (something@something.tld).
    static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }

    /// Whether a password meets the minimum length rule.
    static func isValidPassword(_ password: String) -> Bool {
        password.count >= minPasswordLength
    }

    /// Whether a string is a plausible email OTP code: all digits, 6–10 long.
    /// (Supabase's OTP length is configurable in the dashboard — this project
    /// uses 8 — so we accept the whole valid range rather than hard-coding one.)
    static func isValidOTPCode(_ code: String) -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 6 && trimmed.count <= 10
            && trimmed.allSatisfy { $0.isNumber }
    }

    /// Normalizes an email for sending to the backend (trimmed + lowercased).
    static func normalizeEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
