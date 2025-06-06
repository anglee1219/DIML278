import SwiftUI
import FirebaseAuth

#if os(iOS)
import UIKit
#endif

// MARK: - Custom Text Field Style
struct ResetPasswordTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        VStack {
            configuration
                .font(.custom("Markazi Text", size: 18))
                .foregroundColor(.black) // Fixed dark color for all modes
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.3))
        }
    }
}

// MARK: - Custom Requirement Text Component
struct ResetPasswordRequirementText: View {
    let text: String
    let isPassed: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isPassed ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isPassed ? Color(red: 0.455, green: 0.506, blue: 0.267) : .gray)
            Text(text)
                .font(.custom("Markazi Text", size: 16))
                .foregroundColor(isPassed ? Color(red: 0.455, green: 0.506, blue: 0.267) : .gray)
        }
    }
}

// Custom navigation bar for this view
private struct ResetPasswordNavBar: View {
    let onBack: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .foregroundColor(Color(red: 0.733, green: 0.424, blue: 0.141))
                    .font(.title3)
            }
            .padding(.leading)
            
            Spacer()
            
            Text("Reset Password")
                .font(.custom("Markazi Text", size: 24))
                .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
            
            Spacer()
            
            Color.clear
                .frame(width: 24, height: 24)
                .padding(.trailing)
        }
        .padding(.vertical)
        .background(Color(red: 1, green: 0.988, blue: 0.929))
    }
}

@MainActor
struct ResetPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    // Validation states
    @State private var isLongEnough = false
    @State private var hasSpecialChar = false
    @State private var hasUppercase = false
    @State private var passwordsMatch = false
    
    private func validatePassword() {
        isLongEnough = newPassword.count >= 8
        hasSpecialChar = newPassword.range(of: ".*[^A-Za-z0-9].*", options: .regularExpression) != nil
        hasUppercase = newPassword.range(of: "[A-Z]", options: .regularExpression) != nil
        passwordsMatch = !newPassword.isEmpty && newPassword == confirmPassword
    }
    
    private func updatePassword() {
        isLoading = true
        authManager.updatePassword(currentPassword: currentPassword, newPassword: newPassword) { error in
            isLoading = false
            if let error = error {
                alertMessage = error.localizedDescription
                showAlert = true
            } else {
                alertMessage = "Password updated successfully!"
                showAlert = true
                // Clear the fields
                currentPassword = ""
                newPassword = ""
                confirmPassword = ""
                // Dismiss the view after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ResetPasswordNavBar(onBack: {
                dismiss()
            })
            
            ScrollView {
                VStack(spacing: 30) {                    
                    Text("Reset Password")
                        .font(.custom("Markazi Text", size: 32))
                        .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                        .padding(.top, 20)
                    
                    // Password Fields
                    VStack(spacing: 24) {
                        // Current Password
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enter Current Password")
                                .font(.custom("Markazi Text", size: 18))
                                .foregroundColor(Color(red: 0.455, green: 0.506, blue: 0.267))
                            SecureField("", text: $currentPassword)
                                .textFieldStyle(ResetPasswordTextFieldStyle())
                        }
                        .padding(.horizontal)
                        
                        // New Password
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enter New Password")
                                .font(.custom("Markazi Text", size: 18))
                                .foregroundColor(Color(red: 0.455, green: 0.506, blue: 0.267))
                            SecureField("", text: $newPassword)
                                .textFieldStyle(ResetPasswordTextFieldStyle())
                                .onChange(of: newPassword) { _ in validatePassword() }
                        }
                        .padding(.horizontal)
                        
                        // Confirm Password
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm New Password")
                                .font(.custom("Markazi Text", size: 18))
                                .foregroundColor(Color(red: 0.455, green: 0.506, blue: 0.267))
                            SecureField("", text: $confirmPassword)
                                .textFieldStyle(ResetPasswordTextFieldStyle())
                                .onChange(of: confirmPassword) { _ in validatePassword() }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Update Password Button
                    Button(action: {
                        updatePassword()
                    }) {
                        ZStack {
                            Text("Update Password")
                                .font(.custom("Markazi Text", size: 20))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .fill(Color(red: 0.455, green: 0.506, blue: 0.267))
                                )
                                .padding(.horizontal)
                            
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                        }
                    }
                    .disabled(!(isLongEnough && hasSpecialChar && hasUppercase && passwordsMatch) || isLoading)
                    
                    // Password Requirements
                    VStack(spacing: 8) {
                        ResetPasswordRequirementText(text: "8 letters", isPassed: isLongEnough)
                        ResetPasswordRequirementText(text: "1 Special Character", isPassed: hasSpecialChar)
                        ResetPasswordRequirementText(text: "1 Uppercase Letter", isPassed: hasUppercase)
                        ResetPasswordRequirementText(text: "Passwords Match", isPassed: passwordsMatch)
                    }
                    .padding(.top)
                }
                .padding(.vertical)
            }
        }
        .background(Color(red: 1, green: 0.988, blue: 0.929))
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
        .alert(isPresented: $showAlert) {
            Alert(title: Text(""), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
}

#Preview {
    ResetPasswordView()
} 