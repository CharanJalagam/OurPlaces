//
//  SupabaseAuthVM.swift
//  OurPlaces
//
//  Created by SAIRAM  on 27/12/25.
//


import Foundation
import Supabase

final class SupabaseAuthVM {

    private let supabase = SupabaseManager.shared.client

    // MARK: - SIGN UP
    func signUp(
        email: String,
        password: String,
        userName: String,
        onLoading: @escaping (Bool) -> Void,
        onSuccess: @escaping () -> Void,
        onError: @escaping (String) -> Void
    ) {

        DispatchQueue.main.async {
            onLoading(true)
        }

        Task {
            do {
                let response = try await supabase.auth.signUp(
                    email: email,
                    password: password
                )
                print(response)
                 let userID = response.user.id
                    try await supabase
                        .from("users")
                        .update(["full_name": userName])
                        .eq("id", value: userID)
                        .execute()
                

                await MainActor.run {
                    onLoading(false)
                    onSuccess()
                }

            } catch {
                await MainActor.run {
                    onLoading(false)
                    onError(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - LOGIN
    func login(
        email: String,
        password: String,
        onLoading: @escaping (Bool) -> Void,
        onSuccess: @escaping () -> Void,
        onError: @escaping (String) -> Void
    ) {

        DispatchQueue.main.async {
            onLoading(true)
        }

        Task {
            do {
                try await supabase.auth.signIn(
                    email: email,
                    password: password
                )

                await MainActor.run {
                    onLoading(false)
                    onSuccess()
                }

            } catch {
                await MainActor.run {
                    onLoading(false)
                    onError(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - LOGOUT
    func logout(
        onSuccess: @escaping () -> Void,
        onError: @escaping (String) -> Void
    ) {

        Task {
            do {
                try await supabase.auth.signOut()

                await MainActor.run {
                    onSuccess()
                }

            } catch {
                await MainActor.run {
                    onError(error.localizedDescription)
                }
            }
        }
    }
    func isUserLoggedIn() async -> Bool {
        do {
            let session = try await supabase.auth.session
            return session != nil
        } catch {
            return false
        }
    }

}
