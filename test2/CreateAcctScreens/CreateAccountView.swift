import SwiftUI
import FirebaseAuth

// Struct to hold all account-related fields
struct AccountData {
    var name = ""
    var email = ""
    var username = ""
    var password = ""
    var retypePassword = ""
}

struct CreateAccountView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var account = AccountData()
    @State private var navigateToNext = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @Environment(\.dismiss) var dismiss

    // Validation logic
    private var isLongEnough: Bool { account.password.count >= 8 }
    private var hasSpecialChar: Bool {
        let specialCharRegex = ".*[^A-Za-z0-9].*"
        return NSPredicate(format: "SELF MATCHES %@", specialCharRegex).evaluate(with: account.password)
    }
    private var hasUppercase: Bool {
        account.password.rangeOfCharacter(from: .uppercaseLetters) != nil
    }
    private var passwordsMatch: Bool {
        !account.password.isEmpty && account.password == account.retypePassword
    }
    
    private var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: account.email)
    }
    
    private var canProceed: Bool {
        isLongEnough && hasSpecialChar && hasUppercase && passwordsMatch && isValidEmail && !account.username.isEmpty && !account.name.isEmpty
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                ZStack {
                    Color(red: 1, green: 0.988, blue: 0.929).ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // Add top padding
                            Spacer()
                                .frame(height: 20)
                            
                            // Logo
                            VStack(spacing: 10) {
                                Image("DIML_Logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                
                                Text("DIML")
                                    .font(.custom("Caprasimo-Regular", size: 40))
                                    .foregroundColor(Color(red: 0.969, green: 0.757, blue: 0.224))
                            }
                            
                            // Text fields
                            VStack(spacing: 20) { // Reduced from 24 to 20
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Name")
                                        .font(.custom("Markazi Text", size: 18))
                                        .foregroundColor(Color(red: 0.455, green: 0.506, blue: 0.267))
                                    TextField("", text: $account.name)
                                        .textFieldStyle(UnderlineTextFieldStyle())
                                        .textContentType(.name)
                                        .autocapitalization(.words)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Email")
                                        .font(.custom("Markazi Text", size: 18))
                                        .foregroundColor(Color(red: 0.455, green: 0.506, blue: 0.267))
                                    TextField("", text: $account.email)
                                        .textFieldStyle(UnderlineTextFieldStyle())
                                        .textContentType(.emailAddress)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Username")
                                        .font(.custom("Markazi Text", size: 18))
                                        .foregroundColor(Color(red: 0.455, green: 0.506, blue: 0.267))
                                    TextField("", text: $account.username)
                                        .textFieldStyle(UnderlineTextFieldStyle())
                                        .autocapitalization(.none)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Password")
                                        .font(.custom("Markazi Text", size: 18))
                                        .foregroundColor(Color(red: 0.455, green: 0.506, blue: 0.267))
                                    SecureField("", text: $account.password)
                                        .textFieldStyle(UnderlineTextFieldStyle())
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Retype Password")
                                        .font(.custom("Markazi Text", size: 18))
                                        .foregroundColor(Color(red: 0.455, green: 0.506, blue: 0.267))
                                    SecureField("", text: $account.retypePassword)
                                        .textFieldStyle(UnderlineTextFieldStyle())
                                }
                            }
                            .padding(.horizontal, 40)
                            .padding(.top, 20)
                            
                            // Password Requirements
                            VStack(spacing: 8) {
                                Text("Password Requirements")
                                    .font(.custom("Markazi Text", size: 20))
                                    .foregroundColor(Color(red: 0.455, green: 0.506, blue: 0.267))
                                    .padding(.bottom, 4)
                                
                                RequirementText(text: "8 letters", isPassed: isLongEnough)
                                RequirementText(text: "1 Special Character", isPassed: hasSpecialChar)
                                RequirementText(text: "1 Uppercase Letter", isPassed: hasUppercase)
                                RequirementText(text: "Passwords Match", isPassed: passwordsMatch)
                                RequirementText(text: "Valid Email", isPassed: isValidEmail)
                                RequirementText(text: "Name & Username", isPassed: !account.name.isEmpty && !account.username.isEmpty)
                            }
                            .padding(.top, 16) // Reduced from 20 to 16
                            
                            // Login link
                            HStack {
                                Text("Have an account?")
                                    .font(.custom("Markazi Text", size: 18))
                                    .foregroundColor(.black.opacity(0.6))
                                
                                NavigationLink(destination: LoginScreen()) {
                                    Text("Log in")
                                        .font(.custom("Markazi Text", size: 18))
                                        .foregroundColor(Color(red: 0.733, green: 0.424, blue: 0.141))
                                }
                            }
                            .padding(.top, 16) // Reduced from 20 to 16
                            
                            // Navigation Arrows
                            HStack {
                                // Back Arrow
                                Button(action: {
                                    dismiss()
                                }) {
                                    Image(systemName: "arrow.left.circle.fill")
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                // Next Arrow
                                Button(action: {
                                    guard canProceed else {
                                        alertMessage = "Please fill in all fields correctly."
                                        showAlert = true
                                        return
                                    }
                                    
                                    isLoading = true
                                    // Create Firebase account immediately
                                    authManager.createAccount(email: account.email, password: account.password) { result in
                                        switch result {
                                        case .success(_):
                                            // Store additional info in UserDefaults
                                            UserDefaults.standard.set(account.username, forKey: "profile_username")
                                            UserDefaults.standard.set(account.name, forKey: "profile_name")
                                            UserDefaults.standard.set(account.email, forKey: "pending_email")
                                            UserDefaults.standard.set(account.password, forKey: "pending_password")
                                            
                                            // Update ProfileViewModel
                                            ProfileViewModel.shared.username = account.username
                                            ProfileViewModel.shared.name = account.name
                                    
                                            // Navigate to next screen
                                            DispatchQueue.main.async {
                                                isLoading = false
                                                navigateToNext = true
                                            }
                                            
                                        case .failure(let error):
                                            DispatchQueue.main.async {
                                                isLoading = false
                                                alertMessage = error.localizedDescription
                                                showAlert = true
                                            }
                                        }
                                    }
                                }) {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: Color.mainBlue))
                                            .frame(width: 40, height: 40)
                                    } else {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .resizable()
                                            .frame(width: 40, height: 40)
                                            .foregroundColor(canProceed ? Color.mainBlue : .gray)
                                    }
                                }
                                .disabled(!canProceed || isLoading)
                            }
                            .padding(.horizontal, 40)
                            .padding(.top, 30)
                            
                            // Add bottom padding for scroll content
                            Spacer()
                                .frame(height: 60)
                        }
                        .padding(.bottom, 20) // Extra bottom padding
                    }
                }
                .navigationDestination(isPresented: $navigateToNext) {
                    BuildProfileFlowView()
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.5), value: navigateToNext)
                }
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text("Message"),
                        message: Text(alertMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            .navigationBarHidden(true)
        } else {
            // Fallback on earlier versions
        }
    }
}

// MARK: - Preview
struct CreateAccountView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CreateAccountView()
        }
    }
} 