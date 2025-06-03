import SwiftUI

struct BuildProfileFlowView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var showText = false
    @State private var showNextScreen = false

    var body: some View {
        ZStack {
            Color(red: 1, green: 0.988, blue: 0.929)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                Image("DIML_Logo")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .opacity(showText ? 1 : 0)
                    .animation(.easeIn(duration: 0.5), value: showText)
                
                if showText {
                    VStack(spacing: 10) {
                        Text("Let's Build")
                            .font(.custom("Fredoka-Medium", size: 32))
                        Text("Your Profile")
                            .font(.custom("Fredoka-Medium", size: 32))
                        
                        Text("We'll help you create your profile\nand get you started.")
                            .font(.custom("Markazi Text", size: 24))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.top, 10)
                    }
                    .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                Spacer()
                
                // Navigation Link to ProfilePicSetup
                NavigationLink(destination: ProfilePicSetup(), isActive: $showNextScreen) {
                    EmptyView()
                }
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Ensure we're in profile completion mode
            authManager.isCompletingProfile = true
            
            // Fade in the logo and text
            withAnimation(.easeIn(duration: 1)) {
                showText = true
            }
            
            // After 2.5 seconds, transition to the profile photo upload screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                showNextScreen = true
            }
        }
    }
}

#Preview {
    NavigationView {
        BuildProfileFlowView()
    }
}
