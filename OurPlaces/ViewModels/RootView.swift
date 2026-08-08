//
//  RootView.swift
//  OurPlaces
//
//  Created by SAIRAM  on 26/12/25.
//

import SwiftUI


struct RootView: View {
    
    @State private var showSplash = true
    @StateObject private var authState = AppAuthState()
    let authVM = SupabaseAuthVM()
    
    var body: some View {
        Group {
            if showSplash {
                SplashView()
            } else {
                if authState.isLoggedIn {
                    OurPlacesTabView()
                } else {
                    LoginView {
                        authState.isLoggedIn = true
                    }
                }
            }
        }
        .environmentObject(authState)
        .task {
            authState.isLoggedIn = await authVM.isUserLoggedIn()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                withAnimation {
                    showSplash = false
                }
            }
        }
    }
}
