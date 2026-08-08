//
//  LoginView.swift
//  OurPlaces
//
//  Created by SAIRAM  on 26/12/25.
//


import SwiftUI
import SwiftUI
import WidgetKit

struct LoginView: View {
    
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isValid = false
    let onLoginSuccess: () -> Void
    @State private var isLoading = false
    @State private var showPopup = false
    @State private var showToast = false
    @State private var isSignUpSuccess: Bool? = false

    var authVM = SupabaseAuthVM()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.background)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    
                    Spacer()
                    
                    // Logo
                    Image(.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Title
                    Text("OurPlaces")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(Color(.textPrimary))
                    
                    // Subtitle
                    Text("Sign in to mark your moments together")
                        .font(.system(size: 15))
                        .foregroundColor(Color(.textSecondary))
                    
                    VStack(spacing: 16) {
                        
                        // Email Field
                        inputField(
                            placeholder: "Email",
                            text: $email,
                            systemImage: "envelope"
                        ).onChange(of: email) { oldValue, newValue in
                            validateFields()
                        }
                        
                        // Password Field
                        inputField(
                            placeholder: "Password",
                            text: $password,
                            systemImage: "lock",
                            isSecure: true
                        ).onChange(of: password) { oldValue, newValue in
                            validateFields()
                        }
                        HStack {
                            Spacer()
                            Text("Forgot password?")
                                .font(.system(size: 14))
                                .foregroundColor(Color(.accent))
                        }
                    }
                    .padding(.top, 10)
                    
                    // Sign In Button
                    Button {
                        if isValid{
                            isLoading = true
                            authVM.login(email: email, password: password, onLoading: { isLoading = $0 }, onSuccess: {
                                onLoginSuccess()
                                WidgetDataManager.shared.setLoginState(true)
                                WidgetCenter.shared.reloadAllTimelines()
                            }, onError: {
                                errorMessage = $0
                                showPopup = true
                            })
                        }
                    } label: {
                        Text("Sign In")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(isValid ? .appRed : .appPrimary)
                            .cornerRadius(14)
                    }
                    .padding(.top, 10)
                    
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
                    .padding(.vertical, 8)
                    
                    // Google Sign In
                    socialButton(
                        title: "Sign in with Google",
                        icon: "g.circle"
                    )
                    
                    //                 Apple Sign In
                    socialButton(
                        title: "Sign in with Apple",
                        icon: "applelogo"
                    )
                    
                    Spacer()
                    
                    // Sign Up
                    NavigationLink {
                        SignupView(isSignUpSuccess: $isSignUpSuccess)
                    } label: {
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundColor(Color(.textSecondary))

                            Text("Sign Up")
                                .foregroundColor(Color(.accent))
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: 14))
                    }

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
                if showToast {
                       VStack {
                           Spacer()
                          
                           BottomToast(
                               imageName: "checkmark.circle.fill",
                               message: "Sign Up Successful"
                           ) {
                               showToast = false
                           }
                           .transition(.move(edge: .bottom).combined(with: .opacity))
                           .padding(.bottom, 24)
                       }
                   }
            }
            .animation(.easeInOut, value: showToast)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
        .onChange(of: isSignUpSuccess, { oldValue, newValue in
            if newValue == true {
                showToast = true

                isSignUpSuccess = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showToast = false
                }
            }
        })
    }
    private func validateFields() {
        isValid = !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                  !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

}
private func inputField(
    placeholder: String,
    text: Binding<String>,
    systemImage: String,
    isSecure: Bool = false
) -> some View {
    
    HStack(spacing: 12) {
        Image(systemName: systemImage)
            .foregroundColor(Color(.accent))
        
        if isSecure {
            SecureField(placeholder, text: text)
        } else {
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
            
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
    
    Button {
        // OAuth action later
    } label: {
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
    LoginView(onLoginSuccess: {})
}
