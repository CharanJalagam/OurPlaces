//
//  SupabaseNetworkLogger.swift
//  OurPlaces
//
//  A single app-wide logger for every Supabase network call.
//
//  supabase-swift routes an internal request/response interceptor through the
//  `SupabaseLogger` we plug into the client. Installing this one logger gives us
//  full coverage across Auth, Database (PostgREST) and Storage — no need to add
//  logging at individual call sites.
//
//  For each call it prints:
//    • the request  — HTTP method + URL + body
//    • the response — the same URL (correlated by requestID) + status + body
//
//  ⚠️ Request bodies can contain sensitive data (passwords, tokens), so this is
//  compiled into DEBUG builds only and never runs in a release build.
//

import Foundation
import Supabase

final class SupabaseNetworkLogger: SupabaseLogger {

    /// Correlates a response back to the URL/method of its originating request.
    private let lock = NSLock()
    private var inFlight: [String: String] = [:]   // requestID -> "METHOD URL"

    /// Bodies (especially image uploads) can be huge — cap what we print.
    private let maxBodyLength = 2000

    init() {
        // Flush prints immediately so logs appear live (not stuck in the
        // stdout buffer) in Xcode's console and any attached log stream.
        setvbuf(stdout, nil, _IONBF, 0)
    }

    func log(message: SupabaseLogMessage) {
        let system = message.system            // "Auth", "PostgREST", "Storage", …
        let text = message.message
        let id = requestID(from: message)

        if text.hasPrefix("Request:") {
            let endpoint = endpointLine(from: text)
            if let id { setEndpoint(endpoint, for: id) }
            print("""

            🌐 [\(system)] ➡️ REQUEST  \(endpoint)
            \(truncate(text))
            """)

        } else if text.hasPrefix("Response:") {
            let endpoint = id.flatMap { takeEndpoint(for: $0) } ?? "<url unknown>"
            print("""

            🌐 [\(system)] ⬅️ RESPONSE  \(endpoint)
            \(truncate(text))
            """)

        } else if message.level == .error || message.level == .warning {
            print("🌐 [\(system)] [\(message.level)] \(truncate(text))")
        }
    }

    // MARK: - Helpers

    /// Extracts "METHOD URL" from the interceptor's "Request: POST https://…" line.
    private func endpointLine(from text: String) -> String {
        let firstLine = text.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? text
        return firstLine
            .replacingOccurrences(of: "Request:", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private func requestID(from message: SupabaseLogMessage) -> String? {
        if case let .string(id)? = message.additionalContext["requestID"] {
            return id
        }
        return nil
    }

    private func setEndpoint(_ endpoint: String, for id: String) {
        lock.lock(); defer { lock.unlock() }
        inFlight[id] = endpoint
    }

    private func takeEndpoint(for id: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return inFlight.removeValue(forKey: id)
    }

    private func truncate(_ text: String) -> String {
        guard text.count > maxBodyLength else { return text }
        let end = text.index(text.startIndex, offsetBy: maxBodyLength)
        return String(text[..<end]) + "… (truncated \(text.count - maxBodyLength) chars)"
    }
}
