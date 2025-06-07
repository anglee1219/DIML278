import SwiftUI
import FirebaseFirestore

struct OnboardingTutorialView: View {
    @StateObject private var tutorialManager = TutorialManager()
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var showMainApp = false
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 1, green: 0.988, blue: 0.929)
                .ignoresSafeArea()
            
            // Scrollable welcome content
            ScrollView {
                VStack(spacing: 20) {
                    // Add top padding for smaller screens
                    Spacer()
                        .frame(height: 30)
                    
                    // Logo and welcome
                    VStack(spacing: 16) {
                        Image("DIML_Logo")
                            .resizable()
                            .frame(width: 80, height: 80)
                        
                        Text("Welcome to DIML!")
                            .font(.custom("Fredoka-Bold", size: 28))
                            .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                        
                        Text("Let's show you around")
                            .font(.custom("Fredoka-Regular", size: 18))
                            .foregroundColor(.gray)
                    }
                    
                    // Tutorial sections preview
                    VStack(spacing: 16) {
                        OnboardingPreviewCard(
                            icon: "person.circle.fill",
                            title: "Profile Setup",
                            description: "Customize your profile and preferences"
                        )
                        
                        OnboardingPreviewCard(
                            icon: "person.3.fill",
                            title: "Groups & Friends",
                            description: "Connect with your closest friends"
                        )
                        
                        OnboardingPreviewCard(
                            icon: "lightbulb.fill",
                            title: "Daily Prompts",
                            description: "Share moments through creative prompts"
                        )
                        
                        OnboardingPreviewCard(
                            icon: "photo.on.rectangle.angled",
                            title: "Memory Capsule",
                            description: "Your personal collection of shared moments"
                        )
                    }
                    
                    // Start tutorial button
                    Button(action: {
                        startTutorial()
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                            Text("Get Started")
                                .font(.custom("Fredoka-Medium", size: 18))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 15)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                    }
                    
                    // Skip option - navigates to circles
                    Button(action: {
                        navigateToCircles()
                    }) {
                        Text("Skip for now")
                            .font(.custom("Fredoka-Regular", size: 16))
                            .foregroundColor(.gray)
                            .underline()
                    }
                    
                    // Add bottom padding for scroll content
                    Spacer()
                        .frame(height: 40)
                }
                .padding(.horizontal, 30)
            }
        }
        .onAppear {
            // Don't auto-start tutorial here - let user choose
            // The tutorial will start in GroupListView after navigation
            print("🎯 OnboardingTutorialView: onAppear - showing welcome screen")
        }
        .onChange(of: tutorialManager.isShowingTutorial) { isShowing in
            if !isShowing && tutorialManager.steps.isEmpty {
                // Tutorial completed or skipped
                navigateToCircles()
            }
        }
    }
    
    private func startTutorial() {
        // Don't start tutorial here - navigate to main app where card tutorial will show
        print("🎯 OnboardingTutorialView: Get Started pressed - navigating to main app")
        navigateToCircles()
    }
    
    private func navigateToCircles() {
        // DON'T mark tutorial as completed yet - let the card tutorial show first
        print("🎯 OnboardingTutorialView: Navigating to main app - tutorial will show as cards")
        
        // Update Firebase to mark onboarding screen as completed but keep tutorial flag for card tutorial
        if let userId = authManager.currentUser?.uid {
            let db = Firestore.firestore()
            db.collection("users").document(userId).updateData([
                "isFirstTimeUser": true, // Keep as true so card tutorial shows
                "onboardingCompleted": false, // Keep as false so card tutorial shows
                "welcomeScreenCompleted": true, // New flag to show we passed the welcome screen
                "lastUpdated": FieldValue.serverTimestamp()
            ]) { error in
                if let error = error {
                    print("🎯 OnboardingTutorial: Firebase update error: \(error)")
                } else {
                    print("🎯 OnboardingTutorial: Successfully updated welcome screen flags")
                }
            }
        }
        
        // Complete the authentication flow by setting the proper state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                authManager.isCompletingProfile = false
                authManager.isAuthenticated = true
            }
            
            // Notify the main app that onboarding is complete
            NotificationCenter.default.post(name: NSNotification.Name("OnboardingCompleted"), object: nil)
        }
    }
}

struct OnboardingPreviewCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(.blue)
                .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Fredoka-Medium", size: 16))
                    .foregroundColor(.black)
                
                Text(description)
                    .font(.custom("Fredoka-Regular", size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Preview
#Preview {
    OnboardingTutorialView()
}

// MARK: - Import Firebase if needed
import FirebaseFirestore 