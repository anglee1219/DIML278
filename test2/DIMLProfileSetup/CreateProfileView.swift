import SwiftUI

struct CreateProfileView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var retypePassword: String = ""
    @State private var showNextScreen = false
    
    // Password validation states
    @State private var hasEightLetters = false
    @State private var hasSpecialCharacter = false
    @State private var hasUppercase = false
    @State private var passwordsMatch = false
    
    private func validatePassword() {
        hasEightLetters = password.count >= 8
        hasSpecialCharacter = password.range(of: #"[!@#$%^&*(),.?\":{}|<>]"#, options: .regularExpression) != nil
        hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        passwordsMatch = password == retypePassword && !password.isEmpty
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color
                Color(red: 1, green: 0.989, blue: 0.93)
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 15) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Image("DIML_Text_Logo") // Make sure to add this asset
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120)
                    }
                    .padding(.top, 60)
                    
                    // Input fields
                    VStack(spacing: 20) {
                        // Username field
                        TextField("", text: $username)
                            .placeholder(when: username.isEmpty) {
                                Text("Username")
                                    .foregroundColor(Color(red: 0.533, green: 0.533, blue: 0.533))
                            }
                            .textFieldStyle(UnderlineTextFieldStyle())
                            .padding(.horizontal, 40)
                        
                        // Password field
                        SecureField("", text: $password)
                            .placeholder(when: password.isEmpty) {
                                Text("Password")
                                    .foregroundColor(Color(red: 0.533, green: 0.533, blue: 0.533))
                            }
                            .textFieldStyle(UnderlineTextFieldStyle())
                            .padding(.horizontal, 40)
                            .onChange(of: password) { _ in validatePassword() }
                        
                        // Retype Password field
                        SecureField("", text: $retypePassword)
                            .placeholder(when: retypePassword.isEmpty) {
                                Text("Retype Password")
                                    .foregroundColor(Color(red: 0.533, green: 0.533, blue: 0.533))
                            }
                            .textFieldStyle(UnderlineTextFieldStyle())
                            .padding(.horizontal, 40)
                            .onChange(of: retypePassword) { _ in validatePassword() }
                    }
                    
                    // Password requirements
                    VStack(spacing: 15) {
                        Text("Create a Username and Password")
                            .font(.custom("Markazi Text", size: 20))
                            .foregroundColor(Color(red: 0.533, green: 0.533, blue: 0.533))
                        
                        VStack(spacing: 8) {
                            RequirementText(text: "8 letters", isMet: hasEightLetters)
                            RequirementText(text: "1 Special Character", isMet: hasSpecialCharacter)
                            RequirementText(text: "1 Uppercase Letter", isMet: hasUppercase)
                            RequirementText(text: "Passwords Match", isMet: passwordsMatch)
                        }
                    }
                    
                    Spacer()
                    
                    // Next button
                    NavigationLink(destination: Text("Next Screen"), isActive: $showNextScreen) {
                        HStack {
                            Spacer()
                            Image(systemName: "arrow.right")
                                .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                                .font(.system(size: 24))
                                .opacity(allRequirementsMet ? 1 : 0.5)
                        }
                        .padding(.trailing, 40)
                    }
                    .disabled(!allRequirementsMet)
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private var allRequirementsMet: Bool {
        hasEightLetters && hasSpecialCharacter && hasUppercase && passwordsMatch
    }
}

struct PlaceholderStyle: ViewModifier {
    var showPlaceHolder: Bool
    var placeholder: AnyView
    
    func body(content: Content) -> some View {
        ZStack(alignment: .leading) {
            if showPlaceHolder {
                placeholder
            }
            content
        }
    }
}

// Custom text field style
struct UnderlineTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        VStack {
            configuration
                .font(.system(size: 16))
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(red: 0.533, green: 0.533, blue: 0.533))
        }
    }
}

// Requirement text component
struct RequirementText: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        Text(text)
            .font(.custom("Markazi Text", size: 16))
            .foregroundColor(Color(red: 0.533, green: 0.533, blue: 0.533))
            .opacity(isMet ? 1 : 0.5)
    }
}

// Extension for placeholder
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
            modifier(PlaceholderStyle(showPlaceHolder: shouldShow,
                                    placeholder: AnyView(placeholder())))
    }
}

struct CreateProfileView_Previews: PreviewProvider {
    static var previews: some View {
        CreateProfileView()
    }
} 