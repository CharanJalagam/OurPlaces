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

    var body: some View {
        Group {
            if showSplash {
                SplashView()
            } else {
                if authState.isLoggedIn {
                    OurPlacesTabView()
                } else {
                    LoginView {
                        authState.signIn()
                    }
                }
            }
        }
        .environmentObject(authState)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                withAnimation {
                    showSplash = false
                }
            }
        }
    }
}
