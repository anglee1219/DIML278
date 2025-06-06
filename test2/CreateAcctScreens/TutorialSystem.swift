import SwiftUI
import Combine

// MARK: - Tutorial Step Model
struct TutorialStep: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let targetView: String? // ID of the view to highlight
    let position: TutorialPosition
    let action: TutorialAction?
    let image: String? // Optional image/icon
    let highlightArea: CGRect? // Area to highlight
    
    enum TutorialPosition {
        case top, bottom, center, custom(CGPoint)
    }
    
    enum TutorialAction {
        case next, done, custom(String, () -> Void)
    }
}

// MARK: - Tutorial Manager
class TutorialManager: ObservableObject {
    @Published var isShowingTutorial = false
    @Published var currentStepIndex = 0
    @Published var steps: [TutorialStep] = []
    
    private let userDefaults = UserDefaults.standard
    
    // Check if user has seen tutorial
    func shouldShowTutorial(for tutorialID: String) -> Bool {
        // Check if tutorial was already completed
        let tutorialCompleted = userDefaults.bool(forKey: "tutorial_completed_\(tutorialID)")
        
        // For onboarding tutorial, also check if user is actually new
        if tutorialID == "onboarding" {
            // Check if user has completed profile setup (indicating they're not new)
            let profileCompleted = userDefaults.bool(forKey: "profile_completed")
            let hasUsername = userDefaults.string(forKey: "profile_username") != nil
            let hasName = userDefaults.string(forKey: "profile_name") != nil
            
            // If user has completed profile setup previously, don't show tutorial
            if profileCompleted || (hasUsername && hasName) {
                print("🎯 Tutorial: User has existing profile, skipping onboarding tutorial")
                return false
            }
        }
        
        print("🎯 Tutorial: shouldShowTutorial(\(tutorialID)) = \(!tutorialCompleted)")
        return !tutorialCompleted
    }
    
    // Mark tutorial as completed
    func markTutorialCompleted(for tutorialID: String) {
        userDefaults.set(true, forKey: "tutorial_completed_\(tutorialID)")
        userDefaults.synchronize()
        print("🎯 Tutorial: Marked \(tutorialID) as completed")
    }
    
    // Add method to reset tutorials (for testing)
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

// MARK: - Tutorial Overlay View
struct TutorialOverlay: View {
    @ObservedObject var tutorialManager: TutorialManager
    let tutorialID: String
    
    var body: some View {
        if tutorialManager.isShowingTutorial,
           let currentStep = tutorialManager.currentStep {
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.3), value: tutorialManager.currentStepIndex)
                
                // Highlight area (if specified)
                if let highlightArea = currentStep.highlightArea {
                    Rectangle()
                        .frame(width: highlightArea.width, height: highlightArea.height)
                        .position(x: highlightArea.midX, y: highlightArea.midY)
                        .blendMode(.destinationOut)
                }
                
                // Tutorial content
                TutorialCard(
                    step: currentStep,
                    tutorialManager: tutorialManager,
                    tutorialID: tutorialID
                )
            }
            .compositingGroup()
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }
}

// MARK: - Tutorial Card
struct TutorialCard: View {
    let step: TutorialStep
    @ObservedObject var tutorialManager: TutorialManager
    let tutorialID: String
    
    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        let cardWidth = min(screenWidth - 64, 320) // Responsive width with max
        
        VStack(spacing: 16) {
            // Close button
            HStack {
                Spacer()
                Button(action: {
                    tutorialManager.markTutorialCompleted(for: tutorialID)
                    tutorialManager.endTutorial()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Content
            VStack(spacing: 14) {
                // Image/Icon
                if let imageName = step.image {
                    Image(systemName: imageName)
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                }
                
                // Title
                Text(step.title)
                    .font(.custom("Fredoka-Bold", size: screenWidth < 375 ? 20 : 24))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                // Description
                Text(step.description)
                    .font(.custom("Fredoka-Regular", size: screenWidth < 375 ? 14 : 16))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Progress indicator
                HStack(spacing: 6) {
                    ForEach(0..<tutorialManager.steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == tutorialManager.currentStepIndex ? Color.blue : Color.white.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.vertical, 8)
                
                // Navigation buttons
                HStack(spacing: 12) {
                    if !tutorialManager.isFirstStep {
                        Button(action: {
                            tutorialManager.previousStep()
                        }) {
                            Text("Back")
                                .font(.custom("Fredoka-Medium", size: 14))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if tutorialManager.isLastStep {
                            tutorialManager.markTutorialCompleted(for: tutorialID)
                            tutorialManager.endTutorial()
                            
                            // Navigate to circles if this is the onboarding tutorial
                            if tutorialID == "onboarding" {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    // Navigate to groups view using window scene navigation
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
                        } else {
                            tutorialManager.nextStep()
                        }
                    }) {
                        Text(tutorialManager.isLastStep ? "Get Started!" : "Next")
                            .font(.custom("Fredoka-Medium", size: 14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .frame(width: cardWidth)
        .padding(.horizontal, 32)
        .position(getCardPosition())
    }
    
    private func getCardPosition() -> CGPoint {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        // Get safe area insets with iOS 15+ compatibility
        let safeAreaInsets: UIEdgeInsets
        if #available(iOS 15.0, *) {
            safeAreaInsets = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow })?.safeAreaInsets ?? UIEdgeInsets.zero
        } else {
            safeAreaInsets = UIApplication.shared.windows.first?.safeAreaInsets ?? UIEdgeInsets.zero
        }
        
        // Account for safe areas and navigation
        let topSafeArea = max(safeAreaInsets.top, 44) // At least 44pts for status bar
        let bottomSafeArea = max(safeAreaInsets.bottom, 20) // At least 20pts padding
        let availableHeight = screenHeight - topSafeArea - bottomSafeArea
        
        switch step.position {
        case .top:
            // Position in upper third, accounting for safe area and navigation
            let yPosition = topSafeArea + 60 + (availableHeight * 0.15)
            return CGPoint(x: screenWidth / 2, y: min(yPosition, screenHeight * 0.3))
        case .bottom:
            // Position in lower third, accounting for safe area
            let yPosition = screenHeight - bottomSafeArea - 100 - (availableHeight * 0.15)
            return CGPoint(x: screenWidth / 2, y: max(yPosition, screenHeight * 0.7))
        case .center:
            // True center accounting for safe areas
            let yPosition = topSafeArea + (availableHeight / 2)
            return CGPoint(x: screenWidth / 2, y: yPosition)
        case .custom(let point):
            return point
        }
    }
}

// MARK: - Tutorial Extensions
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
    
    func tutorialHighlight(
        id: String,
        tutorialManager: TutorialManager,
        highlightColor: Color = .blue
    ) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(highlightColor, lineWidth: 3)
                .opacity(shouldHighlight(id: id, tutorialManager: tutorialManager) ? 1 : 0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), 
                          value: shouldHighlight(id: id, tutorialManager: tutorialManager))
        )
    }
    
    private func shouldHighlight(id: String, tutorialManager: TutorialManager) -> Bool {
        guard tutorialManager.isShowingTutorial,
              let currentStep = tutorialManager.currentStep else { return false }
        return currentStep.targetView == id
    }
}

// MARK: - Predefined Tutorial Flows
extension TutorialManager {
    
    // Onboarding Tutorial
    static func createOnboardingTutorial() -> [TutorialStep] {
        return [
            TutorialStep(
                title: "Welcome to DIML! 🎉",
                description: "Day In My Life - where you share authentic moments with your closest friends through daily prompts and photos.",
                targetView: nil,
                position: .center,
                action: .next,
                image: "heart.fill",
                highlightArea: nil
            ),
            
            TutorialStep(
                title: "Create Your Profile ✨",
                description: "Let's set up your profile with a photo, pronouns, and some fun details about yourself.",
                targetView: "profile_section",
                position: .top,
                action: .next,
                image: "person.circle.fill",
                highlightArea: nil
            ),
            
            TutorialStep(
                title: "Join or Create Groups 👥",
                description: "DIML is all about sharing with close friends. You can join existing groups or create your own circle.",
                targetView: "groups_section",
                position: .center,
                action: .next,
                image: "person.3.fill",
                highlightArea: nil
            ),
            
            TutorialStep(
                title: "Daily Prompts 📝",
                description: "Every day, you'll receive fun prompts to share moments from your life - both photos and thoughts.",
                targetView: "prompts_section",
                position: .bottom,
                action: .next,
                image: "lightbulb.fill",
                highlightArea: nil
            ),
            
            TutorialStep(
                title: "Your Memory Capsule 📸",
                description: "All your shared moments get collected in your personal capsule - a beautiful timeline of your memories.",
                targetView: "capsule_section",
                position: .center,
                action: .next,
                image: "photo.on.rectangle.angled",
                highlightArea: nil
            ),
            
            TutorialStep(
                title: "Ready to Start! 🚀",
                description: "You're all set! Start by completing your profile, then invite friends or join groups to begin sharing your daily moments.",
                targetView: nil,
                position: .center,
                action: .done,
                image: "checkmark.circle.fill",
                highlightArea: nil
            )
        ]
    }
    
    // Feature-specific tutorials
    static func createGroupTutorial() -> [TutorialStep] {
        return [
            TutorialStep(
                title: "Understanding Groups 👥",
                description: "Groups are your private circles where you share daily life moments with close friends.",
                targetView: nil,
                position: .center,
                action: .next,
                image: "person.3.fill",
                highlightArea: nil
            ),
            
            TutorialStep(
                title: "The Influencer Role ⭐",
                description: "Each day, one person becomes the 'influencer' and can take photos for prompts. This role rotates daily.",
                targetView: "influencer_indicator",
                position: .top,
                action: .next,
                image: "star.fill",
                highlightArea: nil
            ),
            
            TutorialStep(
                title: "Prompts & Responses 💬",
                description: "Everyone receives the same prompt and can respond with text, photos, or both - creating shared experiences.",
                targetView: "prompt_area",
                position: .bottom,
                action: .next,
                image: "bubble.left.and.bubble.right.fill",
                highlightArea: nil
            ),
            
            TutorialStep(
                title: "React & Comment ❤️",
                description: "Show love for your friends' posts with reactions and comments - keep the conversation going!",
                targetView: "reaction_area",
                position: .center,
                action: .done,
                image: "heart.circle.fill",
                highlightArea: nil
            )
        ]
    }
    
    static func createCapsuleTutorial() -> [TutorialStep] {
        return [
            TutorialStep(
                title: "Your Memory Capsule 📸",
                description: "This is your personal collection of all the moments you've shared in DIML.",
                targetView: "capsule_main",
                position: .top,
                action: .next,
                image: "photo.stack.fill",
                highlightArea: nil
            ),
            
            TutorialStep(
                title: "Daily Collections 📅",
                description: "Your entries are organized by date, with each day showing a preview that flickers through your uploads.",
                targetView: "daily_capsule",
                position: .center,
                action: .next,
                image: "calendar",
                highlightArea: nil
            ),
            
            TutorialStep(
                title: "Tap to Explore 👆",
                description: "Tap any day to see all your entries from that day in detail - photos, responses, and memories.",
                targetView: "capsule_card",
                position: .bottom,
                action: .next,
                image: "hand.tap.fill",
                highlightArea: nil
            ),
            
            TutorialStep(
                title: "Pull to Refresh 🔄",
                description: "Swipe down anytime to refresh and see your latest uploads appear in your capsule.",
                targetView: "refresh_area",
                position: .top,
                action: .done,
                image: "arrow.clockwise",
                highlightArea: nil
            )
        ]
    }
} 