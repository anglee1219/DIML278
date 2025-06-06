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
                        .tutorialHighlight(id: "profile_section", tutorialManager: tutorialManager)
                        
                        OnboardingPreviewCard(
                            icon: "person.3.fill",
                            title: "Groups & Friends",
                            description: "Connect with your closest friends"
                        )
                        .tutorialHighlight(id: "groups_section", tutorialManager: tutorialManager)
                        
                        OnboardingPreviewCard(
                            icon: "lightbulb.fill",
                            title: "Daily Prompts",
                            description: "Share moments through creative prompts"
                        )
                        .tutorialHighlight(id: "prompts_section", tutorialManager: tutorialManager)
                        
                        OnboardingPreviewCard(
                            icon: "photo.on.rectangle.angled",
                            title: "Memory Capsule",
                            description: "Your personal collection of shared moments"
                        )
                        .tutorialHighlight(id: "capsule_section", tutorialManager: tutorialManager)
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
        .tutorialOverlay(tutorialManager: tutorialManager, tutorialID: "onboarding")
        .onAppear {
            // Auto-start tutorial if user hasn't seen it
            if tutorialManager.shouldShowTutorial(for: "onboarding") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    startTutorial()
                }
            } else {
                // If tutorial was already seen, go to circles
                navigateToCircles()
            }
        }
        .onChange(of: tutorialManager.isShowingTutorial) { isShowing in
            if !isShowing && tutorialManager.steps.isEmpty {
                // Tutorial completed or skipped
                navigateToCircles()
            }
        }
    }
    
    private func startTutorial() {
        let steps = TutorialManager.createOnboardingTutorial()
        tutorialManager.startTutorial(steps: steps)
    }
    
    private func navigateToCircles() {
        // Mark tutorial as completed if not already done
        tutorialManager.markTutorialCompleted(for: "onboarding")
        
        // Set onboarding flags in Firebase
        if let userId = authManager.currentUser?.uid {
            let db = Firestore.firestore()
            db.collection("users").document(userId).updateData([
                "isFirstTimeUser": false,
                "onboardingCompleted": true,
                "lastUpdated": FieldValue.serverTimestamp()
            ])
        }
        
        // Navigate to main app with GroupListView (circles)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                // Set authenticated and navigate to groups tab
                authManager.isCompletingProfile = false
                authManager.isAuthenticated = true
                
                // Switch to groups view using window scene navigation
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController = UIHostingController(rootView: 
                        NavigationView {
                            GroupListView()
                                .environmentObject(GroupStore())
                        }
                    )
                }
            }
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