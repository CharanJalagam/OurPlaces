//
//  RootView.swift
//  OurPlaces
//
//  Created by SAIRAM  on 26/12/25.
//

import SwiftUICore


struct RootView: View {
    @State private var showSplash = true
    @State private var isLoggedIn: Bool = false
    var authVM = SupabaseAuthVM()
    var body: some View {
        Group {
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else {
                if isLoggedIn{
//                    ContentView(onLogout: {
//                        isLoggedIn = false
//                    })
                    OurPlacesTabView()
                }else{
                    LoginView(onLoginSuccess: {
                        isLoggedIn = true
                    })
                }
            }
        }
        .task {
                    isLoggedIn = await authVM.isUserLoggedIn()
                }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                withAnimation(.easeOut(duration: 0.25)) {
                    showSplash = false
                }
            }
        }
    }
}
