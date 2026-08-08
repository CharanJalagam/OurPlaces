//
//  AppPopup.swift
//  OurPlaces
//
//  Created by SAIRAM  on 02/01/26.
//

import SwiftUI
import SwiftUI


struct AppPopup: View {
    let title: String
    let message: String
    let buttonTitle: String
    let imageName: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: imageName)
                    .font(.system(size: 36))
                    .foregroundColor(.accent)

                Text(title)
                    .font(.system(size: 18, weight: .semibold))

                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)

            
                Button {
                    onDismiss()
                } label: {
                    Text(buttonTitle)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.accent)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    
                }

            }
            .padding(24)
            .background(Color(.background))
            .cornerRadius(16)
            .shadow(radius: 20)
            .padding(.horizontal, 40)
        }
    }
}

#Preview {
    AppPopup(title: "dbkajdb", message: "adbadj", buttonTitle: "ad", imageName: "bookmark.fill") {
        
    }
}
