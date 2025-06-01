import SwiftUI

struct LoginScreen: View {
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @StateObject private var store = EntryStore()
    @State private var emailOrPhone: String = ""
    @State private var password: String = ""
    @State private var isPressed = false

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
                    VStack(spacing: 30) {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Phone Number, username, or email", text: $emailOrPhone)
                                .font(.custom("Markazi Text", size: 20))
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding(.bottom, 5)
                                .foregroundColor(.black)
                                .opacity(0.6)

                            Divider()
                                .background(Color.black.opacity(0.1))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            SecureField("Password", text: $password)
                                .font(.custom("Markazi Text", size: 20))
                                .padding(.bottom, 5)
                                .foregroundColor(.black)
                                .opacity(0.6)

                            Divider()
                                .background(Color.black.opacity(0.1))
                        }
                    }
                    .padding(.horizontal)

                    // Navigation link triggered by login
                    NavigationLink(destination: GroupListView(), isActive: $isLoggedIn) {
                        EmptyView()
                    }

                    // Login Button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isPressed = true
                        }
                        
                        // Delay the login action slightly for animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isLoggedIn = true
                            isPressed = false
                        }
                    }) {
                        Text("Login")
                            .font(.custom("Fredoka-Medium", size: 20))
                            .foregroundColor(.white)
                            .frame(width: 200, height: 45)
                            .background(Color(red: 0.353, green: 0.447, blue: 0.875))
                            .cornerRadius(10)
                            .scaleEffect(isPressed ? 0.95 : 1.0)
                            .opacity(isPressed ? 0.9 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                    }
                    .padding(.bottom, 10)

                    // Forgot Password
                    Button(action: {
                        // Implement password recovery
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
    }
}

struct LoginScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LoginScreen()
        }
    }
}
