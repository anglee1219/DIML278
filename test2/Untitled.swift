import SwiftUI

struct LoginScreen: View {
    var body: some View {
        ZStack {
            // Background color
            Color(red: 1, green: 0.988, blue: 0.929)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 40) {
                    Spacer(minLength: 100)

                    // Text-based Logo
                    VStack(spacing: 8) {
                        Text("DIML")
                            .font(.custom("Markazi Text", size: 48))
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 0.373, green: 0.42, blue: 0.22))

                        Text("DAY IN MY LIFE")
                            .font(.custom("Markazi Text", size: 20))
                            .kerning(2)
                            .foregroundColor(Color(red: 0.373, green: 0.22, blue: 0.1))
                    }

                    // Input Fields
                    VStack(spacing: 35) {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Phone Number, username, or email", text: .constant(""))
                                .font(.custom("Markazi Text", size: 20))
                                .padding(.bottom, 5)
                                .foregroundColor(.black)
                                .opacity(0.6)

                            Divider()
                                .background(Color.black.opacity(0.1))
                        }
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 8) {
                            SecureField("Password", text: .constant(""))
                                .font(.custom("Markazi Text", size: 20))
                                .padding(.bottom, 5)
                                .foregroundColor(.black)
                                .opacity(0.6)

                            Divider()
                                .background(Color.black.opacity(0.1))
                        }
                        .padding(.horizontal)
                    }

                    // Login Button
                    Button(action: {
                        // Add login logic here
                    }) {
                        Text("Login")
                            .font(.custom("Markazi Text", size: 20))
                            .foregroundColor(Color(red: 1, green: 0.988, blue: 0.929))
                            .opacity(0.9)
                            .frame(width: 200, height: 40)
                            .background(Color(red: 0.373, green: 0.42, blue: 0.22))
                            .cornerRadius(10)
                    }

                    // Forgot Password
                    Button(action: {
                        // Add forgot password action
                    }) {
                        Text("Forgot Password?")
                            .font(.custom("Markazi Text", size: 20))
                            .foregroundColor(Color(red: 0.733, green: 0.424, blue: 0.141))
                            .opacity(0.8)
                    }

                    // Sign Up Section
                    HStack(spacing: 5) {
                        Text("Don’t have an account?")
                            .font(.custom("Markazi Text", size: 20))
                            .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                            .opacity(0.6)

                        Button(action: {
                            // Add sign-up navigation
                        }) {
                            Text("Sign Up")
                                .font(.custom("Markazi Text", size: 20))
                                .foregroundColor(Color(red: 0.733, green: 0.424, blue: 0.141))
                                .opacity(0.8)
                        }
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal)
            }
        }
    }
}

// Preview (use this if you're on Xcode <15)
struct LoginScreen_Previews: PreviewProvider {
    static var previews: some View {
        CreateAcct()
    }
}
