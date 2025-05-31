import SwiftUI

struct LoginScreen: View {
    
    //rebecca edits
    @State private var isLoggedIn = false
    @StateObject private var store = EntryStore()
    @State private var emailOrPhone: String = ""
    @State private var password: String = ""
    
    
    var body: some View {
        NavigationView {
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
                                .font(.caprasimo_DIML())
                                .fontWeight(.bold)
                                .foregroundColor(Color.mainYellow)
                            
                            Text("DAY IN MY LIFE")
                                .font(.custom("Markazi Text", size: 20))
                                .kerning(2)
                                .foregroundColor(Color.mainBlue)
                        }
                        Spacer()
                        // Input Fields
                        VStack(spacing: 30) {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Phone Number, username, or email", text: $emailOrPhone)
                                    .font(.custom("Markazi Text", size: 20))
                                    .padding(.bottom, 5)
                                    .foregroundColor(.black)
                                    .opacity(0.6)
                                
                                Divider()
                                    .background(Color.black.opacity(0.1))
                            }
                            .padding(.horizontal)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                SecureField("Password", text: $password)
                                    .font(.custom("Markazi Text", size: 20))
                                    .padding(.bottom, 5)
                                    .foregroundColor(.black)
                                    .opacity(0.6)
                                
                                Divider()
                                    .background(Color.black.opacity(0.1))
                            }
                            .padding(.horizontal)
                        }
                        
                        NavigationLink(destination:  GroupListView(), isActive: $isLoggedIn) {
                            EmptyView()
                        }
                        Button(action: {
                            
                            isLoggedIn = true
                        }) {
                            Text("Login")
                                .font(.custom("Markazi Text", size: 20))
                                .foregroundColor(.white)
                                .frame(width: 200, height: 45)
                                .background(Color.mainBlue)
                                .cornerRadius(10)
                            }
                            .padding(.bottom, 10)
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
                            
                            NavigationLink(destination: SignUpScreen()) {
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
                .navigationBarHidden(true)
            }
        }
    }

struct LoginScreen_Previews: PreviewProvider {
    static var previews: some View {
        LoginScreen()
    }
}

