import SwiftUI

struct TutorialTriggerView: View {
    @StateObject private var tutorialManager = TutorialManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Add top padding for smaller screens
                    Spacer()
                        .frame(height: 10)
                    
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("DIML Tutorials")
                            .font(.custom("Fredoka-Bold", size: 24))
                            .foregroundColor(.black)
                        
                        Text("Learn how to use DIML features")
                            .font(.custom("Fredoka-Regular", size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 10)
                    
                    // Tutorial options
                    VStack(spacing: 12) {
                        TutorialOptionCard(
                            icon: "heart.fill",
                            title: "App Overview",
                            description: "Learn the basics of DIML and how to get started",
                            completed: !tutorialManager.shouldShowTutorial(for: "onboarding")
                        ) {
                            let steps = TutorialManager.createOnboardingTutorial()
                            tutorialManager.startTutorial(steps: steps)
                        }
                        
                        TutorialOptionCard(
                            icon: "person.3.fill",
                            title: "Groups & Friends",
                            description: "Understand how groups work and the influencer system",
                            completed: !tutorialManager.shouldShowTutorial(for: "groups")
                        ) {
                            let steps = TutorialManager.createGroupTutorial()
                            tutorialManager.startTutorial(steps: steps)
                        }
                        
                        TutorialOptionCard(
                            icon: "photo.stack.fill",
                            title: "Memory Capsule",
                            description: "Explore your personal collection of shared moments",
                            completed: !tutorialManager.shouldShowTutorial(for: "capsule")
                        ) {
                            let steps = TutorialManager.createCapsuleTutorial()
                            tutorialManager.startTutorial(steps: steps)
                        }
                        
                        // Reset all tutorials
                        Button(action: {
                            resetAllTutorials()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .font(.title3)
                                Text("Reset All Tutorials")
                                    .font(.custom("Fredoka-Medium", size: 16))
                            }
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.top, 16)
                    }
                    .padding(.horizontal, 20)
                    
                    // Add bottom padding for scroll content
                    Spacer()
                        .frame(height: 40)
                }
            }
            .background(Color(red: 1, green: 0.989, blue: 0.93))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.custom("Fredoka-Medium", size: 16))
                    .foregroundColor(.blue)
                }
            }
        }
        .tutorialOverlay(tutorialManager: tutorialManager, tutorialID: "manual")
    }
    
    private func resetAllTutorials() {
        let tutorialIDs = ["onboarding", "groups", "capsule"]
        for id in tutorialIDs {
            UserDefaults.standard.removeObject(forKey: "tutorial_completed_\(id)")
        }
        UserDefaults.standard.synchronize()
    }
}

struct TutorialOptionCard: View {
    let icon: String
    let title: String
    let description: String
    let completed: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(completed ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: completed ? "checkmark.circle.fill" : icon)
                        .font(.system(size: 24))
                        .foregroundColor(completed ? .green : .blue)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.custom("Fredoka-Medium", size: 18))
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        if completed {
                            Text("Completed")
                                .font(.custom("Fredoka-Regular", size: 12))
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    
                    Text(description)
                        .font(.custom("Fredoka-Regular", size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                }
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    TutorialTriggerView()
} 