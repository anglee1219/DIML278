import SwiftUI

struct CreateAccountView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var retypePassword = ""

    // Validation logic
    private var isLongEnough: Bool { password.count >= 8 }
    private var hasSpecialChar: Bool {
        let specialCharRegex = ".*[^A-Za-z0-9].*"
        return NSPredicate(format: "SELF MATCHES %@", specialCharRegex).evaluate(with: password)
    }
    private var hasUppercase: Bool {
        password.rangeOfCharacter(from: .uppercaseLetters) != nil
    }
    private var passwordsMatch: Bool {
        !password.isEmpty && password == retypePassword
    }

    var body: some View {
        ZStack {
            Color(red: 1, green: 0.988, blue: 0.929).ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                // Logo
                VStack(spacing: 10) {
                    Image("DIML_Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)

                    Text("DIML")
                        .font(.custom("Fredoka-Bold", size: 28))
                        .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                }

                // Text fields
                VStack(spacing: 20) {
                    CustomTextField(placeholder: "Username", text: $username)
                    CustomTextField(placeholder: "Password", text: $password, isSecure: true)
                    CustomTextField(placeholder: "Retype Password", text: $retypePassword, isSecure: true)
                }
                .padding(.top, 20)

                // Instructions
                VStack(spacing: 10) {
                    Text("Create a Username and Password")
                        .font(.custom("Markazi Text", size: 18))
                        .foregroundColor(.black)

                    VStack(spacing: 5) {
                        ChecklistItem(text: "8 letters", passed: isLongEnough)
                        ChecklistItem(text: "1 Special Character", passed: hasSpecialChar)
                        ChecklistItem(text: "1 Uppercase Letter", passed: hasUppercase)
                        ChecklistItem(text: "Passwords Match", passed: passwordsMatch)
                    }
                }
                .padding(.top, 10)

                Spacer()

                // Forward arrow
                HStack {
                    Spacer()
                    Button(action: {
                        // Navigate to next screen
                    }) {
                        Image(systemName: "arrow.right")
                            .font(.title2)
                            .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                    }
                }
                .padding(.horizontal)
            }
            .padding(.horizontal, 30)
        }
    }
}

// MARK: - Reusable TextField with underline
struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            if isSecure {
                SecureField(placeholder, text: $text)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
            } else {
                TextField(placeholder, text: $text)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
            }

            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.4))
        }
    }
}

// MARK: - Checklist Item View
struct ChecklistItem: View {
    var text: String
    var passed: Bool

    var body: some View {
        Text(text)
            .font(.custom("Markazi Text", size: 16))
            .foregroundColor(passed ? .green : Color(red: 0.85, green: 0.6, blue: 0.5))
    }
}

// MARK: - Preview
struct CreateAccountView_Previews: PreviewProvider {
    static var previews: some View {
        CreateAccountView()
    }
}
//
//  CreateAccountView.swift
//  test2
//
//  Created by Angela Lee on 5/31/25.
//

