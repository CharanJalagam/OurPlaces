//
//  LoginView 2.swift
//  OurPlaces
//
//  Created by SAIRAM  on 27/12/25.
//


import SwiftUI


struct SignupView: View {
    
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isValid = false
    @State private var showPopup = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showToast = false
    
    @Binding var isSignUpSuccess: Bool?
    var authVM = SupabaseAuthVM()
    
    var body: some View {
        ZStack {
            Color(.background)
                .ignoresSafeArea()
//            ScrollView(showsIndicators: false){
//                HStack{
//                    Button {
//                        dismiss()
//                    } label: {
//                        Image(systemName: "chevron.left")
//                            .foregroundStyle(.accent)
//                            .font(.system(size: 20, weight: .semibold))
//                    }
//
//                    
//                    Spacer()
//                }
//                .padding(.horizontal, 24)
                VStack(spacing: 18) {
                    
                    Spacer()
                    
                    // Logo
                    Image(.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                    
                    // Title
                    Text("OurPlaces")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(Color(.textPrimary))
                    
                    // Subtitle
                    Text("Create an account to get started")
                        .font(.system(size: 15))
                        .foregroundColor(Color(.textSecondary))
                    
                    VStack(spacing: 16) {
                        
                        inputField(
                            placeholder: "Name",
                            text: $name,
                            icon: "person"
                        )
                        .onChange(of: name) { oldValue, newValue in
                            validateFields()
                        }
                        
                        inputField(
                            placeholder: "Email",
                            text: $email,
                            icon: "envelope"
                        ) .onChange(of: email) { oldValue, newValue in
                            validateFields()
                        }
                        
                        
                        inputField(
                            placeholder: "Password",
                            text: $password,
                            icon: "lock",
                            isSecure: true
                        ) .onChange(of: password) { oldValue, newValue in
                            validateFields()
                        }
                        
                        
                        inputField(
                            placeholder: "Confirm Password",
                            text: $confirmPassword,
                            icon: "lock",
                            isSecure: true
                        ) .onChange(of: confirmPassword) { oldValue, newValue in
                            validateFields()
                        }
                        
                    }
                    .padding(.top, 8)
                    
                    // Sign Up Button
                    Button(action: {
                        if isValid{
                            isLoading = true
                            authVM.signUp(
                                email: email,
                                password: password,
                                userName: name,
                                onLoading: { isLoading = $0 },
                                onSuccess: {
                                    showToast = true
                                    isSignUpSuccess = true
                                        dismiss()
                                },
                                onError: { errorMessage = $0
                                    showPopup = true
                                }
                            )
                        }
                    }) {
                        Text("Sign Up")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(isValid ? .appRed : .appPrimary)
                            .cornerRadius(14)
                    }
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color(.divider))
                            .frame(height: 1)
                        
                        Text("Or continue with")
                            .font(.system(size: 13))
                            .foregroundColor(Color(.textSecondary))
                        
                        Rectangle()
                            .fill(Color(.divider))
                            .frame(height: 1)
                    }
                    .padding(.vertical, 6)
                    
                    socialButton(
                        title: "Sign up with Google",
                        icon: "g.circle"
                    )
                    
                    socialButton(
                        title: "Sign up with Apple",
                        icon: "applelogo"
                    )
                    
//                    Spacer()
                    
                    // Switch to Login
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .foregroundColor(Color(.textSecondary))
                            
                            Text("Sign In")
                                .foregroundColor(Color(.accent))
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: 14))
                    }
                    .padding(.top, 10)

                   
                }
                .padding(.horizontal, 24)
                .disabled(isLoading)
                if isLoading {
                       Color.black.opacity(0.25)
                           .ignoresSafeArea()

                       ProgressView()
                           .progressViewStyle(.circular)
                           .tint(.accent)
                           .scaleEffect(1.2)
                   }
            if showPopup {
                    AppPopup(
                        title: "OurPlaces",
                        message: errorMessage,
                        buttonTitle: "OK", imageName: "exclamationmark.circle.fill"
                    ) {
                        showPopup = false
                    }
                }
//            if showToast {
//                   VStack {
//                       Spacer()
//
//                       BottomToast(
//                           imageName: "checkmark.circle.fill",
//                           message: "Sign Up Successful"
//                       ) {
//                           showToast = false
//                       }
//                       .transition(.move(edge: .bottom).combined(with: .opacity))
//                       .padding(.bottom, 24)
//                   }
//               }
//            }
        }
//        .animation(.easeInOut, value: showToast)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)

    }
    private func validateFields() {
        isValid =
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            password == confirmPassword
    }

}

private func inputField(
    placeholder: String,
    text: Binding<String>,
    icon: String,
    isSecure: Bool = false
) -> some View {

    HStack(spacing: 12) {
        Image(systemName: icon)
            .foregroundColor(Color(.accent))

        if isSecure {
            SecureField(placeholder, text: text)
        } else {
            TextField(placeholder, text: text)
                .keyboardType(placeholder == "Email" ? .emailAddress : .default)
                .textInputAutocapitalization(.never)
        }
    }
    .padding()
    .frame(height: 54)
    .background(Color.white)
    .cornerRadius(14)
    .overlay(
        RoundedRectangle(cornerRadius: 14)
            .stroke(Color(.divider), lineWidth: 1)
    )
}

private func socialButton(
    title: String,
    icon: String
) -> some View {

    Button(action: {}) {
        HStack(spacing: 10) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(Color(.textPrimary))
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.divider), lineWidth: 1)
        )
    }
}


#Preview {
//    SignupView(isSignUpSuccess: <#T##Binding<Bool?>#>)
}
