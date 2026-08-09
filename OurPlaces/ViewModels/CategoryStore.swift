//
//  CategoryStore.swift
//  OurPlaces
//
//  Shared place categories: built-in defaults + the user's custom categories.
//  Custom ones are persisted in Supabase (per-user) with an offline-first local
//  cache, and shown everywhere categories are used (Add Place form + Map chips).
//

import Foundation

final class CategoryStore: ObservableObject {
    static let shared = CategoryStore()

    static let defaults = ["Cafe", "Food", "Historic", "Nature", "Shopping", "Religious", "Entertainment"]
    private let key = "customCategories"
    private let vm = SupabaseAuthVM()

    /// Cached custom categories (shown instantly, synced with Supabase).
    @Published private(set) var custom: [String]

    private init() {
        custom = UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    /// Built-in categories followed by the user's custom ones.
    var all: [String] { CategoryStore.defaults + custom }

    func isCustom(_ name: String) -> Bool {
        !CategoryStore.defaults.contains(name)
    }

    /// Fetch from Supabase and reconcile with the local cache. Any category that
    /// exists only locally (e.g. created offline, or before this synced) is
    /// pushed up to the server so nothing is lost.
    @MainActor
    func refresh() async {
        let server = await vm.fetchCategories()
        let serverLower = Set(server.map { $0.lowercased() })
        let localOnly = custom.filter { !serverLower.contains($0.lowercased()) }

        for name in localOnly {
            try? await vm.addCategory(name: name)
        }

        var merged = server
        for name in localOnly where !merged.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            merged.append(name)
        }
        custom = merged
        persist()
    }

    /// Optimistically add locally, then persist to Supabase.
    func add(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !all.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        custom.append(trimmed)
        persist()
        Task { try? await vm.addCategory(name: trimmed) }
    }

    /// Remove locally + from Supabase. (Callers are responsible for the
    /// "block if in use" check before calling this.)
    func remove(_ name: String) {
        custom.removeAll { $0 == name }
        persist()
        Task { try? await vm.deleteCategory(name: name) }
    }

    private func persist() {
        UserDefaults.standard.set(custom, forKey: key)
    }

    /// SF Symbol for a category (custom categories get a generic pin).
    static func icon(for name: String) -> String {
        switch name.lowercased() {
        case "cafe":          return "cup.and.saucer.fill"
        case "food":          return "fork.knife"
        case "historic":      return "building.columns.fill"
        case "nature":        return "leaf.fill"
        case "shopping":      return "bag.fill"
        case "religious":     return "sparkles"
        case "entertainment": return "theatermasks.fill"
        default:              return "mappin.circle.fill"
        }
    }
}
