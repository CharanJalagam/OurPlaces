//
//  ContentView.swift
//  OurPlaces
//
//  Created by SAIRAM  on 26/12/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    
    @State private var isLoading = false
    @State private var errorMessage = ""
    var authVM = SupabaseAuthVM()
    let onLogout: () -> Void
    var body: some View {
        NavigationStack {
            VStack{
                
                Button {
                    authVM.logout(onSuccess: {
                        onLogout()
                    }, onError: {errorMessage = $0})
                } label: {
                    Text("Sign Out")
                        .foregroundStyle(.appSecondary)
                        .padding()
                        .background(.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

  
}



#Preview {
    ContentView(onLogout: {})
}
