//
//  SupabaseManager.swift
//  OurPlaces
//
//  Created by SAIRAM  on 26/12/25.
//


import Foundation
import Supabase

final class SupabaseManager {

    // MARK: - Singleton
    static let shared = SupabaseManager()

    // MARK: - Supabase Credentials
    private let supabaseURL: URL
    private let supabaseAnonKey: String

    // MARK: - Supabase Client
    let client: SupabaseClient

    // MARK: - Private Init
    private init() {

        
        let urlString = "https://vkcytomtcibaaruzpdyr.supabase.co"
        let anonKey = "sb_publishable_zMuZDLt6Ho7NUmfDjUuehg_Cixf06h-"

        guard let url = URL(string: urlString) else {
            fatalError("❌ Invalid Supabase URL")
        }

        self.supabaseURL = url
        self.supabaseAnonKey = anonKey

        #if DEBUG
        // Log every Supabase request/response app-wide. DEBUG only — request
        // bodies can contain passwords/tokens, so this never ships in release.
        let options = SupabaseClientOptions(
            global: .init(logger: SupabaseNetworkLogger())
        )
        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseAnonKey,
            options: options
        )
        #else
        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseAnonKey
        )
        #endif
    }
}
