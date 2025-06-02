import SwiftUI

struct BioEntryView: View {
    @StateObject private var viewModel = ProfileViewModel.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var goToNextScreen = false
    @State private var goToPreviousScreen = false
    @State private var showLocationSearch = false
    
    var body: some View {
        ZStack {
            Color(red: 1, green: 0.988, blue: 0.929)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Image("DIML_Logo")
                    .resizable()
                    .frame(width: 60, height: 60)
                
                VStack(spacing: 24) {
                    Text("Tell us about yourself")
                        .font(.custom("Markazi Text", size: 32))
                        .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                    
                    VStack(spacing: 24) {
                        // Location Field
                        LocationSearchField(text: $viewModel.location)
                        
                        // School Field
                        VStack(alignment: .leading, spacing: 4) {
                            Text("school:")
                                .font(.system(size: 16))
                                .foregroundColor(.black)
                            
                            TextField("", text: $viewModel.school)
                                .font(.system(size: 16))
                                .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0))
                                .tint(Color(red: 0.722, green: 0.369, blue: 0))
                                .textFieldStyle(.plain)
                                .padding(.vertical, 8)
                            
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0).opacity(0.4))
                        }
                        .padding(.horizontal)
                        
                        // Interests Field
                        VStack(alignment: .leading, spacing: 4) {
                            Text("interests:")
                                .font(.system(size: 16))
                                .foregroundColor(.black)
                            
                            TextField("", text: $viewModel.interests)
                                .font(.system(size: 16))
                                .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0))
                                .tint(Color(red: 0.722, green: 0.369, blue: 0))
                                .textFieldStyle(.plain)
                                .padding(.vertical, 8)
                            
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0).opacity(0.4))
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // Create Profile Button
                Button(action: {
                    // Set authentication state to true
                    authManager.isAuthenticated = true
                    
                    // Switch to main tab view
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.rootViewController = UIHostingController(rootView: 
                            NavigationView {
                                MainTabView(currentTab: .home)
                            }
                        )
                    }
                }) {
                    Text("Create Profile")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.mainBlue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
    }
}

struct BioEntryView_Previews: PreviewProvider {
    static var previews: some View {
        BioEntryView()
    }
}


