//
//  BottomToast.swift
//  OurPlaces
//
//  Created by SAIRAM  on 02/01/26.
//

import SwiftUI


struct BottomToast: View {
    let imageName: String
    let message: String
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: imageName)
                .font(.system(size: 18))
                .foregroundColor(.accent)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .lineLimit(2)

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.white))
        .cornerRadius(14)
        .shadow(radius: 10)
        .padding(.horizontal, 16)
    }
}
