import SwiftUI

struct LoginScreen: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var store = EntryStore()
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isPressed = false
    @State private var showCreateAccount = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false

    var body: some View {
        ZStack {
            // Background color
            Color(red: 1, green: 0.988, blue: 0.929)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 40) {
                    Spacer(minLength: 100)

                    // Logo
                    VStack(spacing: 8) {
                        Text("DIML")
                            .font(.custom("Caprasimo-Regular", size: 70))
                            .foregroundColor(Color(red: 0.969, green: 0.757, blue: 0.224))

                        Text("DAY IN MY LIFE")
                            .font(.custom("Fredoka-Regular", size: 20))
                            .kerning(2)
                            .foregroundColor(Color(red: 0.353, green: 0.447, blue: 0.875))
                    }

                    // Input Fields
                    VStack(spacing: 20) {
                        TextField("Email", text: $email)
                            .textFieldStyle(UnderlineTextFieldStyle())
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .padding(.horizontal, 40)
                            .foregroundColor(.gray)

                        SecureField("Password", text: $password)
                            .textFieldStyle(UnderlineTextFieldStyle())
                            .textContentType(.password)
                            .padding(.horizontal, 40)
                            .foregroundColor(.gray)
                    }

                    // Login Button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isPressed = true
                            isLoading = true
                        }
                        
                        authManager.signIn(email: email, password: password) { result in
                            isLoading = false
                            isPressed = false
                            
                            switch result {
                            case .success(_):
                                // Authentication successful, AuthenticationManager will handle the state change
                                break
                            case .failure(let error):
                                alertMessage = error.localizedDescription
                                showAlert = true
                            }
                        }
                    }) {
                        ZStack {
                            Text("Login")
                                .font(.custom("Fredoka-Medium", size: 20))
                                .foregroundColor(.white)
                                .frame(width: 200, height: 45)
                                .background(Color(red: 0.353, green: 0.447, blue: 0.875))
                                .cornerRadius(10)
                                .scaleEffect(isPressed ? 0.95 : 1.0)
                                .opacity(isPressed ? 0.9 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                            
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                        }
                    }
                    .disabled(isLoading)
                    .padding(.bottom, 10)

                    // Forgot Password
                    Button(action: {
                        if !email.isEmpty {
                            authManager.resetPassword(email: email) { error in
                                if let error = error {
                                    alertMessage = error.localizedDescription
                                } else {
                                    alertMessage = "Password reset email sent. Please check your inbox."
                                }
                                showAlert = true
                            }
                        } else {
                            alertMessage = "Please enter your email address first."
                            showAlert = true
                        }
                    }) {
                        Text("Forgot Password?")
                            .font(.custom("Markazi Text", size: 20))
                            .foregroundColor(Color.mainYellow)
                            .opacity(0.9)
                            .shadow(radius: 0.3)
                    }

                    // Sign Up Section
                    HStack(spacing: 5) {
                        Text("Don't have an account?")
                            .font(.custom("Markazi Text", size: 20))
                            .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                            .opacity(0.6)

                        NavigationLink(destination: CreateAccountView()) {
                            Text("Sign Up")
                                .font(.custom("Markazi Text", size: 20))
                                .foregroundColor(Color.mainYellow)
                                .opacity(0.9)
                                .shadow(radius: 0.3)
                        }
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal)
            }
        }
        .navigationBarHidden(true)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Message"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct LoginScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LoginScreen()
        }
    }
}
