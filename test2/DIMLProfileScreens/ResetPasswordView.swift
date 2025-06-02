import SwiftUI

struct ResetPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
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
    
    var body: some View {
        VStack(spacing: 0) {
            TopNavBar(showsBack: true, onBack: {
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
                                .textFieldStyle(UnderlineTextFieldStyle())
                        }
                        .padding(.horizontal)
                        
                        // New Password
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enter New Password")
                                .font(.custom("Markazi Text", size: 18))
                                .foregroundColor(Color(red: 0.455, green: 0.506, blue: 0.267))
                            SecureField("", text: $newPassword)
                                .textFieldStyle(UnderlineTextFieldStyle())
                                .onChange(of: newPassword) { _ in validatePassword() }
                        }
                        .padding(.horizontal)
                        
                        // Confirm Password
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm New Password")
                                .font(.custom("Markazi Text", size: 18))
                                .foregroundColor(Color(red: 0.455, green: 0.506, blue: 0.267))
                            SecureField("", text: $confirmPassword)
                                .textFieldStyle(UnderlineTextFieldStyle())
                                .onChange(of: confirmPassword) { _ in validatePassword() }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Update Password Button
                    Button(action: {
                        // Add update password action
                    }) {
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
                    }
                    .disabled(!(isLongEnough && hasSpecialChar && hasUppercase && passwordsMatch))
                    
                    // Password Requirements
                    VStack(spacing: 8) {
                        RequirementText(text: "8 letters", isPassed: isLongEnough)
                        RequirementText(text: "1 Special Character", isPassed: hasSpecialChar)
                        RequirementText(text: "1 Uppercase Letter", isPassed: hasUppercase)
                        RequirementText(text: "Passwords Match", isPassed: passwordsMatch)
                    }
                    .padding(.top)
                }
                .padding(.vertical)
            }
        }
        .navigationBarHidden(true)
        .background(Color(red: 1, green: 0.988, blue: 0.929))
    }
}

// Custom text field style with underline
struct UnderlineTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        VStack {
            configuration
                .font(.custom("Markazi Text", size: 18))
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.3))
        }
    }
}

// Requirement text component
struct RequirementText: View {
    let text: String
    let isPassed: Bool
    
    var body: some View {
        Text(text)
            .font(.custom("Markazi Text", size: 16))
            .foregroundColor(isPassed ? Color(red: 0.455, green: 0.506, blue: 0.267) : Color.gray)
    }
}

#Preview {
    ResetPasswordView()
} 