//
//  SectionHeaderView.swift
//  OurPlaces
//
//  Created by apple on 10/01/26.
//

import SwiftUI
struct SectionHeaderView: View {
    let title: String
    var actionTitle: String? = nil
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            
            Spacer()
            
            if let actionTitle {
                Text(actionTitle)
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
        }
    }
}
