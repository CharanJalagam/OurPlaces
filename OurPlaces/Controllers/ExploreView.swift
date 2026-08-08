//
//  ExploreView.swift
//  OurPlaces
//
//  Created by SAIRAM  on 03/01/26.
//


import SwiftUI

struct ExploreView: View {
    
    @State private var isSearching = false
    @State private var activeDot = 0
    @State private var navigateToDiscovery = false
    @State private var places: [Place] = []
    var body: some View {
        NavigationStack{
            ZStack {
                Image(.exploreBg)
                    .resizable()
                    .ignoresSafeArea()
                
                Image(.exploreCenter)
                    .scaledToFit()
                    .padding(.top, 40)
                
                SpinButtonView(isSpinning: $isSearching) {
                    startSearching()
                }
                .padding(.top, 40)
                
                VStack {
                    Text("Feeling")
                        .font(.system(size: 40))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text("Adventurous?")
                        .font(.system(size: 40))
                        .fontWeight(.bold)
                        .foregroundStyle(.orangeCustom)
                    
                    Text("Let us pick a place for you.")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(.systemGray4))
                        .padding(.top, 12)
                    
                    Spacer()
                    
                    // 🔄 Loading dots
                    HStack(spacing: 10) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(activeDot == index ? .orangeCustom : Color.gray.opacity(0.4))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .opacity(isSearching ? 1 : 0)
                    .animation(.easeInOut, value: activeDot)
                    
                    Text("SEARCHING CURATED GEMS...")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(.systemGray2))
                        .padding(.top, 12)
                        .opacity(isSearching ? 1 : 0)
                        .padding(.bottom, 40)
                    
                }
                .padding(.top, 40)
            }
            .navigationDestination(isPresented: $navigateToDiscovery) {
                if let placeF = places.randomElement(){
                    ExploreDiscoveryView(place: placeF)
                }
            }
        }
        .task {
            places = CoreDataLayer.shared.fetchPlaces()
        }
    }
    
    // MARK: - Logic
    private func startSearching() {
        guard !isSearching else { return }
        
        isSearching = true
        activeDot = 0
        
        Task {
            for _ in 0..<12 {        // 12 × 0.4s = ~5s
                try? await Task.sleep(nanoseconds: 400_000_000)
                if !isSearching { return }
                activeDot = (activeDot + 1) % 3
            }
            
            isSearching = false
            navigateToDiscovery = true
        }
    }

}

#Preview{
    ExploreView()
}

struct SpinButtonView: View {
    @Binding var isSpinning: Bool
    var action: () -> Void
    
//    @State private var pulse = false
    
    var body: some View {
        Button {
            guard !isSpinning else { return }
            
//            pulse = true
            action()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation {
//                    pulse = false
                }
            }
        } label: {
            VStack(spacing: 10) {
                
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
//                    .opacity(isSpinning ? 1 : 0.8)
//                    .scaleEffect(isSpinning ? 1.25 : 1)
//                    .animation(
//                        isSpinning
//                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
//                        : .default,   // 👈 animation removed when false
//                        value: isSpinning
//                    )

                if !isSpinning {
                    Text("TAP TO SPIN")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(1.2)
                }
            }
            .frame(width: 180, height: 180)
            .background(
                Circle()
                    .fill(.orangeCustom)
                    .shadow(
                        color: .orangeCustom.opacity(isSpinning ? 0.9 : 0.5),
                        radius: isSpinning ? 35 : 20
                    )
                    .scaleEffect(isSpinning ? 1.05 : 1)
                    .animation(
                        isSpinning
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                        value: isSpinning
                    )

            )
        }
        .buttonStyle(.plain)
    }
}


