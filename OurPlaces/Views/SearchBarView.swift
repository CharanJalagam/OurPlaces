//
//  SearchBarView.swift
//  OurPlaces
//
//  Created by apple on 10/01/26.
//

import SwiftUI


struct SearchBarView: View {
    @Binding var text: String
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("Search places", text: $text)
                .textInputAutocapitalization(.none)
                .disableAutocorrection(true)

            Spacer()
            if text.isEmpty{
                
            }else{
                Button {
                    text = ""
                    UIApplication.shared.sendAction( #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil )
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.black)
                }

                
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(26)
        .shadow(radius: 4)
        .padding(.horizontal)
    }
}
