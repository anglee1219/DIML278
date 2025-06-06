import SwiftUI
import Combine
import FirebaseFirestore

// MARK: - Tutorial Step Model (Simplified)
struct TutorialStep: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let image: String // SF Symbol
    let backgroundColor: Color
    let accentColor: Color
}

// MARK: - Tutorial Manager (Simplified)
class TutorialManager: ObservableObject {
    @Published var isShowingTutorial = false
    @Published var currentStepIndex = 0
    @Published var steps: [TutorialStep] = []
    
    private let userDefaults = UserDefaults.standard
    
    // Check if user has seen tutorial
    func shouldShowTutorial(for tutorialID: String) -> Bool {
        let tutorialCompleted = userDefaults.bool(forKey: "tutorial_completed_\(tutorialID)")
        print("🎯 Tutorial: shouldShowTutorial(\(tutorialID)) = \(!tutorialCompleted)")
        return !tutorialCompleted
    }
    
    // Mark tutorial as completed
    func markTutorialCompleted(for tutorialID: String) {
        userDefaults.set(true, forKey: "tutorial_completed_\(tutorialID)")
        userDefaults.synchronize()
        print("🎯 Tutorial: Marked \(tutorialID) as completed")
    }
    
    // Reset tutorial (for testing)
    func resetTutorial(for tutorialID: String) {
        userDefaults.removeObject(forKey: "tutorial_completed_\(tutorialID)")
        userDefaults.synchronize()
        print("🎯 Tutorial: Reset \(tutorialID) completion status")
    }
    
    // Start tutorial
    func startTutorial(steps: [TutorialStep]) {
        self.steps = steps
        self.currentStepIndex = 0
        self.isShowingTutorial = true
        print("🎯 Tutorial: Started tutorial with \(steps.count) steps")
    }
    
    // Navigate tutorial
    func nextStep() {
        if currentStepIndex < steps.count - 1 {
            currentStepIndex += 1
        } else {
            endTutorial()
        }
    }
    
    func previousStep() {
        if currentStepIndex > 0 {
            currentStepIndex -= 1
        }
    }
    
    func endTutorial() {
        isShowingTutorial = false
        currentStepIndex = 0
        steps = []
        print("🎯 Tutorial: Ended tutorial")
    }
    
    var currentStep: TutorialStep? {
        guard currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }
    
    var isLastStep: Bool {
        currentStepIndex == steps.count - 1
    }
    
    var isFirstStep: Bool {
        currentStepIndex == 0
    }
}

// MARK: - Tutorial Overlay View (Simplified)
struct TutorialOverlay: View {
    @ObservedObject var tutorialManager: TutorialManager
    let tutorialID: String
    
    var body: some View {
        if tutorialManager.isShowingTutorial,
           let currentStep = tutorialManager.currentStep {
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Allow dismissing by tapping background
                        tutorialManager.markTutorialCompleted(for: tutorialID)
                        tutorialManager.endTutorial()
                        completeOnboardingFlow()
                    }
                
                // Tutorial slide card
                TutorialSlide(
                    step: currentStep,
                    tutorialManager: tutorialManager,
                    tutorialID: tutorialID
                )
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .animation(.easeInOut(duration: 0.3), value: tutorialManager.currentStepIndex)
        }
    }
    
    private func completeOnboardingFlow() {
        print("🎯 Tutorial: completeOnboardingFlow() called")
        
        // Set onboarding flags in Firebase if user exists
        if let userId = AuthenticationManager.shared.currentUser?.uid {
            print("🎯 Tutorial: Updating Firebase for user: \(userId)")
            let db = Firestore.firestore()
            db.collection("users").document(userId).updateData([
                "isFirstTimeUser": false,
                "onboardingCompleted": true,
                "lastUpdated": FieldValue.serverTimestamp()
            ]) { error in
                if let error = error {
                    print("🎯 Tutorial: Firebase update error: \(error.localizedDescription)")
                } else {
                    print("🎯 Tutorial: Firebase update successful")
                }
            }
        }
        
        // Complete authentication flow
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.5)) {
                AuthenticationManager.shared.isCompletingProfile = false
                AuthenticationManager.shared.isAuthenticated = true
            }
        }
    }
}

// MARK: - Tutorial Slide
struct TutorialSlide: View {
    let step: TutorialStep
    @ObservedObject var tutorialManager: TutorialManager
    let tutorialID: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Top section with background color
            VStack(spacing: 24) {
                // Skip button (top right)
                HStack {
                    Spacer()
                    Button(action: {
                        print("🎯 Tutorial: Skip button pressed")
                        tutorialManager.markTutorialCompleted(for: tutorialID)
                        tutorialManager.endTutorial()
                        completeOnboardingFlow()
                    }) {
                        Text("Skip")
                            .font(.custom("Fredoka-Medium", size: 16))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 24)
                
                // Icon with animated background
                ZStack {
                    Circle()
                        .fill(step.accentColor.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: tutorialManager.currentStepIndex)
                    
                    Circle()
                        .fill(step.accentColor.opacity(0.1))
                        .frame(width: 150, height: 150)
                        .scaleEffect(1.2)
                        .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: tutorialManager.currentStepIndex)
                    
                    Image(systemName: step.image)
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
                
                // Title
                Text(step.title)
                    .font(.custom("Fredoka-Bold", size: 28))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                // Description
                Text(step.description)
                    .font(.custom("Fredoka-Regular", size: 18))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(.horizontal, 16)
                
                Spacer()
            }
            .frame(height: 400)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        step.backgroundColor,
                        step.backgroundColor.opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            // Bottom white section with navigation
            VStack(spacing: 20) {
                // Progress dots
                HStack(spacing: 12) {
                    ForEach(0..<tutorialManager.steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == tutorialManager.currentStepIndex ? step.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                            .scaleEffect(index == tutorialManager.currentStepIndex ? 1.3 : 1.0)
                            .animation(.spring(response: 0.3), value: tutorialManager.currentStepIndex)
                    }
                }
                .padding(.top, 24)
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if !tutorialManager.isFirstStep {
                        Button(action: {
                            tutorialManager.previousStep()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Back")
                                    .font(.custom("Fredoka-Medium", size: 16))
                            }
                            .foregroundColor(step.accentColor)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(step.accentColor, lineWidth: 2)
                            )
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if tutorialManager.isLastStep {
                            print("🎯 Tutorial: Get Started button pressed")
                            tutorialManager.markTutorialCompleted(for: tutorialID)
                            tutorialManager.endTutorial()
                            completeOnboardingFlow()
                        } else {
                            tutorialManager.nextStep()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Text(tutorialManager.isLastStep ? "Get Started!" : "Next")
                                .font(.custom("Fredoka-Medium", size: 16))
                            
                            if !tutorialManager.isLastStep {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    step.accentColor,
                                    step.accentColor.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                        .shadow(color: step.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .background(Color.white)
        }
        .frame(width: min(UIScreen.main.bounds.width - 48, 350))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    private func completeOnboardingFlow() {
        print("🎯 Tutorial: completeOnboardingFlow() called")
        
        if let userId = AuthenticationManager.shared.currentUser?.uid {
            let db = Firestore.firestore()
            db.collection("users").document(userId).updateData([
                "isFirstTimeUser": false,
                "onboardingCompleted": true,
                "lastUpdated": FieldValue.serverTimestamp()
            ]) { error in
                if let error = error {
                    print("🎯 Tutorial: Firebase update error: \(error.localizedDescription)")
                } else {
                    print("🎯 Tutorial: Firebase update successful")
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.5)) {
                AuthenticationManager.shared.isCompletingProfile = false
                AuthenticationManager.shared.isAuthenticated = true
            }
        }
    }
}

// MARK: - View Extensions (Simplified)
extension View {
    func tutorialOverlay(
        tutorialManager: TutorialManager,
        tutorialID: String
    ) -> some View {
        ZStack {
            self
            TutorialOverlay(tutorialManager: tutorialManager, tutorialID: tutorialID)
        }
    }
}

// MARK: - Tutorial Content
extension TutorialManager {
    
    static func createOnboardingTutorial() -> [TutorialStep] {
        return [
            TutorialStep(
                title: "Welcome to DIML! ✨",
                description: "Day In My Life - Share authentic moments with your closest friends through daily prompts and photos.",
                image: "heart.circle.fill",
                backgroundColor: Color.blue,
                accentColor: Color(red: 1.0, green: 0.815, blue: 0.0) // Yellow
            ),
            
            TutorialStep(
                title: "Create Your Circles 👥",
                description: "Build intimate friend groups where you'll share your daily life.",
                image: "person.3.fill",
                backgroundColor: Color(red: 1.0, green: 0.815, blue: 0.0), // Yellow
                accentColor: Color.blue
            ),
            
            TutorialStep(
                title: "Daily Prompts 📝",
                description: "Every day, your circles receive fun prompts to respond to.",
                image: "lightbulb.circle.fill",
                backgroundColor: Color.blue,
                accentColor: Color(red: 1.0, green: 0.815, blue: 0.0) // Yellow
            ),
            
            TutorialStep(
                title: "The Influencer Role ⭐",
                description: "Each day, one person is chosen as the 'influencer' and can take photos for prompts. Everyone gets a turn!",
                image: "star.circle.fill",
                backgroundColor: Color(red: 1.0, green: 0.815, blue: 0.0), // Yellow
                accentColor: Color.blue
            ),
            
            TutorialStep(
                title: "Your Memory Capsule 📸",
                description: "All your shared moments are saved in your personal memory capsule. Relive your favorite days anytime!",
                image: "photo.stack.fill",
                backgroundColor: Color.blue,
                accentColor: Color(red: 1.0, green: 0.815, blue: 0.0) // Yellow
            ),
            
            TutorialStep(
                title: "Let's Get Started! 🚀",
                description: "You're all set! Create your first circle or ask friends to invite you to theirs. Time to share your daily moments!",
                image: "checkmark.circle.fill",
                backgroundColor: Color(red: 1.0, green: 0.815, blue: 0.0), // Yellow
                accentColor: Color.blue
            )
        ]
    }
} 
