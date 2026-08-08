//
//  SplashView.swift
//  OurPlaces
//
//  Created by SAIRAM  on 26/12/25.
//


import SwiftUI

struct SplashView: View {
    @State private var animate = false
    @State private var moveup = true
    @State private var expand = false
    @State private var showSolidBackground = false


    var body: some View {
        ZStack {
            Color(showSolidBackground ? .appRed : .background)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ZStack(alignment: .center){
                    Image(.iconBG)
                        .resizable()
                        .scaledToFit()
                        .opacity(showSolidBackground ? 0 : 1)
                        .frame(width: 96, height: 96)
                    
                    Image(.iconPointer)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 50)
                        .scaleEffect(expand ? 55 : 1)
                        .offset(y: expand ? -500 : (moveup ? 0 : -10))
                        .opacity(showSolidBackground ? 0 : 1)
//                        .blur(radius: expand ? 8 : 0)
                        .opacity(expand ? 1.5 : 1)

                       

                }

                Text("OurPlaces")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(Color(.textPrimary))
                    .opacity(showSolidBackground ? 0 : 1)
                    .opacity(animate ? 1 : 0)
                    .offset(y: animate ? 0 : 4)

                Text("Moments, marked together")
                    .font(.system(size: 15))
                    .foregroundColor(Color(.textSecondary))
                    .opacity(showSolidBackground ? 0 : 1)
                    .opacity(animate ? 1 : 0)
                
            }
            .padding(.top, -40) 
        }
        .onAppear {

            // MARK: Pointer lift
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.5)) {
                    moveup = false
                }
            }

            // MARK: Settle + text appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.easeOut(duration: 0.45)) {
                    moveup = true
                    animate = true
                }
            }

            // MARK: Brand pause (VERY important)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                // intentional pause — no animation
            }

            // MARK: Takeover zoom (Netflix style)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    expand = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.25) {
                withAnimation(.easeIn(duration: 0.35)) {
                    showSolidBackground = true
                }
            }

        }

    }
}

#Preview {
    SplashView()
}
