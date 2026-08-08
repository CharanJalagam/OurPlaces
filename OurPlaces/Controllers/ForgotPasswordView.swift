//
//  ForgotPasswordView.swift
//  OurPlaces
//
//  OTP-based password reset: email → code → new password → auto-login.
//

import SwiftUI

struct ForgotPasswordView: View {

    enum Step {
        case email
        case code
        case newPassword
    }

    /// Called once the password is successfully reset. At this point the user
    /// already holds a valid session, so the caller logs them into the app.
    var onResetComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .email
    @State private var email: String
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showPopup = false

    private let authVM = SupabaseAuthVM()

    init(initialEmail: String, onResetComplete: @escaping () -> Void) {
        self._email = State(initialValue: initialEmail)
        self.onResetComplete = onResetComplete
    }

    var body: some View {
        ZStack {
            Color(.background)
                .ignoresSafeArea()

            VStack(spacing: 24) {

                Spacer()

                Image(.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(title)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(Color(.textPrimary))
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundColor(Color(.textSecondary))
                    .multilineTextAlignment(.center)

                stepContent

                primaryButton

                Spacer()
            }
            .padding(.horizontal, 24)
            .disabled(isLoading)

            // Liquid Glass back button (steps back, or dismisses on step 1)
            Button {
                goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(.textPrimary))
                    .frame(width: 44, height: 44)
            }
            .glassEffect(.regular.interactive(), in: Circle())
            .padding(.leading, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if isLoading {
                Color.black.opacity(0.25).ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.accent)
                    .scaleEffect(1.2)
            }

            if showPopup {
                AppPopup(
                    title: "OurPlaces",
                    message: errorMessage,
                    buttonTitle: "OK",
                    imageName: "exclamationmark.circle.fill"
                ) {
                    showPopup = false
                }
            }
        }
        .animation(.easeInOut, value: step)
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .email:
            VStack(spacing: 8) {
                authField(placeholder: "Email", text: $email, systemImage: "envelope", isEmail: true)
                if !email.isEmpty && !Validators.isValidEmail(email) {
                    hint("Enter a valid email address")
                }
            }

        case .code:
            VStack(spacing: 8) {
                authField(placeholder: "Verification code", text: $code, systemImage: "number", isCode: true)
                if !code.isEmpty && !Validators.isValidOTPCode(code) {
                    hint("Enter the code from your email")
                }
                Button("Resend code") {
                    sendCode()
                }
                .font(.system(size: 14))
                .foregroundColor(Color(.accent))
                .padding(.top, 4)
            }

        case .newPassword:
            VStack(spacing: 8) {
                authField(placeholder: "New password", text: $newPassword, systemImage: "lock", isSecure: true)
                if !newPassword.isEmpty && !Validators.isValidPassword(newPassword) {
                    hint("At least \(Validators.minPasswordLength) characters")
                }
                authField(placeholder: "Confirm password", text: $confirmPassword, systemImage: "lock", isSecure: true)
                if !confirmPassword.isEmpty && confirmPassword != newPassword {
                    hint("Passwords don't match")
                }
            }
        }
    }

    private var primaryButton: some View {
        Button {
            handlePrimaryAction()
        } label: {
            Text(primaryButtonTitle)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(isStepValid ? Color(.appRed) : Color(.appPrimary))
                .cornerRadius(14)
        }
        .disabled(!isStepValid)
    }

    private func hint(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(Color(.error))
            Spacer()
        }
    }

    // MARK: - Copy per step

    private var title: String {
        switch step {
        case .email: return "Forgot Password"
        case .code: return "Enter Code"
        case .newPassword: return "New Password"
        }
    }

    private var subtitle: String {
        switch step {
        case .email: return "Enter your email to receive a reset code"
        case .code: return "We sent a verification code to \(email)"
        case .newPassword: return "Set a new password for your account"
        }
    }

    private var primaryButtonTitle: String {
        switch step {
        case .email: return "Send Code"
        case .code: return "Verify"
        case .newPassword: return "Update Password"
        }
    }

    private var isStepValid: Bool {
        switch step {
        case .email:
            return Validators.isValidEmail(email)
        case .code:
            return Validators.isValidOTPCode(code)
        case .newPassword:
            return Validators.isValidPassword(newPassword) && newPassword == confirmPassword
        }
    }

    // MARK: - Actions

    private func handlePrimaryAction() {
        guard isStepValid else { return }
        switch step {
        case .email: sendCode()
        case .code: verifyCode()
        case .newPassword: updatePassword()
        }
    }

    private func goBack() {
        switch step {
        case .email: dismiss()
        case .code: step = .email
        case .newPassword: step = .code
        }
    }

    private func sendCode() {
        print("🔐 [ForgotPW] Step=email → requesting code for \(email)")
        run {
            try await authVM.sendPasswordResetCode(email: email)
            await MainActor.run {
                print("🔐 [ForgotPW] Moving to code step")
                step = .code
            }
        }
    }

    private func verifyCode() {
        print("🔐 [ForgotPW] Step=code → verifying \(code)")
        run {
            try await authVM.verifyPasswordResetCode(email: email, code: code)
            await MainActor.run {
                print("🔐 [ForgotPW] Moving to newPassword step")
                step = .newPassword
            }
        }
    }

    private func updatePassword() {
        print("🔐 [ForgotPW] Step=newPassword → updating password")
        run {
            try await authVM.updatePassword(newPassword: newPassword)
            await MainActor.run {
                print("🔐 [ForgotPW] Reset complete → auto-login")
                onResetComplete()
            }
        }
    }

    /// Runs an async auth call with shared loading + error handling.
    private func run(_ work: @escaping () async throws -> Void) {
        isLoading = true
        Task {
            do {
                try await work()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showPopup = true
                }
            }
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - Styled input field (matches LoginView)

private extension ForgotPasswordView {
    func authField(
        placeholder: String,
        text: Binding<String>,
        systemImage: String,
        isSecure: Bool = false,
        isEmail: Bool = false,
        isCode: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundColor(Color(.accent))

            if isSecure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
                    .textInputAutocapitalization(.never)
                    .keyboardType(isCode ? .numberPad : (isEmail ? .emailAddress : .default))
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
}

#Preview {
    ForgotPasswordView(initialEmail: "") {}
}
