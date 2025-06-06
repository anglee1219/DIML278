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
                        
                        // Note: Additional tutorials can be added here in the future
                        VStack(spacing: 8) {
                            Text("More tutorials coming soon!")
                                .font(.custom("Fredoka-Medium", size: 16))
                                .foregroundColor(.gray)
                            
                            Text("We're working on additional tutorials for groups, memory capsule, and other features.")
                                .font(.custom("Fredoka-Regular", size: 14))
                                .foregroundColor(.gray.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 16)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Reset all tutorials
                        Button(action: {
                            resetAllTutorials()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .font(.title3)
                                Text("Reset Tutorial")
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
        let tutorialIDs = ["onboarding"]
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