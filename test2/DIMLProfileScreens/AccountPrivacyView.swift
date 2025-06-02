import SwiftUI

struct AccountPrivacyView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var viewModel = ProfileViewModel.shared
    @State private var email: String = "Rebecca" // This should be loaded from user data
    @State private var showResetPassword = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                Button("Back") {
                    dismiss()
                }
                .foregroundColor(Color(red: 0.733, green: 0.424, blue: 0.141))
                .font(.custom("Markazi Text", size: 18))
                
                Spacer()
                
                Button("Save Changes") {
                    // Save changes and dismiss
                    dismiss()
                }
                .foregroundColor(Color(red: 0.733, green: 0.424, blue: 0.141))
                .font(.custom("Markazi Text", size: 18))
            }
            .padding()
            .background(Color(red: 1, green: 0.988, blue: 0.929))
            
            ScrollView {
                VStack(spacing: 24) {
                    // Settings Icon
                    Image(systemName: "gearshape")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                    
                    // Title
                    Text("Account and Privacy")
                        .font(.custom("Markazi Text", size: 32))
                        .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                    
                    // Form Fields
                    VStack(alignment: .leading, spacing: 20) {
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email:")
                                .font(.custom("Markazi Text", size: 18))
                                .foregroundColor(.gray)
                            
                            VStack(spacing: 4) {
                                TextField("Enter your email", text: $email)
                                    .font(.custom("Markazi Text", size: 18))
                                    .foregroundColor(.black)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                
                                Divider()
                                    .frame(height: 1)
                                    .background(Color.gray.opacity(0.3))
                            }
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password:")
                                .font(.custom("Markazi Text", size: 18))
                                .foregroundColor(.gray)
                            
                            Button(action: {
                                showResetPassword = true
                            }) {
                                HStack {
                                    Text("Reset Password")
                                        .font(.custom("Markazi Text", size: 18))
                                        .foregroundColor(.white)
                                    
                                    Image(systemName: "arrow.right")
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.455, green: 0.506, blue: 0.267))
                                .cornerRadius(20)
                            }
                        }
                        
                        // Privacy Toggles
                        VStack(alignment: .leading, spacing: 16) {
                            // Location Toggle
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Show Location")
                                    .font(.custom("Markazi Text", size: 18))
                                    .foregroundColor(.gray)
                                
                                Toggle("", isOn: $viewModel.showLocation)
                                    .toggleStyle(CustomToggleStyle())
                            }
                            
                            // School Toggle
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Show School")
                                    .font(.custom("Markazi Text", size: 18))
                                    .foregroundColor(.gray)
                                
                                Toggle("", isOn: $viewModel.showSchool)
                                    .toggleStyle(CustomToggleStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .background(Color(red: 1, green: 0.988, blue: 0.929).ignoresSafeArea())
        .fullScreenCover(isPresented: $showResetPassword) {
            ResetPasswordView()
        }
    }
}

struct CustomToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            RoundedRectangle(cornerRadius: 16)
                .fill(configuration.isOn ? Color(red: 0.455, green: 0.506, blue: 0.267) : Color.gray.opacity(0.3))
                .frame(width: 50, height: 31)
                .overlay(
                    Circle()
                        .fill(.white)
                        .padding(2)
                        .offset(x: configuration.isOn ? 10 : -10)
                )
                .onTapGesture {
                    withAnimation(.spring()) {
                        configuration.isOn.toggle()
                    }
                }
        }
    }
}

#Preview {
    AccountPrivacyView()
} 