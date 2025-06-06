import SwiftUI
import AVFoundation
import FirebaseAuth
import FirebaseStorage
import Foundation
import UserNotifications
import FirebaseFirestore
import FirebaseMessaging

// Seeded random number generator for consistent daily prompts
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var seed: UInt64
    
    init(seed: UInt64) {
        self.seed = seed
    }
    
    mutating func next() -> UInt64 {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return seed
    }
}

// Extension to make TimeOfDay hashable for seeded random
extension TimeOfDay: Hashable {
    var hashValue: Int {
        switch self {
        case .morning: return 1
        case .afternoon: return 2
        case .night: return 3
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(hashValue)
    }
}

// Create a shared instance of ProfileViewModel
class SharedProfileViewModel {
    static let shared = ProfileViewModel()
}

struct GroupDetailView: View {
    @State private var group: Group
    @StateObject var store: EntryStore
    @ObservedObject var groupStore: GroupStore
    @State private var goToDIML = false
    @State private var showCamera = false
    @State private var showPermissionAlert = false
    @Environment(\.dismiss) private var dismiss
    @State private var currentTab: Tab = .home
    @State private var showSettings = false
    @State private var keyboardVisible = false
    @State private var showAddEntry = false
    @State private var currentPrompt = ""
    @Environment(\.presentationMode) var presentationMode
    @State private var capturedImage: UIImage?
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var responseText = ""
    @State private var capturedFrameSize: FrameSize = FrameSize.random
    @State private var nextPromptCountdown = ""
    @State private var countdownTimer: Timer?
    @FocusState private var isResponseFieldFocused: Bool
    @State private var shouldScrollToResponse = false
    @State private var cachedIsInfluencer: Bool = false
    @State private var showComments = false
    @State private var selectedEntryForComments: DIMLEntry?
    @State private var hasInteractedWithCurrentPrompt = false
    @State private var isUnlockingPrompt = false
    @State private var showNewPromptCard = false
    @State private var animateCountdownRefresh = false
    @State private var hasUnlockedNewPrompt = false
    @State private var currentPromptRequiresCamera = false
    @State private var isImagePrompt = false
    @State private var currentPromptConfiguration: PromptConfiguration?
    @State private var shouldAutoScrollToPrompt = false
    @State private var hasTriggeredUnlockForCurrentPrompt = false // NEW: Prevent duplicate unlocks
    @State private var showPromptCompletedFeedback = false // NEW: Show when prompt is completed
    @State private var showNewPromptUnlockedFeedback = false // NEW: Show when new prompt unlocks
    @State private var hasNewPromptReadyForAnimation = false // NEW: Flag for delayed animation trigger
    @State private var isRefreshing = false // NEW: Show refresh indicator
    @State private var isActivelyViewingChat = false // NEW: Track if user is actively in this chat view
    
    // Notification handling states
    @State private var cameFromNotification = false
    @State private var shouldTriggerNotificationUnlock = false
    @State private var notificationPrompt = ""
    
    private let promptManager = PromptManager.shared
    private let storage = StorageManager.shared

    // Default initializer for existing usage
    init(group: Group, groupStore: GroupStore) {
        self._group = State(initialValue: group)
        self.groupStore = groupStore
        self._store = StateObject(wrappedValue: EntryStore(groupId: group.id))
        // Initialize cached influencer status
        self._cachedIsInfluencer = State(initialValue: Auth.auth().currentUser?.uid == group.currentInfluencerId)
        // Notification states
        self._cameFromNotification = State(initialValue: false)
        self._shouldTriggerNotificationUnlock = State(initialValue: false)
        self._notificationPrompt = State(initialValue: "")
    }
    
    // New initializer for notification handling
    init(group: Group, groupStore: GroupStore, shouldTriggerUnlock: Bool, notificationUserInfo: [String: Any]) {
        self._group = State(initialValue: group)
        self.groupStore = groupStore
        self._store = StateObject(wrappedValue: EntryStore(groupId: group.id))
        // Initialize cached influencer status
        self._cachedIsInfluencer = State(initialValue: Auth.auth().currentUser?.uid == group.currentInfluencerId)
        // Notification states
        self._cameFromNotification = State(initialValue: true)
        self._shouldTriggerNotificationUnlock = State(initialValue: shouldTriggerUnlock)
        self._notificationPrompt = State(initialValue: notificationUserInfo["prompt"] as? String ?? "")
        
        print("🔔 🎯 GroupDetailView initialized from notification")
        print("🔔 🎯 Group: \(group.name)")
        print("🔔 🎯 Should trigger unlock: \(shouldTriggerUnlock)")
        print("🔔 🎯 Notification prompt: \(notificationUserInfo["prompt"] as? String ?? "")")
    }

    // Get the user's name from UserDefaults
    private var userName: String {
        SharedProfileViewModel.shared.name
    }

    // Use the saved name for current user
    var currentUser: User {
        let profile = SharedProfileViewModel.shared
        return User(
            id: Auth.auth().currentUser?.uid ?? "", // Use actual Firebase Auth ID
            name: profile.name,
            username: "@\(profile.name.lowercased())",
            role: .admin
        )
    }

    var influencer: User? {
        group.members.first(where: { $0.id == group.currentInfluencerId })
    }

    var isInfluencer: Bool {
        return cachedIsInfluencer
    }
    
    private func updateInfluencerStatus() {
        let newStatus = Auth.auth().currentUser?.uid == group.currentInfluencerId
        if newStatus != cachedIsInfluencer {
            print("Updating influencer status - Current user ID: \(Auth.auth().currentUser?.uid ?? "none"), Influencer ID: \(group.currentInfluencerId)")
            cachedIsInfluencer = newStatus
        }
    }
    
    private func loadDailyPrompt() {
        print("🎯 loadDailyPrompt called")
        
        // First, check if there are any completed entries that should determine timing
        if let mostRecentEntry = store.entries.max(by: { $0.timestamp < $1.timestamp }) {
            print("🎯 Found most recent completed entry: '\(mostRecentEntry.prompt)' at \(mostRecentEntry.timestamp)")
            
            // Check if enough time has passed since the most recent entry for a new prompt
            if let nextPromptTime = calculateNextPromptTime() {
                let now = Date()
                let timeRemaining = nextPromptTime.timeIntervalSince(now)
                print("🎯 Time remaining since most recent entry: \(timeRemaining)s")
                
                if timeRemaining > 0 {
                    // Still need to wait - preserve the most recent prompt for timing calculations
                    print("🎯 Time not elapsed yet, preserving most recent prompt for timing: '\(mostRecentEntry.prompt)'")
                    currentPrompt = mostRecentEntry.prompt
                    
                    // Also preserve/recreate the configuration for this prompt
                    if currentPromptConfiguration == nil {
                        currentPromptConfiguration = getCurrentPromptConfiguration()
                        if let config = currentPromptConfiguration {
                            isImagePrompt = config.fields.isEmpty
                        }
                    }
                    return
                } else {
                    print("🎯 Time has elapsed since most recent entry! Ready for new prompt")
                    // Time has elapsed, generate new prompt below
                }
            }
        }
        
        print("🎯 Generating new prompt configuration...")
        
        // Generate the configuration once and store it
        currentPromptConfiguration = getCurrentPromptConfiguration()
        
        guard let config = currentPromptConfiguration else {
            currentPrompt = "What does your day look like?"
            isImagePrompt = false
            return
        }
        
        // All configurations now have the prompt in the main prompt field
        currentPrompt = config.prompt.isEmpty ? "What does your day look like?" : config.prompt
        
        // Check if this is an image prompt (no input fields)
        isImagePrompt = config.fields.isEmpty
        
        print("🎯 Loaded daily prompt: '\(currentPrompt)'")
        print("🎯 Is image prompt: \(isImagePrompt)")
        print("🎯 Configuration stored for consistency")
    }
    
    private func shouldShowNextPrompt() -> Bool {
        // Check if user has completed the current prompt
        let hasCompletedCurrentPrompt = store.entries.contains { $0.prompt == currentPrompt }
        
        // If current prompt hasn't been completed, don't show next prompt
        guard hasCompletedCurrentPrompt else {
            print("🕐 shouldShowNextPrompt: Current prompt not completed")
            return false
        }
        
        // If current prompt is completed, check if enough time has passed for next prompt based on group frequency
        guard let nextPromptTime = calculateNextPromptTime() else {
            print("🕐 shouldShowNextPrompt: No next prompt time calculated")
            return false
        }
        
        let now = Date()
        let timeRemaining = nextPromptTime.timeIntervalSince(now)
        let shouldShow = timeRemaining <= 0
        
        print("🕐 shouldShowNextPrompt: timeRemaining=\(timeRemaining), shouldShow=\(shouldShow)")
        print("🕐 shouldShowNextPrompt: Using group frequency \(group.promptFrequency)")
        
        return shouldShow
    }
    
    private func getCurrentPrompt() -> String {
        // If we already have a current prompt and haven't completed it, keep using it
        if !currentPrompt.isEmpty {
            let hasCompletedCurrentPrompt = store.entries.contains { $0.prompt == currentPrompt }
            if !hasCompletedCurrentPrompt {
                print("🎯 getCurrentPrompt: Keeping existing incomplete prompt: '\(currentPrompt)'")
                return currentPrompt
            }
        }
        
        // Only generate a new prompt if current one is completed or empty
        print("🎯 getCurrentPrompt: Generating new prompt...")
        
        // Use the stored configuration if available, otherwise generate new one
        if let config = currentPromptConfiguration, !config.prompt.isEmpty {
            print("🎯 getCurrentPrompt: Using stored configuration prompt: '\(config.prompt)'")
            return config.prompt
        }
        
        // Fallback to generating new configuration
        let newConfig = getCurrentPromptConfiguration()
        currentPromptConfiguration = newConfig
        let newPrompt = newConfig.prompt.isEmpty ? "What does your day look like?" : newConfig.prompt
        print("🎯 getCurrentPrompt: Generated new prompt: '\(newPrompt)'")
        return newPrompt
    }

    // MARK: - Dynamic Prompt Configuration
    
    private func getCurrentPromptConfiguration() -> PromptConfiguration {
        let completedCount = store.entries.count
        let isEvenPrompt = completedCount % 2 == 0
        
        // Specific questions for date bubble cards (Type 2)
        let dateBubbleQuestions = [
            "What's the last thing that made you laugh today?",
            "What's something small that made your day better?",
            "What's one thing you're grateful for right now?",
            "What's been on your mind lately?",
            "What's the most interesting thing you learned today?",
            "What's a moment from today you want to remember?",
            "What's something you're looking forward to?",
            "What's a challenge you're working through?",
            "What's bringing you joy today?",
            "What's something you accomplished recently?"
        ]
        
        // Specific questions for mood/energy cards (Type 3)
        let moodEnergyQuestions = [
            "How are you feeling about this week?",
            "What's your energy like today?",
            "How would you describe your current mood?",
            "What's your vibe right now?",
            "How are you doing mentally today?",
            "What's your headspace like?",
            "How's your day treating you?",
            "What's your current state of mind?",
            "How are you feeling in this moment?",
            "What's your emotional temperature today?"
        ]
        
        // Get completed prompts to avoid duplicates
        let completedPrompts = Set(store.entries.map { $0.prompt })
        
        // Determine if this should be an image prompt or text prompt (alternating)
        if isEvenPrompt {
            // Even prompts: IMAGE PROMPTS (clean cards with no input fields - users take photos)
            var uniquePrompt: String
            var attempts = 0
            let maxAttempts = 50
            
            repeat {
                let timeOfDay = TimeOfDay.current()
                let calendar = Calendar.current
                let today = Date()
                let baseDailySeed = calendar.component(.year, from: today) * 1000 + (calendar.ordinality(of: .day, in: .year, for: today) ?? 1)
                let variationSeed = UInt64(abs(baseDailySeed)) + 
                                   UInt64(attempts * 7919) + 
                                   UInt64(completedCount * 1337) +
                                   UInt64(abs(group.id.hashValue))
                
                var generator = SeededRandomNumberGenerator(seed: variationSeed)
                uniquePrompt = promptManager.getSeededPrompt(for: timeOfDay, using: &generator) ?? "What does your day look like?"
                attempts += 1
            } while completedPrompts.contains(uniquePrompt) && attempts < maxAttempts
            
            // IMAGE PROMPT: Clean card with no input fields (like "small step" style)
            // Add date bubble only for the very first entry (completedCount == 0)
            return PromptConfiguration(
                prompt: uniquePrompt,
                fields: [],
                backgroundColor: "blue", // Main blue
                dateLabel: completedCount == 0 ? getCurrentDateLabel() : nil
            )
            
        } else {
            // Odd prompts: TEXT-BASED PROMPTS (Types 1, 2, or 3 with input fields)
            let textPromptType = completedCount % 3 // Cycle through 3 types
            
            if textPromptType == 1 {
                // Type 1: Simple text prompt with input field
                var uniquePrompt: String
                var attempts = 0
                let maxAttempts = 50
                
                repeat {
                    let timeOfDay = TimeOfDay.current()
                    let calendar = Calendar.current
                    let today = Date()
                    let baseDailySeed = calendar.component(.year, from: today) * 1000 + (calendar.ordinality(of: .day, in: .year, for: today) ?? 1)
                    let variationSeed = UInt64(abs(baseDailySeed)) + 
                                       UInt64(attempts * 7919) + 
                                       UInt64(completedCount * 1337) +
                                       UInt64(abs(group.id.hashValue)) +
                                       UInt64(1000) // Different seed for text prompts
                    
                    var generator = SeededRandomNumberGenerator(seed: variationSeed)
                    uniquePrompt = promptManager.getSeededPrompt(for: timeOfDay, using: &generator) ?? "What does your day look like?"
                    attempts += 1
                } while completedPrompts.contains(uniquePrompt) && attempts < maxAttempts
                
                return PromptConfiguration(
                    prompt: uniquePrompt,
                    fields: [
                        PromptField(title: "", placeholder: "Tell us about it...", type: .text, isRequired: false)
                    ],
                    backgroundColor: "cream" // Main yellow (low opacity)
                )
                
            } else if textPromptType == 2 {
                // Type 2: Date + Location bubble cards
                let questionIndex = abs(completedCount.hashValue) % dateBubbleQuestions.count
                let selectedQuestion = dateBubbleQuestions[questionIndex]
                
                // Make sure we don't repeat this question
                var finalQuestion = selectedQuestion
                var questionAttempts = 0
                while completedPrompts.contains(finalQuestion) && questionAttempts < dateBubbleQuestions.count {
                    let newIndex = (questionIndex + questionAttempts + 1) % dateBubbleQuestions.count
                    finalQuestion = dateBubbleQuestions[newIndex]
                    questionAttempts += 1
                }
                
                return PromptConfiguration(
                    prompt: finalQuestion,
                    fields: [
                        PromptField(title: "current mood", placeholder: "how are you feeling?", type: .text),
                        PromptField(title: "what's happening", placeholder: "tell us more...", type: .text)
                    ],
                    backgroundColor: "green", // Grey (very low opacity)
                    dateLabel: getCurrentDateLabel(),
                    locationLabel: "tell us wya? 👀"
                )
                
            } else {
                // Type 3: Energy/mood selection cards
                let questionIndex = abs(completedCount.hashValue) % moodEnergyQuestions.count
                let selectedQuestion = moodEnergyQuestions[questionIndex]
                
                // Make sure we don't repeat this question
                var finalQuestion = selectedQuestion
                var questionAttempts = 0
                while completedPrompts.contains(finalQuestion) && questionAttempts < moodEnergyQuestions.count {
                    let newIndex = (questionIndex + questionAttempts + 1) % moodEnergyQuestions.count
                    finalQuestion = moodEnergyQuestions[newIndex]
                    questionAttempts += 1
                }
                
                return PromptConfiguration(
                    prompt: finalQuestion,
                    fields: [
                        PromptField(title: "How's your energy?", placeholder: "Select your energy level", type: .mood),
                        PromptField(title: "Share more", placeholder: "tell us more...", type: .text, isRequired: false)
                    ],
                    backgroundColor: "pink", // Main yellow (medium opacity)
                    dateLabel: getCurrentDateLabel()
                )
            }
        }
    }
    
    // NEW: Create configuration for a specific prompt text (preserves prompt consistency)
    private func createPromptConfiguration(for promptText: String) -> PromptConfiguration {
        let completedCount = store.entries.count
        let isEvenPrompt = completedCount % 2 == 0
        
        // Determine if this should be an image prompt or text prompt (alternating)
        if isEvenPrompt {
            // IMAGE PROMPT: Clean card with no input fields
            return PromptConfiguration(
                prompt: promptText,
                fields: [],
                backgroundColor: "blue", // Main blue
                dateLabel: completedCount == 0 ? getCurrentDateLabel() : nil
            )
        } else {
            // TEXT-BASED PROMPT: Determine type based on completed count
            let textPromptType = completedCount % 3 // Cycle through 3 types
            
            if textPromptType == 1 {
                // Type 1: Simple text prompt with input field
                return PromptConfiguration(
                    prompt: promptText,
                    fields: [
                        PromptField(title: "", placeholder: "Tell us about it...", type: .text, isRequired: false)
                    ],
                    backgroundColor: "cream" // Main yellow (low opacity)
                )
                
            } else if textPromptType == 2 {
                // Type 2: Date + Location bubble cards
                return PromptConfiguration(
                    prompt: promptText,
                    fields: [
                        PromptField(title: "current mood", placeholder: "how are you feeling?", type: .text),
                        PromptField(title: "what's happening", placeholder: "tell us more...", type: .text)
                    ],
                    backgroundColor: "green", // Grey (very low opacity)
                    dateLabel: getCurrentDateLabel(),
                    locationLabel: "tell us wya? 👀"
                )
                
            } else {
                // Type 3: Energy/mood selection cards
                return PromptConfiguration(
                    prompt: promptText,
                    fields: [
                        PromptField(title: "How's your energy?", placeholder: "Select your energy level", type: .mood),
                        PromptField(title: "Share more", placeholder: "tell us more...", type: .text, isRequired: false)
                    ],
                    backgroundColor: "pink", // Main yellow (medium opacity)
                    dateLabel: getCurrentDateLabel()
                )
            }
        }
    }
    
    private func getCurrentDateLabel() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: Date())
    }
    
    private func getCurrentLocationLabel() -> String? {
        // Return the specific text the user wants for location
        return "tell us wya? 👀"
    }
    
    private func getTimeOfDayDisplay() -> String {
        let timeOfDay = TimeOfDay.current()
        switch timeOfDay {
        case .morning:
            return "☀️ Morning"
        case .afternoon:
            return "🌞 Afternoon" 
        case .night:
            return "🌙 Evening"
        }
    }

    private func getTimeOfDayIcon() -> String {
        let timeOfDay = TimeOfDay.current()
        switch timeOfDay {
        case .morning:
            return "sunrise"
        case .afternoon:
            return "sun.max"
        case .night:
            return "moon.stars"
        }
    }

    private func getPromptIcon() -> String {
        let prompt = currentPrompt.lowercased()
        
        // Activity-based icons
        if prompt.contains("workout") || prompt.contains("exercise") || prompt.contains("gym") || prompt.contains("fitness") {
            return "figure.run"
        } else if prompt.contains("coffee") || prompt.contains("cafe") || prompt.contains("latte") {
            return "cup.and.saucer"
        } else if prompt.contains("food") || prompt.contains("eat") || prompt.contains("meal") || prompt.contains("lunch") || prompt.contains("dinner") || prompt.contains("breakfast") {
            return "fork.knife"
        } else if prompt.contains("work") || prompt.contains("office") || prompt.contains("meeting") {
            return "briefcase"
        } else if prompt.contains("read") || prompt.contains("book") || prompt.contains("study") {
            return "book"
        } else if prompt.contains("music") || prompt.contains("song") || prompt.contains("listen") {
            return "music.note"
        } else if prompt.contains("walk") || prompt.contains("outside") || prompt.contains("nature") {
            return "leaf"
        } else if prompt.contains("friend") || prompt.contains("people") || prompt.contains("social") {
            return "person.2"
        } else if prompt.contains("travel") || prompt.contains("trip") || prompt.contains("vacation") {
            return "airplane"
        } else if prompt.contains("home") || prompt.contains("house") || prompt.contains("room") {
            return "house"
        } else if prompt.contains("phone") || prompt.contains("call") || prompt.contains("text") {
            return "phone"
        } else if prompt.contains("creative") || prompt.contains("art") || prompt.contains("design") {
            return "paintbrush"
        } else if prompt.contains("relax") || prompt.contains("chill") || prompt.contains("rest") {
            return "bed.double"
        } else if prompt.contains("shop") || prompt.contains("buy") || prompt.contains("store") {
            return "bag"
        } else if prompt.contains("car") || prompt.contains("drive") || prompt.contains("transport") {
            return "car"
        } else if prompt.contains("weather") || prompt.contains("rain") || prompt.contains("sunny") {
            return "cloud.sun"
        } else if prompt.contains("love") || prompt.contains("heart") || prompt.contains("relationship") {
            return "heart"
        } else if prompt.contains("goal") || prompt.contains("achieve") || prompt.contains("accomplish") {
            return "target"
        } else if prompt.contains("think") || prompt.contains("mind") || prompt.contains("reflect") {
            return "brain.head.profile"
        } else if prompt.contains("celebrate") || prompt.contains("party") || prompt.contains("fun") {
            return "party.popper"
        } else {
            // Fallback to time-based icons
            let timeOfDay = TimeOfDay.current()
            switch timeOfDay {
            case .morning:
                return "sunrise"
            case .afternoon:
                return "sun.max"
            case .night:
                return "moon.stars"
            }
        }
    }

    private func uploadImage(_ image: UIImage) {
        print("🔥 Starting image upload...")
        print("🔥 🔍 DEBUG: Current user ID: \(Auth.auth().currentUser?.uid ?? "nil")")
        print("🔥 🔍 DEBUG: isInfluencer: \(isInfluencer)")
        print("🔥 🔍 DEBUG: Current prompt: '\(currentPrompt)'")
        print("🔥 🔍 DEBUG: Group ID: \(group.id)")
        print("🔥 🔍 DEBUG: Group influencer ID: \(group.currentInfluencerId)")
        isUploading = true
        
        Task {
            do {
                // Add timeout wrapper
                let uploadResult = try await withTimeout(seconds: 30) {
                    let imagePath = "diml_images/\(UUID().uuidString).jpg"
                    print("🔥 Uploading to Firebase Storage path: \(imagePath)")
                    
                    // Check Firebase Auth state first
                    guard let currentUser = Auth.auth().currentUser else {
                        throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                    }
                    print("🔥 User authenticated: \(currentUser.uid)")
                    
                    let downloadURL = try await storage.uploadImage(image, path: imagePath)
                    print("🔥 Firebase Storage upload successful!")
                    print("🔥 Download URL: \(downloadURL)")
                    return downloadURL
                }
                
                let entry = DIMLEntry(
                    id: UUID().uuidString,
                    userId: Auth.auth().currentUser?.uid ?? "",
                    prompt: currentPrompt,
                    response: responseText,
                    image: nil, // Don't store local image since we have Firebase URL
                    imageURL: uploadResult, // Use Firebase Storage URL
                    frameSize: capturedFrameSize,
                    promptType: .image // Explicitly set as image prompt
                )
                
                print("🔥 Created DIMLEntry with imageURL: \(entry.imageURL ?? "nil")")
                print("🔥 Entry prompt: '\(entry.prompt)'")
                print("🔥 Entry response: '\(entry.response)'")
                
                await MainActor.run {
                    print("🔥 Adding entry to store...")
                    store.addEntry(entry)
                    print("🔥 Entry added to store. Total entries: \(store.entries.count)")
                    print("🔥 First entry imageURL: \(store.entries.first?.imageURL ?? "nil")")
                    
                    // Show completion feedback
                    showPromptCompletedFeedback = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        showPromptCompletedFeedback = false
                    }
                    
                    // Clear captured image and reset states
                    capturedImage = nil
                    responseText = ""
                    capturedFrameSize = FrameSize.random // Reset for next capture
                    hasInteractedWithCurrentPrompt = false // Reset interaction flag
                    
                    // Reset animation states when prompt is completed
                    resetAnimationStates()
                    
                    // EntryStore automatically sends upload notifications to OTHER group members
                    // (correctly excludes the person who uploaded)
                    
                    // Schedule notification for when influencer's NEXT prompt unlocks (future)
                    print("🔥 ⏭️ About to call scheduleNextPromptNotification after image upload")
                    print("🔥 ⏭️ Current user ID: \(Auth.auth().currentUser?.uid ?? "nil")")
                    print("🔥 ⏭️ isInfluencer: \(isInfluencer)")
                    print("🔥 ⏭️ Group muted: \(group.notificationsMuted)")
                    self.scheduleNextPromptNotification()
                    
                    isUploading = false
                    print("🔥 Upload process completed successfully")
                }
            } catch {
                print("🔥 Upload error: \(error.localizedDescription)")
                print("🔥 Full error: \(error)")
                
                // Determine specific error type
                let errorMsg: String
                if error.localizedDescription.contains("timeout") || error.localizedDescription.contains("timed out") {
                    errorMsg = "Upload timed out. Please check your internet connection and try again."
                } else if error.localizedDescription.contains("network") || error.localizedDescription.contains("internet") {
                    errorMsg = "Network error. Please check your internet connection."
                } else if error.localizedDescription.contains("auth") || error.localizedDescription.contains("permission") {
                    errorMsg = "Authentication error. Please try logging out and back in."
                } else {
                    errorMsg = "Upload failed: \(error.localizedDescription)"
                }
                
                await MainActor.run {
                    errorMessage = errorMsg
                    showError = true
                    isUploading = false
                }
            }
        }
    }
    
    // Helper function for timeout handling
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation
            group.addTask {
                return try await operation()
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "TimeoutError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation timed out after \(seconds) seconds"])
            }
            
            // Return the first completed task
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    func checkCameraPermission() {
        print("Checking camera permission")
        
        // Only influencers can use the camera
        guard isInfluencer else {
            // Show alert that only influencers can post
            showPermissionAlert = true
            return
        }
        
        // Check if current prompt has already been completed
        let hasCompletedCurrentPrompt = store.entries.contains { $0.prompt == currentPrompt }
        if hasCompletedCurrentPrompt {
            // Show alert that they've already completed this prompt
            errorMessage = "You've already completed this prompt! Your next prompt will unlock in \(nextPromptCountdown.isEmpty ? "a few hours" : nextPromptCountdown)."
            showError = true
            return
        }
        
        // CRITICAL: Don't interfere with notification animations
        if cameFromNotification && shouldTriggerNotificationUnlock {
            print("📷 ⚠️ Delaying camera permission check - notification animation in progress")
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.checkCameraPermission()
            }
            return
        }
        
        // All prompts now allow camera access - no need to check prompt type
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasInteractedWithCurrentPrompt = true // Mark that user is interacting with current prompt
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.hasInteractedWithCurrentPrompt = true // Mark interaction
                    }
                    self.showCamera = granted
                }
            }
        default:
            showPermissionAlert = true
        }
    }

    private func calculateNextPromptTime() -> Date? {
        print("⏰ ===== calculateNextPromptTime called =====")
        let calendar = Calendar.current
        
        // Get the group's frequency settings
        let frequency = group.promptFrequency
        print("⏰ Group frequency: \(frequency)")
        print("⏰ Group frequency raw value: \(frequency.rawValue)")
        print("⏰ intervalHours: \(frequency.intervalHours)")
        print("⏰ intervalMinutes: \(frequency.intervalMinutes)")
        
        // Find the most recent entry to calculate from
        guard let mostRecentEntry = store.entries.max(by: { $0.timestamp < $1.timestamp }) else {
            print("⏰ No entries found - this should not happen when calculating next prompt time")
            return nil
        }
        
        print("⏰ Found most recent entry with timestamp: \(mostRecentEntry.timestamp)")
        print("⏰ Most recent entry prompt: '\(mostRecentEntry.prompt)'")
        
        let completionTime = mostRecentEntry.timestamp
        let completionHour = calendar.component(.hour, from: completionTime)
        print("⏰ Completion hour: \(completionHour)")
        
        // Handle testing mode (1 minute intervals)
        if frequency == .testing {
            print("⏰ Testing mode detected - 1 minute intervals")
            let nextPromptTime = calendar.date(byAdding: .minute, value: 1, to: completionTime) ?? completionTime
            print("⏰ Next testing prompt time: \(nextPromptTime)")
            return nextPromptTime
        }
        
        // For regular frequencies, use the actual interval hours from the enum
        let intervalHours = frequency.intervalHours
        print("⏰ Using intervalHours from enum: \(intervalHours)")
        
        // Calculate the next prompt time by adding the correct interval
        let nextPromptTime = calendar.date(byAdding: .hour, value: intervalHours, to: completionTime) ?? completionTime
        
        print("⏰ Completion time: \(completionTime)")
        print("⏰ Adding \(intervalHours) hours interval")
        print("⏰ FINAL next prompt time: \(nextPromptTime)")
        print("⏰ Time difference from completion: \(nextPromptTime.timeIntervalSince(completionTime) / 3600) hours")
        print("⏰ ===== End calculateNextPromptTime =====")
        
        // ALWAYS respect the exact frequency interval - no active hours restriction
        return nextPromptTime
    }
    
    private func updateCountdown() {
        print("⏰ updateCountdown called")
        print("⏰ isInfluencer: \(isInfluencer)")
        print("⏰ currentPrompt: '\(currentPrompt)'")
        print("⏰ store.entries count: \(store.entries.count)")
        
        guard isInfluencer else {
            print("⏰ Not influencer, clearing countdown")
            nextPromptCountdown = ""
            return
        }
        
        // Check if user has completed the current prompt
        let hasCompletedCurrentPrompt = store.entries.contains { entry in
            let matches = entry.prompt == currentPrompt
            print("⏰ Checking entry: '\(entry.prompt)' == '\(currentPrompt)' = \(matches)")
            return matches
        }
        
        print("⏰ hasCompletedCurrentPrompt: \(hasCompletedCurrentPrompt)")
        
        // CRITICAL: Only show countdown if current prompt is completed
        guard hasCompletedCurrentPrompt else {
            print("⏰ Current prompt not completed - no countdown until it's answered")
            nextPromptCountdown = "Complete current prompt first"
            return
        }
        
        // If current prompt is completed, calculate time for NEXT prompt
        guard let nextPromptTime = calculateNextPromptTime() else {
            print("⏰ No next prompt time calculated")
            nextPromptCountdown = "Error calculating next prompt"
            return
        }
        
        let now = Date()
        let timeInterval = nextPromptTime.timeIntervalSince(now)
        
        print("⏰ nextPromptTime: \(nextPromptTime)")
        print("⏰ now: \(now)")
        print("⏰ timeInterval: \(timeInterval) seconds")
        
        if timeInterval <= 0 {
            print("⏰ Next prompt time has passed - making new prompt available")
            
            // SHOW COUNTDOWN AT ZERO FIRST for animation sequence
            if timeInterval >= -5 { // Within 5 seconds of unlock time
                nextPromptCountdown = "Prompt unlocking in 0s..."
            
            // Only trigger unlock animation if we haven't already done so for this timing cycle
            if !hasTriggeredUnlockForCurrentPrompt {
                print("🎯 🎬 Setting flag for delayed prompt unlock animation")
                hasTriggeredUnlockForCurrentPrompt = true
                
                    // CRITICAL: Don't change currentPrompt here - preserve it for the "0s..." display
                    // Only generate the new prompt DURING the animation, not before
                    
                    // Delay the animation slightly to show the "0s..." message first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        print("🎯 🎬 NOW generating new prompt for animation")
                        
                        // NOW generate the new prompt for the animation
                        let newPrompt = self.generateUniquePrompt()
                        print("🎯 🎬 Generated new prompt for animation: '\(newPrompt)'")
                        
                        // Store the new prompt but don't set currentPrompt yet
                        // The animation will handle setting currentPrompt at the right time
                    
                    // Send prompt unlock notification to influencer
                    print("📱 🔔 Sending prompt unlock notification for new prompt")
                        self.store.notifyPromptUnlock(prompt: newPrompt, influencerId: self.group.currentInfluencerId, groupName: self.group.name)
                    
                    // Only trigger animation if user is actively viewing this chat
                        if self.isActivelyViewingChat {
                        print("🎯 🎬 User is actively viewing chat - will trigger animation immediately")
                            self.hasNewPromptReadyForAnimation = false // Clear flag since we're using it now
                        
                            // Trigger animation with the newly generated prompt
                            self.triggerPromptUnlockAnimation(newPrompt: newPrompt)
                    } else {
                        print("🎯 🎬 User not actively viewing chat - animation will trigger when they enter")
                            // Store for later animation when user enters
                            self.hasNewPromptReadyForAnimation = true
                            self.currentPrompt = newPrompt // Set here for when user enters
                        }
                    }
                }
                return
                } else {
                nextPromptCountdown = "New prompt available!"
            }
            return
        }
        
        // Calculate time remaining and format appropriately
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60
        
        print("⏰ Time remaining: \(hours)h \(minutes)m \(seconds)s")
        
        // Format countdown based on frequency
        if group.promptFrequency == .testing {
            // For testing mode, show precise time including seconds
            if hours > 0 {
                nextPromptCountdown = "\(hours)h \(minutes)m \(seconds)s"
            } else if minutes > 0 {
                nextPromptCountdown = "\(minutes)m \(seconds)s"
            } else {
                nextPromptCountdown = "\(seconds)s"
            }
        } else {
            // For regular modes, show hours and minutes only
            if hours > 0 {
                nextPromptCountdown = "\(hours)h \(minutes)m"
            } else if minutes > 0 {
                nextPromptCountdown = "\(minutes)m"
            } else {
                nextPromptCountdown = "Less than 1m"
            }
        }
        
        print("⏰ Final countdown: '\(nextPromptCountdown)'")
    }
    
    private func startCountdownTimer() {
        stopCountdownTimer()
        updateCountdown()
        
        // Use appropriate timer intervals based on prompt frequency
        let timerInterval: TimeInterval
        switch group.promptFrequency {
        case .testing:
            timerInterval = 1.0 // Update every second for testing mode
        case .hourly:
            timerInterval = 60.0 // Update every minute for hourly prompts
        case .threeHours:
            timerInterval = 300.0 // Update every 5 minutes for 3-hour prompts  
        case .sixHours:
            timerInterval = 600.0 // Update every 10 minutes for 6-hour prompts
        }
        
        print("⏰ Starting countdown timer with interval: \(timerInterval) seconds for frequency: \(group.promptFrequency)")
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
            updateCountdown()
        }
    }
    
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    private func logPromptVisibility(isEmpty: Bool, showNewCard: Bool, hasUnlocked: Bool, hasCompleted: Bool, shouldShow: Bool) {
        print("🎬 Prompt visibility check:")
        print("🎬 - store.entries.isEmpty: \(isEmpty)")
        print("🎬 - showNewPromptCard: \(showNewCard)")
        print("🎬 - hasUnlockedNewPrompt: \(hasUnlocked)")
        print("🎬 - hasCompletedCurrentPrompt: \(hasCompleted)")
        print("🎬 - shouldShowPromptCard: \(shouldShow)")
        print("🎬 - currentPrompt: '\(currentPrompt)'")
    }
    
    private func triggerPromptUnlockAnimation(newPrompt: String) {
        print("🎬 ===== STARTING ENHANCED PROMPT UNLOCK ANIMATION SEQUENCE =====")
        print("🎬 Function called with newPrompt: '\(newPrompt)'")
        print("🎬 Current time: \(Date())")
        
        // Enhanced initial haptic feedback - stronger and more noticeable
        print("🎬 Triggering HEAVY haptic feedback for unlock start...")
        let startFeedback = UIImpactFeedbackGenerator(style: .heavy)
        startFeedback.prepare()
        startFeedback.impactOccurred()
        print("🎬 Heavy haptic feedback triggered!")
        
        // Step 1: Enhanced countdown refresh animation - more dramatic lock animation
        print("🎬 Step 1: Starting enhanced countdown refresh animation...")
        withAnimation(.easeInOut(duration: 0.5)) {
            animateCountdownRefresh = true
        }
        print("🎬 animateCountdownRefresh set to: \(animateCountdownRefresh)")
        
        // Add a second haptic pulse for the "unlocking" feel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            print("🎬 Triggering MEDIUM haptic feedback for unlock pulse...")
            let pulseFeedback = UIImpactFeedbackGenerator(style: .medium)
            pulseFeedback.prepare()
            pulseFeedback.impactOccurred()
            print("🎬 Medium pulse haptic feedback triggered!")
        }
        
        // Step 2: After refresh, start the unlock transition with more dramatic animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🎬 Step 2: Starting enhanced unlock transition...")
            
            // Haptic feedback for unlock phase - lighter taps
            print("🎬 Triggering LIGHT haptic feedback...")
            let unlockFeedback = UIImpactFeedbackGenerator(style: .light)
            unlockFeedback.prepare()
            unlockFeedback.impactOccurred()
            
            // Add a second light tap for "clicking" unlock sound
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                unlockFeedback.impactOccurred()
                print("🎬 Double-tap light haptic feedback triggered!")
            }
            
            // Enhanced unlocking state with more spring
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                isUnlockingPrompt = true
            }
            print("🎬 isUnlockingPrompt set to: \(isUnlockingPrompt)")
            
            // Step 3: Complete the unlock with celebration haptics and reveal
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                print("🎬 Step 3: Revealing new prompt card with celebration...")
                print("🎯 Setting currentPrompt to newPrompt: '\(newPrompt)'")
                currentPrompt = newPrompt
                hasInteractedWithCurrentPrompt = false
                
                // Regenerate and store new configuration for consistency - but keep the prompt
                print("🎯 Generating configuration for the new prompt...")
                currentPromptConfiguration = createPromptConfiguration(for: newPrompt)
                if let newConfig = currentPromptConfiguration {
                    isImagePrompt = newConfig.fields.isEmpty
                    print("🎯 New prompt is image prompt: \(isImagePrompt)")
                    print("🎯 Configuration generated for prompt: '\(newConfig.prompt)'")
                    // DON'T overwrite currentPrompt here - keep the newPrompt that was passed in
                } else {
                    print("🎯 ⚠️ Failed to generate configuration, keeping newPrompt: '\(newPrompt)'")
                    isImagePrompt = true // Default to image prompt if config fails
                }
                print("🎯 Final currentPrompt for camera: '\(currentPrompt)'")
                
                // Enhanced celebration haptic sequence
                print("🎬 Triggering SUCCESS haptic celebration...")
                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.prepare()
                successFeedback.notificationOccurred(.success)
                print("🎬 Success haptic feedback triggered!")
                
                // Show new prompt unlocked feedback
                print("🎬 Showing new prompt unlocked feedback...")
                showNewPromptUnlockedFeedback = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    showNewPromptUnlockedFeedback = false
                }
                
                // Final spring animation - countdown timer transforms into prompt card
                print("🎬 Triggering final transformation animation...")
                withAnimation(.spring(response: 1.2, dampingFraction: 0.6)) {
                    showNewPromptCard = true
                    hasUnlockedNewPrompt = true
                    isUnlockingPrompt = false
                    animateCountdownRefresh = false
                }
                print("🎬 Final animation states set:")
                print("🎬 - showNewPromptCard: \(showNewPromptCard)")
                print("🎬 - hasUnlockedNewPrompt: \(hasUnlockedNewPrompt)")
                print("🎬 - isUnlockingPrompt: \(isUnlockingPrompt)")
                print("🎬 - animateCountdownRefresh: \(animateCountdownRefresh)")
                
                print("🎬 Animation sequence completed!")
                print("🎬 ===== END PROMPT UNLOCK ANIMATION SEQUENCE =====")
            }
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topBarView
                mainContentView
            }
            bottomNavigationView
        }
        .background(Color(red: 1, green: 0.989, blue: 0.93))
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showCamera) {
            InFrameCameraView(
                isPresented: $showCamera,
                capturedImage: $capturedImage,
                capturedFrameSize: $capturedFrameSize,
                prompt: currentPrompt
            )
        }
        .fullScreenCover(isPresented: $showSettings) {
            GroupSettingsView(groupStore: groupStore, entryStore: store, group: group, isPresented: $showSettings)
        }
        .sheet(isPresented: $showComments) {
            if let selectedEntry = selectedEntryForComments {
                if #available(iOS 16.0, *) {
                    NavigationView {
                        EntryInteractionView(entryId: selectedEntry.id, entryStore: store)
                            .navigationTitle("Comments")
                            .navigationBarTitleDisplayMode(.inline)
                            .navigationBarItems(
                                trailing: Button("Done") {
                                    showComments = false
                                }
                            )
                    }
                    .presentationDetents([.medium, .large])
                } else {
                    NavigationView {
                        EntryInteractionView(entryId: selectedEntry.id, entryStore: store)
                            .navigationTitle("Comments")
                            .navigationBarTitleDisplayMode(.inline)
                            .navigationBarItems(
                                trailing: Button("Done") {
                                    showComments = false
                                }
                            )
                    }
                }
                }
        }
        .alert(isPresented: $showPermissionAlert) {
            if !isInfluencer {
                Alert(
                    title: Text("Only Today's Influencer Can Post"),
                    message: Text("\(influencer?.name ?? "The current influencer") is today's influencer. You can view and react to their posts, but only they can share new content today."),
                    dismissButton: .default(Text("OK"))
                )
            } else {
                Alert(
                    title: Text("Camera Access Required"),
                    message: Text("Please enable camera access in Settings to take photos."),
                    primaryButton: .default(Text("Settings")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            print("🔍 GroupDetailView onAppear - Group: \(group.name) (ID: \(group.id))")
            print("🔍 🎬 User now actively viewing chat - animations enabled")
            
            // Set active viewing flag immediately
            isActivelyViewingChat = true
            
            // CRITICAL: Reset all modal/sheet states when appearing from notification
            if cameFromNotification {
                print("🔔 🎯 RESETTING ALL MODAL STATES FROM NOTIFICATION")
                showCamera = false
                showSettings = false
                showComments = false
                showPermissionAlert = false
                showError = false
                selectedEntryForComments = nil
                
                // CRITICAL: Also reset feedback states that might appear as sheets
                showPromptCompletedFeedback = false
                showNewPromptUnlockedFeedback = false
                isRefreshing = false
                
                print("🔔 🎯 All modal and feedback states reset")
            }
            
            // Clear refresh indicator after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isRefreshing = false
            }
            
            // Always load/check daily prompt first
            print("🔍 Loading daily prompt...")
            let oldPrompt = currentPrompt
            loadDailyPrompt()
            print("🔍 Loaded prompt: '\(currentPrompt)'")
            
            // Handle notification-triggered unlock flow
            if cameFromNotification && shouldTriggerNotificationUnlock {
                print("🔔 🎯 === HANDLING NOTIFICATION UNLOCK FLOW ===")
                print("🔔 🎯 Came from notification: \(cameFromNotification)")
                print("🔔 🎯 Should trigger unlock: \(shouldTriggerNotificationUnlock)")
                print("🔔 🎯 Notification prompt: '\(notificationPrompt)'")
                print("🔔 🎯 Current user is influencer: \(isInfluencer)")
                
                if isInfluencer {
                    // Check if the current prompt has been completed
                    let hasCompletedCurrentPrompt = store.entries.contains { $0.prompt == currentPrompt }
                    print("🔔 🎯 Has completed current prompt: \(hasCompletedCurrentPrompt)")
                    
                    // DON'T show unlock feedback immediately - wait until after animation starts
                    // showNewPromptUnlockedFeedback = true
                    
                    // Step 1: Auto-scroll to the countdown timer first (increased delay to ensure view is ready)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        print("🔔 🎯 📍 Auto-scrolling to countdown timer...")
                        withAnimation(.easeInOut(duration: 1.0)) {
                            shouldAutoScrollToPrompt = true
                        }
                        
                        // Step 2: After scroll completes, trigger unlock animation with vibration
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            print("🔔 🎯 🎬 TRIGGERING UNLOCK ANIMATION WITH VIBRATION!")
                            
                            // Heavy haptic feedback for notification unlock
                            let unlockFeedback = UIImpactFeedbackGenerator(style: .heavy)
                            unlockFeedback.prepare()
                            unlockFeedback.impactOccurred()
                            
                            // Use notification prompt if available, otherwise current prompt
                            let promptForAnimation = !notificationPrompt.isEmpty ? notificationPrompt : currentPrompt
                            print("🔔 🎯 🎬 Using prompt for animation: '\(promptForAnimation)'")
                            
                            // Trigger the unlock animation
                            triggerPromptUnlockAnimation(newPrompt: promptForAnimation)
                            
                            // ONLY NOW show the unlock feedback banner (after animation has started)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                print("🔔 🎯 📢 Now showing unlock feedback banner")
                                showNewPromptUnlockedFeedback = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                                    showNewPromptUnlockedFeedback = false
                                }
                            }
                            
                            // CRITICAL: Reset notification flags IMMEDIATELY after animation starts
                            // Don't wait too long or nav buttons will remain non-responsive
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                print("🔔 🎯 CLEANING UP NOTIFICATION STATE EARLY FOR NAV RESPONSIVENESS")
                                cameFromNotification = false
                                shouldTriggerNotificationUnlock = false
                                notificationPrompt = ""
                                
                                // Force UI refresh to ensure buttons are responsive
                                DispatchQueue.main.async {
                                    print("🔔 🎯 FORCING UI REFRESH FOR BUTTON RESPONSIVENESS")
                                    // Clear any modal/sheet states that might interfere
                                    showCamera = false
                                    showSettings = false
                                    showComments = false
                                    showPermissionAlert = false
                                    showError = false
                                    selectedEntryForComments = nil
                                }
                            }
                        }
                    }
                } else {
                    print("🔔 🎯 ⚠️ User is not influencer - just scroll to show content")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        shouldAutoScrollToPrompt = true
                    }
                    // Reset notification flags for non-influencers immediately
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        print("🔔 🎯 CLEANING UP NOTIFICATION STATE FOR NON-INFLUENCER")
                        cameFromNotification = false
                        shouldTriggerNotificationUnlock = false
                        notificationPrompt = ""
                    }
                }
            } else {
                // Regular flow (not from notification)
                print("🔍 🎬 Regular onAppear flow (not from notification)")
            
            // Check if we have a new prompt ready for animation when entering the view
            if isInfluencer && hasNewPromptReadyForAnimation {
                print("🔍 🎬 NEW PROMPT READY FOR ANIMATION DETECTED!")
                print("🔍 🎬 Current prompt: '\(currentPrompt)'")
                
                // Store the current prompt before clearing the flag
                let promptForAnimation = currentPrompt
                hasNewPromptReadyForAnimation = false // Clear the flag
                
                // Show the prompt unlock feedback immediately
                showNewPromptUnlockedFeedback = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    showNewPromptUnlockedFeedback = false
                }
                
                    // Auto-scroll FIRST, then trigger animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🔄 Auto-scrolling to new prompt BEFORE animation")
                    shouldAutoScrollToPrompt = true
                    
                    // Then trigger animation after scroll completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        print("🔍 🎬 TRIGGERING UNLOCK ANIMATION NOW!")
                        triggerPromptUnlockAnimation(newPrompt: promptForAnimation)
                    }
                }
            } else if isInfluencer {
                    // Check if prompt changed (standard logic)
                if currentPrompt != oldPrompt && !currentPrompt.isEmpty && !oldPrompt.isEmpty {
                        print("🔍 New prompt detected: '\(currentPrompt)', triggering animation")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        triggerPromptUnlockAnimation(newPrompt: currentPrompt)
                    }
                }
                
                    // Auto-scroll to active prompt for influencers when main view appears
                    let hasCompletedCurrentPrompt = store.entries.contains { $0.prompt == currentPrompt }
                    print("🔄 Auto-scroll check: currentPrompt='\(currentPrompt)', hasCompleted=\(hasCompletedCurrentPrompt)")
                
                if !hasCompletedCurrentPrompt && !currentPrompt.isEmpty {
                        print("🔄 Scheduling auto-scroll to activePrompt in 1.0 seconds")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        print("🔄 Triggering auto-scroll...")
                        shouldAutoScrollToPrompt = true
                    }
                } else {
                    print("🔄 Auto-scroll skipped: prompt completed or empty")
                }
            } else {
                print("🔄 Auto-scroll skipped: not influencer")
                }
            }
            
            // Start the countdown timer
            print("🔍 Starting countdown timer...")
            startCountdownTimer()
            // Update cached influencer status
            print("🔍 Updating influencer status...")
            updateInfluencerStatus()
        }
        .onDisappear {
            print("🔍 GroupDetailView onDisappear - Group: \(group.name) (ID: \(group.id))")
            print("🔍 🎬 User no longer actively viewing chat - animations disabled")
            
            // Stop countdown timer when leaving view
            stopCountdownTimer()
            
            // CRITICAL: Clean up all notification state when leaving view
            if cameFromNotification || shouldTriggerNotificationUnlock {
                print("🔍 🎯 CLEANING UP NOTIFICATION STATE ON DISAPPEAR")
                cameFromNotification = false
                shouldTriggerNotificationUnlock = false
                notificationPrompt = ""
                
                // Reset animation states
                showNewPromptCard = false
                hasUnlockedNewPrompt = false
                isUnlockingPrompt = false
                animateCountdownRefresh = false
                hasTriggeredUnlockForCurrentPrompt = false
                hasNewPromptReadyForAnimation = false
                showPromptCompletedFeedback = false
                showNewPromptUnlockedFeedback = false
                shouldAutoScrollToPrompt = false
            }
            
            // Set active viewing flag to false
            isActivelyViewingChat = false
        }
        .onChange(of: groupStore.groups) { newGroups in
            // Update local group state when GroupStore updates - with safety checks
            print("📱 GroupStore.groups changed, checking for updates...")
            print("📱 Current GroupDetailView group ID: \(group.id)")
            print("📱 Total groups in store: \(newGroups.count)")
            if let updatedGroup = groupStore.getGroup(withId: group.id) {
                print("📱 Found updated group, updating local state...")
                print("📱 Updated group name: \(updatedGroup.name)")
                print("📱 Updated group frequency: \(updatedGroup.promptFrequency)")
                print("📱 Updated group muted: \(updatedGroup.notificationsMuted)")
                // Only update if there are actual changes to prevent unnecessary re-renders
                if updatedGroup != group {
                    print("📱 Group has changes, updating...")
                    group = updatedGroup
                    updateInfluencerStatus()
                } else {
                    print("📱 Group unchanged, skipping update")
                }
            } else {
                print("📱 ⚠️ WARNING: Could not find group with ID \(group.id) in store")
                print("📱 Available group IDs: \(newGroups.map { $0.id })")
            }
        }
        .onChange(of: store.entries) { _ in
            print("⏰ Entries changed, updating countdown")
            updateCountdown()
        }
    }
    
    // MARK: - View Components
    
    private var topBarView: some View {
        VStack(spacing: 0) {
            // Feed update banners
            if isRefreshing {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: isRefreshing)
                    
                    Text("Refreshing latest reactions and comments...")
                        .font(.custom("Fredoka-Medium", size: 14))
                        .foregroundColor(.blue)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            if showPromptCompletedFeedback {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Prompt posted to your DIML feed!")
                        .font(.custom("Fredoka-Medium", size: 14))
                        .foregroundColor(.green)
                    Spacer()
                    Button(action: { showPromptCompletedFeedback = false }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle()) // iOS 18.5 compatibility
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            if showNewPromptUnlockedFeedback {
                HStack {
                    // Animated sparkle icon
                    Image(systemName: "sparkles")
                        .foregroundColor(Color(red: 1.0, green: 0.815, blue: 0.0))
                        .scaleEffect(showNewPromptUnlockedFeedback ? 1.2 : 1.0)
                        .rotationEffect(.degrees(showNewPromptUnlockedFeedback ? 360 : 0))
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false), value: showNewPromptUnlockedFeedback)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("🎉 New Prompt Unlocked!")
                            .font(.custom("Fredoka-Bold", size: 16))
                            .foregroundColor(Color(red: 1.0, green: 0.815, blue: 0.0))
                        
                        Text("Scroll down to share your response!")
                            .font(.custom("Fredoka-Regular", size: 14))
                            .foregroundColor(Color(red: 0.8, green: 0.65, blue: 0.0))
                    }
                    
                    Spacer()
                    
                    Button(action: { showNewPromptUnlockedFeedback = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(red: 1.0, green: 0.815, blue: 0.0))
                            .font(.title3)
                    }
                    .buttonStyle(PlainButtonStyle()) // iOS 18.5 compatibility
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.815, blue: 0.0).opacity(0.15),
                            Color(red: 1.0, green: 0.9, blue: 0.2).opacity(0.15)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.815, blue: 0.0), Color.yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                )
                .cornerRadius(12)
                .padding(.horizontal)
                .scaleEffect(showNewPromptUnlockedFeedback ? 1.02 : 1.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showNewPromptUnlockedFeedback)
                .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale))
            }
            
            // Main top bar
            HStack {
                Button(action: {
                    print("🔴 Back button tapped - sending reset navigation notification")
                    
                    // CRITICAL: Always reset MainTabView navigation state via notification
                    print("🔴 🎯 Sending ResetMainTabNavigation notification")
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ResetMainTabNavigation"),
                        object: nil
                    )
                    
                    // Clean up notification state
                    if cameFromNotification {
                        print("🔴 🎯 Cleaning up notification state")
                        cameFromNotification = false
                        shouldTriggerNotificationUnlock = false
                        notificationPrompt = ""
                    }
                    
                    // Reset all modal states to prevent conflicts
                    showCamera = false
                    showSettings = false
                    showComments = false
                    showPermissionAlert = false
                    showError = false
                    selectedEntryForComments = nil
                    
                    // DON'T use dismiss() - it doesn't work with our navigation setup
                    // The notification will handle returning to GroupListView
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.black)
                }
                .buttonStyle(PlainButtonStyle()) // iOS 18.5 compatibility

                Spacer()

                Image("DIML_Logo")
                    .resizable()
                    .frame(width: 40, height: 40)

                Spacer()

                Button(action: {
                    // Clear notification state before showing settings
                    if cameFromNotification {
                        print("🔴 🎯 Clearing notification state before settings")
                        cameFromNotification = false
                        shouldTriggerNotificationUnlock = false
                        notificationPrompt = ""
                    }
                    showSettings = true
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.black)
                }
                .buttonStyle(PlainButtonStyle()) // iOS 18.5 compatibility
            }
            .padding(.horizontal)
            .padding(.top, 12)
        }
        .animation(.easeInOut(duration: 0.3), value: showPromptCompletedFeedback)
        .animation(.easeInOut(duration: 0.3), value: showNewPromptUnlockedFeedback)
    }

    private var mainContentView: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(spacing: 16) {
                    if isInfluencer {
                        influencerContentView
                    } else {
                        nonInfluencerContentView
                    }
                }
                .padding(.vertical)
                .onChange(of: shouldScrollToResponse) { shouldScroll in
                    if shouldScroll {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo("responseField", anchor: UnitPoint.center)
                        }
                        shouldScrollToResponse = false
                    }
                }
                .onChange(of: shouldAutoScrollToPrompt) { shouldScroll in
                    if shouldScroll {
                        print("🔄 Executing auto-scroll to activePrompt")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 1.0)) {
                                proxy.scrollTo("activePrompt", anchor: .center)
                            }
                        }
                        shouldAutoScrollToPrompt = false
                    }
                }
                .onAppear {
                    print("🔄 ScrollView content appeared")
                }
            }
        }
        .refreshable {
            print("🔄 Pull-to-refresh triggered - force refreshing entries")
            await refreshEntries()
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    hideKeyboard()
                }
        )
        .onAppear {
            // Auto-scroll to active prompt for influencers when main view appears
            print("🔄 Main content view appeared")
            if isInfluencer {
                let hasCompletedCurrentPrompt = store.entries.contains { $0.prompt == currentPrompt }
                print("🔄 Auto-scroll check: isInfluencer=\(isInfluencer), currentPrompt='\(currentPrompt)', hasCompleted=\(hasCompletedCurrentPrompt)")
                
                if !hasCompletedCurrentPrompt && !currentPrompt.isEmpty {
                    print("🔄 Scheduling auto-scroll to activePrompt in 0.8 seconds")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        shouldAutoScrollToPrompt = true
                    }
                } else {
                    print("🔄 Auto-scroll skipped: prompt completed or empty")
                }
            } else {
                print("🔄 Auto-scroll skipped: not influencer")
            }
        }
    }
    
    // Add async refresh function
    private func refreshEntries() async {
        print("🔄 GroupDetailView: Starting async refresh")
        await MainActor.run {
            isRefreshing = true
            store.refreshEntries()
        }
        // Add a small delay to ensure the refresh completes
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        await MainActor.run {
            isRefreshing = false
        }
        print("🔄 GroupDetailView: Refresh completed")
    }
            
    private var bottomNavigationView: some View {
            VStack {
                Spacer()
                BottomNavBar(
                    currentTab: Binding(
                        get: { currentTab },
                        set: { newTab in
                            print("🔴 Bottom nav tab changed to: \(newTab)")
                            
                            // CRITICAL: Clear ALL notification and interference states immediately
                            print("🔴 🎯 CLEARING ALL INTERFERING STATES FOR NAVIGATION")
                            cameFromNotification = false
                            shouldTriggerNotificationUnlock = false
                            notificationPrompt = ""
                            
                            // Also clear animation states that might interfere
                            isUnlockingPrompt = false
                            showNewPromptCard = false
                            hasUnlockedNewPrompt = false
                            animateCountdownRefresh = false
                            showPromptCompletedFeedback = false
                            showNewPromptUnlockedFeedback = false
                            
                            // Clear modal states
                            showCamera = false
                            showSettings = false
                            showComments = false
                            showPermissionAlert = false
                            showError = false
                            selectedEntryForComments = nil
                            
                            if newTab == .camera {
                            checkCameraPermission()
                            } else if newTab == .home {
                                print("🔴 Home tab selected - sending reset navigation notification")
                                // Use notification instead of dismiss()
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("ResetMainTabNavigation"),
                                    object: nil
                                )
                            } else if newTab == .profile {
                                print("🔴 Profile tab selected - sending reset navigation notification")
                                // Use notification instead of dismiss()
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("ResetMainTabNavigation"),
                                    object: nil
                                )
                            }
                            currentTab = newTab
                        }
                    ),
                    onCameraTap: {
                        print("Camera tap triggered")
                        // Clear notification state before camera interaction
                        print("🔴 🎯 Clearing notification state before camera")
                        cameFromNotification = false
                        shouldTriggerNotificationUnlock = false
                        notificationPrompt = ""
                        
                        // Clear animation states
                        isUnlockingPrompt = false
                        showNewPromptCard = false
                        animateCountdownRefresh = false
                        
                        checkCameraPermission()
                    },
                    isInfluencer: isInfluencer,
                    shouldBounceCamera: {
                        // Only bounce if influencer AND current prompt hasn't been completed AND it's an image prompt
                        let hasCompletedCurrentPrompt = store.entries.contains { $0.prompt == currentPrompt }
                        let shouldBounce = isInfluencer && !hasCompletedCurrentPrompt && isImagePrompt
                        print("📷 Camera bounce check: isInfluencer=\(isInfluencer), hasCompleted=\(hasCompletedCurrentPrompt), isImagePrompt=\(isImagePrompt), shouldBounce=\(shouldBounce)")
                        return shouldBounce
                    }()
                )
            }
        }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var influencerContentView: some View {
        VStack(spacing: 16) {
            // Show user's name and pronouns header (always visible)
            VStack(alignment: .leading, spacing: 8) {
                Text("\(currentUser.name)'s DIML")
                    .font(.custom("Fredoka-Regular", size: 24))
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 1.0, green: 0.815, blue: 0.0))
                
                Text("she/her") // This could be made dynamic later
                    .font(.custom("Fredoka-Regular", size: 14))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Show all completed entries first (in chronological order)
            allEntriesView
            
            // Show current prompt area if capturing image
            if let image = capturedImage {
                capturedImageView(image: image)
            }
            
            // The countdown timer view that transforms into the prompt card
            animatedCountdownTimerView
            
            circleMembersView
        }
    }
    
    private var allEntriesView: some View {
        // Sort entries by timestamp (earliest first)
        let sortedEntries = store.entries.sorted { $0.timestamp < $1.timestamp }
        
        return ForEach(Array(sortedEntries.enumerated()), id: \.element.id) { index, entry in
            entryView(entry: entry, entryIndex: index, sortedEntries: sortedEntries)
        }
    }
    
    // Helper function to check if user has reacted to all previous entries
    private func hasReactedToPreviousEntries(upToIndex index: Int, sortedEntries: [DIMLEntry]) -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        
        // Influencer can always see all entries
        if isInfluencer { return true }
        
        // Check if user has reacted to ALL previous entries
        for i in 0..<index {
            let previousEntry = sortedEntries[i]
            let hasReacted = previousEntry.userReactions.contains { $0.userId == currentUserId }
            if !hasReacted {
                return false // User hasn't reacted to this previous entry
            }
        }
        
        return true // User has reacted to all previous entries (or this is the first entry)
    }
    
    // Helper function to check if an entry should be blurred
    private func shouldBlurEntry(entry: DIMLEntry, entryIndex: Int, sortedEntries: [DIMLEntry]) -> Bool {
        guard Auth.auth().currentUser != nil else { return false }
        
        // Influencer can always see all entries
        if isInfluencer { return false }
        
        // Don't blur the first entry (index 0)
        if entryIndex == 0 { return false }
        
        // Blur if user hasn't reacted to all previous entries
        return !hasReactedToPreviousEntries(upToIndex: entryIndex, sortedEntries: sortedEntries)
    }
    
    private var currentPromptAreaView: some View {
        // Use dynamic PromptCard for varied styling
        VStack(spacing: 8) {
            if isUploading {
                // Show loading state when submitting
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Saving your response...")
                        .font(.custom("Fredoka-Medium", size: 16))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(red: 0.95, green: 0.95, blue: 0.95))
                .cornerRadius(16)
                .padding(.horizontal)
            } else {
                // Use the stored configuration to ensure consistency
                if let config = currentPromptConfiguration {
                    PromptCard(configuration: config) { response in
                        print("📝 Prompt response received: \(response)")
                        // Handle the response from the dynamic prompt card
                        handlePromptResponse(response)
                    }
                    .scaleEffect(showNewPromptCard ? 1.05 : 1.0)
                    .opacity(showNewPromptCard ? 1.0 : (store.entries.isEmpty ? 1.0 : 0.8))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showNewPromptCard)
                    .disabled(isUploading) // Disable interaction while uploading
                } else {
                    // Fallback if no configuration
                    Text("Loading prompt...")
                        .font(.custom("Fredoka-Regular", size: 16))
                        .foregroundColor(.gray)
                        .padding()
                }
                
                // Hint about camera option
                if isInfluencer && !isUploading {
                    Text("💡 Tip: You can also use the camera button below to take a photo for any prompt")
                        .font(.custom("Fredoka-Regular", size: 12))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                }
            }
        }
    }
    
    // MARK: - Handle Dynamic Prompt Response
    
    private func handlePromptResponse(_ response: PromptResponse) {
        print("📝 Handling prompt response: \(response)")
        
        // Convert PromptResponse to our existing entry system
        let responseText = response.textResponses.values.joined(separator: " • ")
        
        // Check if we have any meaningful response
        guard !responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
              response.imageURL != nil || 
              response.mood != nil || 
              response.rating != nil else {
            print("📝 No meaningful response provided")
            return
        }
        
        // Start uploading state
        print("📝 Setting isUploading = true")
        isUploading = true
        
        Task {
            do {
                let finalImageURL: String? = response.imageURL
                
                // If there's a mood or rating, include it in the response text
                var finalResponseText = responseText
                if let mood = response.mood {
                    finalResponseText += finalResponseText.isEmpty ? "Mood: \(mood)" : " • Mood: \(mood)"
                }
                if let rating = response.rating {
                    finalResponseText += finalResponseText.isEmpty ? "Rating: \(rating)/5" : " • Rating: \(rating)/5"
                }
                
                print("📝 Creating DIMLEntry...")
                
                // Safety check for currentPrompt
                guard !currentPrompt.isEmpty else {
                    print("📝 ERROR: currentPrompt is empty!")
                    throw NSError(domain: "DIMLError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Current prompt is empty"])
                }
                
                // Create entry
                let entry = DIMLEntry(
                    id: UUID().uuidString,
                    userId: Auth.auth().currentUser?.uid ?? "",
                    prompt: currentPrompt,
                    response: finalResponseText,
                    image: nil,
                    imageURL: finalImageURL,
                    frameSize: FrameSize.random,
                    promptType: .text // Explicitly set as text prompt
                )
                
                print("📝 Created entry for text/form submission")
                print("📝 Entry prompt: '\(entry.prompt)'")
                print("📝 Entry response: '\(entry.response)'")
                
                await MainActor.run {
                    print("📝 Running on MainActor...")
                    // Add entry to store
                    print("📝 About to call store.addEntry...")
                    store.addEntry(entry)
                    print("📝 Entry added to store. Total entries: \(store.entries.count)")
                    
                    // Show completion feedback
                    showPromptCompletedFeedback = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        showPromptCompletedFeedback = false
                    }
                    
                    // Reset states
                    print("📝 Resetting states...")
                    hasInteractedWithCurrentPrompt = false
                    resetAnimationStates()
                    isUploading = false
                    
                    // EntryStore automatically sends upload notifications to OTHER group members
                    // (correctly excludes the person who uploaded)
                    
                    // Schedule notification for when influencer's NEXT prompt unlocks (future)
                    print("📝 ⏭️ About to call scheduleNextPromptNotification after text response")
                    print("📝 ⏭️ Current user ID: \(Auth.auth().currentUser?.uid ?? "nil")")
                    print("📝 ⏭️ isInfluencer: \(isInfluencer)")
                    print("📝 ⏭️ Group muted: \(group.notificationsMuted)")
                    self.scheduleNextPromptNotification()
                    
                    
                    print("📝 Text submission completed successfully")
                }
            } catch {
                print("📝 ERROR in handlePromptResponse: \(error)")
                await MainActor.run {
                    isUploading = false
                    errorMessage = "Failed to save response: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func resetAnimationStates() {
        print("🎬 🔄 resetAnimationStates called")
        print("🎬 🔄 Previous hasNewPromptReadyForAnimation: \(hasNewPromptReadyForAnimation)")
        showNewPromptCard = false
        hasUnlockedNewPrompt = false
        isUnlockingPrompt = false
        animateCountdownRefresh = false
        hasTriggeredUnlockForCurrentPrompt = false // Reset so next timing cycle can trigger
        // DON'T reset hasNewPromptReadyForAnimation here - only clear it when animation actually plays
        // hasNewPromptReadyForAnimation = false // Reset the new animation flag
        showPromptCompletedFeedback = false // Reset feedback states
        showNewPromptUnlockedFeedback = false // Reset feedback states
        print("🎬 🔄 Kept hasNewPromptReadyForAnimation = \(hasNewPromptReadyForAnimation) (not resetting)")
    }
    
    private func scheduleNextPromptNotification() {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              isInfluencer,
              !group.notificationsMuted else {
            print("📱 ⏭️ Skipping notification scheduling:")
            print("📱 ⏭️ - currentUserId: \(Auth.auth().currentUser?.uid ?? "nil")")
            print("📱 ⏭️ - isInfluencer: \(isInfluencer)")
            print("📱 ⏭️ - notificationsMuted: \(group.notificationsMuted)")
            return
        }
        
        guard let nextPromptTime = calculateNextPromptTime() else {
            print("📱 ⏭️ No next prompt time calculated, cannot schedule notification")
            return
        }
        
        let now = Date()
        let timeInterval = nextPromptTime.timeIntervalSince(now)
        
        print("📱 ⏭️ === SCHEDULING LOCAL PROMPT UNLOCK NOTIFICATION ===")
        print("📱 ⏭️ Current time: \(now)")
        print("📱 ⏭️ Next prompt unlock time: \(nextPromptTime)")
        print("📱 ⏭️ Time interval: \(timeInterval) seconds (\(timeInterval/3600) hours)")
        print("📱 ⏭️ Group frequency: \(group.promptFrequency)")
        
        // Only schedule if it's in the future
        guard timeInterval > 0 else {
            print("📱 ⏭️ ⚠️ Next prompt time is in the past, not scheduling notification")
            return
        }
        
        // Cancel existing prompt unlock notifications to prevent duplicates
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let existingPromptNotifications = requests.filter { 
                $0.identifier.contains("prompt_unlocked")
            }
            
            if !existingPromptNotifications.isEmpty {
                let identifiersToRemove = existingPromptNotifications.map { $0.identifier }
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
                print("📱 ⏭️ 🗑️ Cancelled \(identifiersToRemove.count) existing prompt unlock notifications")
                for identifier in identifiersToRemove {
                    print("📱 ⏭️ 🗑️ Removed: \(identifier)")
                }
            }
            
            // Generate the next prompt text that will be unlocked
            print("📱 ⏭️ 🎯 Generating next prompt text for notification...")
            let nextPromptText = self.getCurrentPrompt() // This will generate the next prompt
            print("📱 ⏭️ 🎯 Next prompt text: '\(nextPromptText)'")
            
            // Schedule LOCAL notification for delivery when prompt unlocks
            let content = UNMutableNotificationContent()
            content.title = "🎉 New Prompt Unlocked!"
            content.body = nextPromptText.isEmpty ? "Your next DIML prompt is ready to answer!" : nextPromptText
            content.sound = .default
            content.badge = 1
            
            // Enhanced metadata for better notification handling
            content.userInfo = [
                "type": "prompt_unlock",
                "groupId": self.group.id,
                "groupName": self.group.name,
                "userId": currentUserId,
                "prompt": nextPromptText,
                "promptFrequency": self.group.promptFrequency.rawValue,
                "unlockTime": nextPromptTime.timeIntervalSince1970
            ]
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
            let identifier = "prompt_unlocked_local_\(currentUserId)_\(self.group.id)_\(nextPromptTime.timeIntervalSince1970)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            print("📱 ⏭️ 🔧 DETAILED NOTIFICATION DEBUG:")
            print("📱 ⏭️ 🔧 Title: '\(content.title)'")
            print("📱 ⏭️ 🔧 Body: '\(content.body)'")
            print("📱 ⏭️ 🔧 Identifier: '\(identifier)'")
            print("📱 ⏭️ 🔧 Time interval: \(timeInterval) seconds")
            print("📱 ⏭️ 🔧 Will fire at: \(nextPromptTime)")
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("📱 ⏭️ ❌ Error scheduling local prompt unlock notification: \(error)")
                    print("📱 ⏭️ ❌ Full error details: \(error.localizedDescription)")
                } else {
                    print("📱 ⏭️ ✅ Successfully scheduled LOCAL prompt unlock notification")
                    print("📱 ⏭️ ✅ Will fire in \(Int(timeInterval)) seconds at \(nextPromptTime)")
                    print("📱 ⏭️ ✅ Notification will show: '\(nextPromptText)'")
                    print("📱 ⏭️ ✅ Works when app is backgrounded (but not when completely terminated)")
                    print("📱 ⏭️ ✅ Notification ID: \(identifier)")
                    
                    // VERIFY: Double-check that notification was actually scheduled
                    UNUserNotificationCenter.current().getPendingNotificationRequests { verifyRequests in
                        let justScheduled = verifyRequests.filter { $0.identifier == identifier }
                        if justScheduled.isEmpty {
                            print("📱 ⏭️ ❌ CRITICAL: Notification was NOT found in pending queue after scheduling!")
                        } else {
                            print("📱 ⏭️ ✅ VERIFIED: Notification is confirmed in pending queue")
                            if let trigger = justScheduled.first?.trigger as? UNTimeIntervalNotificationTrigger {
                                print("📱 ⏭️ ✅ VERIFIED: Will fire at \(trigger.nextTriggerDate() ?? Date())")
                            }
                        }
                        
                        // Show total pending notifications
                        print("📱 ⏭️ 📊 Total pending notifications: \(verifyRequests.count)")
                        for request in verifyRequests {
                            print("📱 ⏭️ 📊 - Pending: \(request.identifier)")
                        }
                    }
                }
            }
        }
    }
    
    // Clean up function for account switching
    private func clearAllPendingNotifications() {
        print("📱 🧹 === CLEARING ALL PENDING LOCAL NOTIFICATIONS ===")
        print("📱 🧹 This prevents duplicate notifications when switching user accounts")
        
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let allNotificationIds = requests.map { $0.identifier }
            
            if !allNotificationIds.isEmpty {
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                print("📱 🧹 ✅ Cleared \(allNotificationIds.count) pending local notifications")
                for identifier in allNotificationIds {
                    print("📱 🧹 🗑️ Cleared: \(identifier)")
                }
            } else {
                print("📱 🧹 ℹ️ No pending notifications to clear")
            }
        }
    }
    
    // MARK: - Testing Functions
    
    private func testNotificationSystem() {
        print("🧪 === TESTING NOTIFICATION SYSTEM ===")
        
        // First check notification permissions
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                print("🧪 📱 === NOTIFICATION PERMISSION STATUS ===")
                print("🧪 📱 Authorization Status: \(settings.authorizationStatus.rawValue)")
                print("🧪 📱 Alert Setting: \(settings.alertSetting.rawValue)")
                print("🧪 📱 Badge Setting: \(settings.badgeSetting.rawValue)")
                print("🧪 📱 Sound Setting: \(settings.soundSetting.rawValue)")
                print("🧪 📱 Lock Screen Setting: \(settings.lockScreenSetting.rawValue)")
                print("🧪 📱 Notification Center Setting: \(settings.notificationCenterSetting.rawValue)")
                
                switch settings.authorizationStatus {
                case .authorized:
                    print("🧪 📱 ✅ Notifications are AUTHORIZED - proceeding with test")
                    self.testLocalNotification()
                    self.testFCMPushNotification()
                case .denied:
                    print("🧪 📱 ❌ Notifications are DENIED - user needs to enable in Settings")
                case .notDetermined:
                    print("🧪 📱 ⚠️ Notifications not determined - requesting permission")
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                        if granted {
                            print("🧪 📱 ✅ Permission granted - trying test again")
                            DispatchQueue.main.async {
                                self.testLocalNotification()
                                self.testFCMPushNotification()
                            }
                        } else {
                            print("🧪 📱 ❌ Permission denied: \(error?.localizedDescription ?? "unknown")")
                        }
                    }
                case .provisional:
                    print("🧪 📱 ⚠️ Provisional authorization - proceeding with test")
                    self.testLocalNotification()
                    self.testFCMPushNotification()
                case .ephemeral:
                    print("🧪 📱 ⚠️ Ephemeral authorization - proceeding with test")
                    self.testLocalNotification()
                    self.testFCMPushNotification()
                @unknown default:
                    print("🧪 📱 ❓ Unknown authorization status")
                    self.testLocalNotification()
                    self.testFCMPushNotification()
                }
            }
        }
    }
    
    private func testLocalNotification() {
        print("🧪 📱 Testing LOCAL notification...")
        
        // Check how many pending notifications we have
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("🧪 📱 Current pending notifications: \(requests.count)")
            for request in requests {
                print("🧪 📱 - Pending: \(request.identifier)")
            }
        }
        
        let content = UNMutableNotificationContent()
        content.title = "🧪 Test Notification"
        content.body = "If you see this, notifications work! Tap to open app."
        content.sound = .default
        content.badge = NSNumber(value: 1)
        content.userInfo = [
            "type": "test_local",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Schedule for 3 seconds from now (shorter delay for testing)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3.0, repeats: false)
        let identifier = "test_local_\(Int(Date().timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🧪 📱 ❌ Local notification test failed: \(error.localizedDescription)")
                print("🧪 📱 ❌ Full error: \(error)")
            } else {
                print("🧪 📱 ✅ Local notification scheduled successfully!")
                print("🧪 📱 ✅ Identifier: \(identifier)")
                print("🧪 📱 ✅ Will fire in 3 seconds")
                print("🧪 📱 💡 NOW: Press home button to background the app!")
                print("🧪 📱 💡 You should see notification in 3 seconds")
                
                // Verify it was actually scheduled
                UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                    let testRequests = requests.filter { $0.identifier == identifier }
                    if testRequests.isEmpty {
                        print("🧪 📱 ❌ WARNING: Notification was NOT actually scheduled!")
                    } else {
                        print("🧪 📱 ✅ Verified: Notification is in pending queue")
                    }
                }
            }
        }
    }
    
    private func testFCMPushNotification() {
        print("🧪 🚀 Testing FCM PUSH notification...")
        
        guard Auth.auth().currentUser != nil else {
            print("🧪 🚀 ❌ No authenticated user for FCM test")
            return
        }
        
        // Send a test push notification via Firebase Functions (if you have them set up)
        // For now, we'll just verify FCM token is available
        Messaging.messaging().token { token, error in
            if let error = error {
                print("🧪 🚀 ❌ FCM token error: \(error)")
            } else if let token = token {
                print("🧪 🚀 ✅ FCM token available: \(String(token.suffix(8)))")
                print("🧪 🚀 💡 FCM push notifications should work when app is completely terminated!")
                print("🧪 🚀 💡 You can test this by completely closing the app and triggering a notification")
            } else {
                print("🧪 🚀 ⚠️ No FCM token available")
            }
        }
    }
    
    private var nonInfluencerContentView: some View {
        VStack(spacing: 16) {
            // Show influencer's name header
            VStack(alignment: .leading, spacing: 8) {
                Text("\(influencer?.name ?? "Today's Influencer")'s DIML")
                    .font(.custom("Fredoka-Regular", size: 24))
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 1.0, green: 0.815, blue: 0.0))
                
                Text("she/her · Today's Influencer") // This could be made dynamic later
                    .font(.custom("Fredoka-Regular", size: 14))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            influencerEntryView
            circleMembersView
        }
    }
    
    private func capturedImageView(image: UIImage) -> some View {
        VStack(spacing: 0) {
            // Prompt box with image inside
            VStack(alignment: .leading, spacing: 0) {
                // Prompt text at the top
                VStack(alignment: .leading, spacing: 6) {
                    Text(currentPrompt)
                        .font(.custom("Fredoka-Medium", size: 16))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // Image in the middle
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: capturedFrameSize.height)
                    .cornerRadius(12)
                    .clipped()
                    .padding(.horizontal, 16)
                
                // Response text field at the bottom
                VStack(alignment: .leading, spacing: 6) {
                    Text("Add your response...")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if #available(iOS 16.0, *) {
                        TextField("e.g., corepower w/ eliza", text: $responseText, axis: .vertical)
                            .font(.custom("Fredoka-Regular", size: 16))
                            .textFieldStyle(PlainTextFieldStyle())
                            .frame(minHeight: 40)
                            .submitLabel(.done)
                            .focused($isResponseFieldFocused)
                            .onSubmit {
                                hideKeyboard()
                            }
                            .onTapGesture {
                                isResponseFieldFocused = true
                                shouldScrollToResponse = true
                            }
                    } else {
                        TextEditor(text: $responseText)
                            .font(.custom("Fredoka-Regular", size: 16))
                            .frame(minHeight: 60)
                            .onTapGesture {
                                isResponseFieldFocused = true
                                shouldScrollToResponse = true
                            }
                    }
                }
                .id("responseField")
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .background(Color(red: 1.0, green: 0.95, blue: 0.80))
            .cornerRadius(15)
            .padding(.horizontal)
            
            // Action Buttons outside the frame
            HStack(spacing: 16) {
                Button(action: {
                    print("🔥 Share button tapped")
                    
                    // Add immediate haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    guard let image = capturedImage else {
                        print("🔥 ERROR: No captured image available")
                        errorMessage = "No image to upload. Please take a photo first."
                        showError = true
                        return
                    }
                    
                    guard !isUploading else {
                        print("🔥 Already uploading, ignoring button tap")
                        return
                    }
                    
                    print("🔥 Starting upload for captured image")
                    uploadImage(image)
                }) {
                    HStack(spacing: 6) {
                        if isUploading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14))
                        }
                        
                        Text(isUploading ? "Uploading..." : "Share")
                            .font(.custom("Fredoka-Regular", size: 16))
                    }
                    .foregroundColor(isUploading ? .gray : .blue)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(isUploading ? Color.gray.opacity(0.1) : Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .contentShape(Rectangle()) // Ensure entire area is tappable
                }
                .buttonStyle(PlainButtonStyle()) // Fix grey background on iOS 18.5
                .disabled(isUploading)
                .opacity(isUploading ? 0.6 : 1.0)
            
                Button(action: {
                    print("🔥 Retake button tapped")
                    
                    // Add haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
                    capturedImage = nil 
                    responseText = "" // Also clear response text
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.rotate")
                            .font(.system(size: 14))
                        Text("Retake")
                            .font(.custom("Fredoka-Regular", size: 16))
                    }
                    .foregroundColor(.red)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .contentShape(Rectangle()) // Ensure entire area is tappable
                }
                .buttonStyle(PlainButtonStyle()) // Fix grey background on iOS 18.5
                .disabled(isUploading)
                .opacity(isUploading ? 0.6 : 1.0)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
    }
    
    private var animatedCountdownTimerView: some View {
        VStack(spacing: 16) {
            let hasCompletedCurrentPrompt = store.entries.contains { $0.prompt == currentPrompt }
            let isInitialPrompt = store.entries.isEmpty
            
            // CORRECTED LOGIC: Show prompt card when:
            // 1. No entries yet (very first prompt)
            // 2. During unlock animation 
            // 3. After unlock animation is complete (showNewPromptCard = true)
            // 4. Current prompt hasn't been completed yet (active prompt state)
            let shouldShowPromptCard = isInitialPrompt || 
                                     isUnlockingPrompt || 
                                     showNewPromptCard ||
                                     !hasCompletedCurrentPrompt
            
            if shouldShowPromptCard {
                // Show the prompt card with enhanced unlock animation
                if let config = currentPromptConfiguration {
                    PromptCard(configuration: config) { response in
                        handlePromptResponse(response)
                    }
                    .scaleEffect(showNewPromptCard ? 1.05 : (isInitialPrompt ? 1.0 : 0.95))
                    .opacity(showNewPromptCard ? 1.0 : (isInitialPrompt ? 1.0 : 0.8))
                    .rotation3DEffect(
                        .degrees(isUnlockingPrompt ? 5 : 0),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .animation(.spring(response: 1.0, dampingFraction: 0.5), value: showNewPromptCard)
                    .animation(.spring(response: 0.6, dampingFraction: 0.5), value: isUnlockingPrompt)
                    .transition(.scale.combined(with: .opacity))
                    .overlay(
                        // Sparkle effect when unlocking
                        showNewPromptCard ? AnyView(
                            ZStack {
                                ForEach(0..<8, id: \.self) { index in
                                    Image(systemName: "sparkle")
                                        .foregroundColor(.yellow)
                                        .scaleEffect(0.5)
                                        .offset(
                                            x: cos(Double(index) * .pi / 4) * 60,
                                            y: sin(Double(index) * .pi / 4) * 60
                                        )
                                        .opacity(showNewPromptCard ? 1.0 : 0.0)
                                        .animation(
                                            .easeOut(duration: 1.5)
                                            .delay(Double(index) * 0.1),
                                            value: showNewPromptCard
                                        )
                                }
                            }
                        ) : AnyView(EmptyView())
                    )
                } else {
                    Text("Loading prompt...")
                        .font(.custom("Fredoka-Regular", size: 16))
                        .foregroundColor(.gray)
                        .padding()
                }
            } else if hasCompletedCurrentPrompt && !isInitialPrompt {
                // COUNTDOWN TIMER: Only show after prompt has been completed
                // This replaces the prompt card when user has uploaded their response
                HStack {
                    // Enhanced animated lock icon with more dramatic effects
                    ZStack {
                        // Glow effect when animating
                        if animateCountdownRefresh {
                            Circle()
                                .fill(Color.yellow.opacity(0.3))
                                .frame(width: 40, height: 40)
                                .scaleEffect(animateCountdownRefresh ? 1.5 : 1.0)
                                .opacity(animateCountdownRefresh ? 0.0 : 1.0)
                                .animation(.easeOut(duration: 0.8), value: animateCountdownRefresh)
                        }
                        
                        Image(systemName: isUnlockingPrompt ? "lock.open.fill" : "lock.fill")
                            .foregroundColor(isUnlockingPrompt ? .green : .gray)
                            .font(.title2)
                            .rotationEffect(.degrees(animateCountdownRefresh ? 360 : 0))
                            .scaleEffect(animateCountdownRefresh ? 1.2 : 1.0)
                            .rotation3DEffect(
                                .degrees(isUnlockingPrompt ? 180 : 0),
                                axis: (x: 0, y: 1, z: 0)
                            )
                            .animation(.easeInOut(duration: 0.8), value: animateCountdownRefresh)
                            .animation(.spring(response: 0.6, dampingFraction: 0.5), value: isUnlockingPrompt)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next Prompt Unlocking in...")
                            .font(.custom("Fredoka-Regular", size: 14))
                            .foregroundColor(.gray)
                        
                        if nextPromptCountdown == "New prompt available!" {
                            Text("Ready to unlock!")
                                .font(.custom("Fredoka-Medium", size: 16))
                                .foregroundColor(.green)
                                .scaleEffect(animateCountdownRefresh ? 1.1 : 1.0)
                                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: animateCountdownRefresh)
                        } else if !nextPromptCountdown.isEmpty {
                            Text(nextPromptCountdown)
                                .font(.custom("Fredoka-Medium", size: 16))
                                .foregroundColor(.black)
                        } else {
                            Text("Calculating...")
                                .font(.custom("Fredoka-Medium", size: 16))
                                .foregroundColor(.gray)
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isUnlockingPrompt ? 
                              LinearGradient(
                                colors: [Color.green.opacity(0.2), Color.yellow.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              ) :
                              LinearGradient(
                                colors: [Color(red: 1.0, green: 0.95, blue: 0.80)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    animateCountdownRefresh ? 
                                    LinearGradient(
                                        colors: [Color.green, Color.yellow],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) : 
                                    LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom),
                                    lineWidth: animateCountdownRefresh ? 3 : 0
                                )
                                .animation(.easeInOut(duration: 0.3), value: animateCountdownRefresh)
                        )
                )
                .scaleEffect(animateCountdownRefresh ? 1.03 : 1.0)
                .rotation3DEffect(
                    .degrees(isUnlockingPrompt ? 5 : 0),
                    axis: (x: 1, y: 0, z: 0)
                )
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: animateCountdownRefresh)
                .animation(.spring(response: 0.6, dampingFraction: 0.5), value: isUnlockingPrompt)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal)
        .id("activePrompt") // This is where auto-scroll will target
        .onAppear {
            print("🎬 animatedCountdownTimerView appeared")
            print("🎬 - store.entries.isEmpty: \(store.entries.isEmpty)")
            print("🎬 - isUnlockingPrompt: \(isUnlockingPrompt)")
            print("🎬 - showNewPromptCard: \(showNewPromptCard)")
            print("🎬 - currentPrompt: '\(currentPrompt)'")
            print("🎬 - currentPromptConfiguration: \(currentPromptConfiguration != nil)")
        }
    }
    
    private var circleMembersView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Circle Members")
                .font(.custom("Fredoka-Medium", size: 18))
                .foregroundColor(.black)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(group.members) { member in
                        VStack(spacing: 8) {
                            Circle()
                                .fill(member.id == group.currentInfluencerId ? 
                                      Color(red: 1.0, green: 0.815, blue: 0.0) : 
                                      getPlaceholderColor(for: member.id))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Text(member.name.prefix(1).uppercased())
                                        .font(.custom("Fredoka-Medium", size: 20))
                                        .foregroundColor(.white)
                                )
                            
                            Text(member.name)
                                .font(.custom("Fredoka-Regular", size: 12))
                                .foregroundColor(.black)
                                .lineLimit(1)
                            
                            if member.id == group.currentInfluencerId {
                                Text("Today's ✨")
                                    .font(.custom("Fredoka-Regular", size: 10))
                                    .foregroundColor(Color(red: 1.0, green: 0.815, blue: 0.0))
                            }
                        }
                        .frame(width: 70)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }
    
    // Helper function to get consistent placeholder colors
    private func getPlaceholderColor(for userId: String) -> Color {
        return Color.gray.opacity(0.3) // Consistent light grey for all users
    }
    
    private var influencerEntryView: some View {
        // Get all entries by the influencer, sorted by timestamp (earliest first)
        let influencerEntries = store.entries
            .filter { $0.userId == group.currentInfluencerId }
            .sorted { $0.timestamp < $1.timestamp }
        
        print("🔍 influencerEntryView: Looking for influencer entries")
        print("🔍 Total entries in store: \(store.entries.count)")
        print("🔍 Current influencer ID: \(group.currentInfluencerId)")
        print("🔍 Entries by influencer: \(influencerEntries.count)")
        
        if !influencerEntries.isEmpty {
            // Show all influencer entries with progressive unlock
            return AnyView(
                VStack(spacing: 16) {
                    ForEach(Array(influencerEntries.enumerated()), id: \.element.id) { index, entry in
                        influencerEntryCard(entry: entry, entryIndex: index, sortedEntries: influencerEntries)
                    }
                }
            )
        } else {
            // Influencer hasn't posted yet - show waiting message
            return AnyView(
                VStack(spacing: 16) {
                    Image(systemName: "clock")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.gray)

                    VStack(spacing: 8) {
                        Text("Waiting for today's DIML")
                            .font(.custom("Fredoka-Medium", size: 18))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                        
                        Text("\(influencer?.name ?? "The influencer") hasn't shared today's prompt yet. Check back soon!")
                            .font(.custom("Fredoka-Regular", size: 14))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)
        }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(red: 0.95, green: 0.95, blue: 0.95))
                .cornerRadius(16)
                .padding(.horizontal)
            )
        }
    }
    
    // Helper function to display individual influencer entry cards with progressive unlock
    private func influencerEntryCard(entry: DIMLEntry, entryIndex: Int, sortedEntries: [DIMLEntry]) -> some View {
        let isBlurred = shouldBlurEntry(entry: entry, entryIndex: entryIndex, sortedEntries: sortedEntries)
        
        return VStack(alignment: .leading, spacing: 0) {
                    // Prompt text at the top
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.prompt)
                            .font(.custom("Fredoka-Medium", size: 16))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    // Image in the middle
                    if let imageURL = entry.imageURL {
                        AsyncImage(url: URL(string: imageURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: entry.frameSize.height)
                                    .cornerRadius(12)
                                    .clipped()
                    case .failure(_):
                                VStack {
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                    Text("Failed to load image")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .frame(height: entry.frameSize.height)
                            case .empty:
                                ProgressView()
                                    .frame(height: entry.frameSize.height)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Response text at the bottom
                    if !entry.response.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.response)
                                .font(.custom("Fredoka-Regular", size: 16))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                    }
                }
                .background(Color(red: 1.0, green: 0.95, blue: 0.80))
                .cornerRadius(15)
                .padding(.horizontal)
        .opacity(isBlurred ? 0.3 : 1.0) // Apply blur opacity
        .blur(radius: isBlurred ? 8 : 0) // Apply blur effect
                .overlay(
            ZStack {
                if isBlurred {
                    // Lock overlay for blurred entries
                    VStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.gray)
                        
                        Text("React to unlock")
                            .font(.custom("Fredoka-Medium", size: 14))
                            .foregroundColor(.gray)
                        
                        Text("React to the previous post to see this one")
                            .font(.custom("Fredoka-Regular", size: 12))
                            .foregroundColor(.gray.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                } else {
                    // Reaction button positioned in bottom right corner (only for unlocked entries)
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ReactionButton(entryId: entry.id, entryStore: store, groupMembers: group.members)
                                .padding(.trailing, 20)
                                .padding(.bottom, 20)
                        }
                    }
                }
            }
        )
        .disabled(isBlurred) // Disable interaction for locked entries
    }
    
    private func entryView(entry: DIMLEntry, entryIndex: Int, sortedEntries: [DIMLEntry]) -> some View {
        // Create the same configuration that would have been used for this entry
        let entryConfiguration = getEntryConfigurationMatchingPrompt(for: entry)
        let isBlurred = shouldBlurEntry(entry: entry, entryIndex: entryIndex, sortedEntries: sortedEntries)
        
        // Display completed entry using the same PromptCard styling with reaction button
        return PromptCard(
            configuration: entryConfiguration,
            onComplete: nil // No completion handler for completed entries
        )
        .opacity(isBlurred ? 0.3 : 0.9) // More dramatic opacity for locked entries
        .blur(radius: isBlurred ? 8 : 0) // Add blur effect for locked entries
        .overlay(
            ZStack {
                if isBlurred {
                    // Lock overlay for blurred entries
                    VStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.gray)
                        
                        Text("React to unlock")
                            .font(.custom("Fredoka-Medium", size: 14))
                            .foregroundColor(.gray)
                        
                        Text("React to the previous post to see this one")
                            .font(.custom("Fredoka-Regular", size: 12))
                            .foregroundColor(.gray.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                } else {
                    // Add reaction button positioned in bottom right corner (only for unlocked entries)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ReactionButton(entryId: entry.id, entryStore: store, groupMembers: group.members)
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                        }
                    }
                }
            }
        )
        .disabled(isBlurred) // Disable interaction for locked entries
    }
    
    private func getEntryConfigurationMatchingPrompt(for entry: DIMLEntry) -> PromptConfiguration {
        // Use the actual promptType stored in the entry instead of calculating based on position
        if entry.promptType == .image {
            // This was an image prompt - show with date bubble only if it was the first entry
            let sortedEntries = store.entries.sorted { $0.timestamp < $1.timestamp }
            let entryIndex = sortedEntries.firstIndex(where: { $0.id == entry.id }) ?? 0
            
            return PromptConfiguration(
                prompt: entry.prompt,
                fields: entry.imageURL != nil ? [] : [
                    // Only show response text if there's no image
                    PromptField(title: "", placeholder: entry.response, type: .text, isRequired: false)
                ],
                backgroundColor: "blue", // Main blue
                dateLabel: entryIndex == 0 ? getEntryDateLabel(for: entry) : nil,
                imageURL: entry.imageURL, // Pass the image URL to display
                frameSize: entry.frameSize
            )
        } else {
            // This was a text prompt - determine which type based on chronological position
            let sortedEntries = store.entries.sorted { $0.timestamp < $1.timestamp }
            let entryIndex = sortedEntries.firstIndex(where: { $0.id == entry.id }) ?? 0
            let textPromptType = entryIndex % 3
            
            if textPromptType == 1 {
                // Type 1: Simple text prompt
                return PromptConfiguration(
                    prompt: entry.prompt,
                    fields: [
                        PromptField(title: "", placeholder: entry.response, type: .text, isRequired: false)
                    ],
                    backgroundColor: "cream" // Main yellow (low opacity)
                )
            } else if textPromptType == 2 {
                // Type 2: Date + Location bubble cards
                // Parse the response to extract mood and main response if possible
                let responseParts = entry.response.components(separatedBy: " • ")
                let moodResponse = responseParts.count > 1 ? responseParts[0] : ""
                let mainResponse = responseParts.count > 1 ? responseParts[1] : entry.response
                
                return PromptConfiguration(
                    prompt: entry.prompt,
                    fields: [
                        PromptField(title: "current mood", placeholder: moodResponse, type: .text),
                        PromptField(title: "what's happening", placeholder: mainResponse, type: .text)
                    ],
                    backgroundColor: "green", // Grey (very low opacity)
                    dateLabel: getEntryDateLabel(for: entry),
                    locationLabel: getEntryLocationLabel(for: entry)
                )
            } else {
                // Type 3: Energy/mood selection cards
                return PromptConfiguration(
                    prompt: entry.prompt,
                    fields: [
                        PromptField(title: "Response", placeholder: entry.response, type: .text, isRequired: false)
                    ],
                    backgroundColor: "pink", // Main yellow (medium opacity)
                    dateLabel: getEntryDateLabel(for: entry)
                )
            }
        }
    }
    
    private func getEntryDateLabel(for entry: DIMLEntry) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        // Only show date labels for some entries
        return entry.id.hashValue % 3 == 0 ? formatter.string(from: entry.timestamp) : nil
    }
    
    private func getEntryLocationLabel(for entry: DIMLEntry) -> String? {
        let locations = ["Campus", "Home", "Coffee Shop", "Library", "Gym"]
        let entryHash = entry.id.hashValue
        // Only show location labels for some entries
        return entryHash % 4 == 0 ? locations[abs(entryHash) % locations.count] : nil
    }

    // MARK: - Helper Methods
    
    // MARK: - Generate Unique Prompt Helper
    
    private func generateUniquePrompt() -> String {
        print("🎯 generateUniquePrompt called")
        let completedCount = store.entries.count
        
        // Enhanced unique prompt generation with multiple fallback strategies
        var uniquePrompt: String = ""
        var attempts = 0
        let maxAttempts = 100
        
        // Strategy 1: Try different time-based seeds
        while attempts < maxAttempts && (uniquePrompt.isEmpty || uniquePrompt == currentPrompt) {
            let timeOfDay = TimeOfDay.current()
            let calendar = Calendar.current
            let today = Date()
            let baseDailySeed = calendar.component(.year, from: today) * 1000 + (calendar.ordinality(of: .day, in: .year, for: today) ?? 1)
        
            // Use multiple seed variations including attempt number and timestamp
            let timestamp = Int(Date().timeIntervalSince1970)
            let variationSeed = UInt64(abs(baseDailySeed)) + 
                               UInt64(attempts * 12345) + 
                               UInt64(completedCount * 6789) +
                               UInt64(abs(group.id.hashValue)) +
                               UInt64(timestamp % 10000) // Add timestamp variation
            
            var generator = SeededRandomNumberGenerator(seed: variationSeed)
            if let generatedPrompt = promptManager.getSeededPrompt(for: timeOfDay, using: &generator) {
                uniquePrompt = generatedPrompt
            }
            attempts += 1
            print("🎯 Attempt \(attempts): Generated '\(uniquePrompt)'")
        }
        
        // Strategy 2: If still no unique prompt, use curated fallbacks
        if uniquePrompt.isEmpty || uniquePrompt == currentPrompt {
            let curatedPrompts = [
                "What's the highlight of your day so far?",
                "Show us what you're up to right now",
                "What's bringing you joy today?",
                "Share a moment from your current adventure",
                "What's your vibe right now?",
                "Show us your perspective on today",
                "What's happening in your world?",
                "Share something that made you smile recently",
                "What's your current energy like?",
                "Show us what's inspiring you today"
            ]
            
            // Use completion count to cycle through curated prompts
            uniquePrompt = curatedPrompts[completedCount % curatedPrompts.count]
            print("🎯 Using curated prompt: '\(uniquePrompt)'")
        }
        
        print("🎯 Final unique prompt: '\(uniquePrompt)'")
        return uniquePrompt
    }
    
    // MARK: - Notification Methods
    
    private func sendImmediatePromptUnlockNotification(prompt: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              isInfluencer else {
            print("📱 Skipping immediate prompt unlock notification: not influencer")
            return
        }
        
        print("📱 🚀 Sending immediate prompt unlock notification")
        
        let content = UNMutableNotificationContent()
        content.title = "🎉 New Prompt Unlocked!"
        content.body = prompt
        content.sound = .default
        content.badge = 1
        
        // Enhanced metadata
        content.userInfo = [
            "type": "prompt_unlocked_immediate",
            "groupId": group.id,
            "groupName": group.name,
            "userId": currentUserId,
            "prompt": prompt,
            "unlockTime": Date().timeIntervalSince1970
        ]
        
        // Send immediately with a 1 second delay
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        
        let identifier = "prompt_unlocked_immediate_\(currentUserId)_\(group.id)_\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("📱 🚀 ❌ Error sending immediate prompt unlock notification: \(error)")
            } else {
                print("📱 🚀 ✅ Successfully sent immediate prompt unlock notification")
            }
        }
    }
}

// MARK: - Debug and Testing Methods
extension GroupDetailView {
    
    // Test notification methods removed for cleaner code
    
}

// MARK: - Preview
struct GroupDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let mockMembers = [
            User(id: "1", name: "Rebecca"),
            User(id: "2", name: "Taylor")
        ]

        let mockGroup = Group(
            id: "g1",
            name: "Test Group",
            members: mockMembers,
            currentInfluencerId: "1",
            date: Date(),
            promptFrequency: .sixHours,
            notificationsMuted: false
        )

        GroupDetailView(
            group: mockGroup,
            groupStore: GroupStore()
        )
    }
}

// Wrapper view that fetches group by ID to prevent recreation issues
struct GroupDetailViewWrapper: View {
    let groupId: String
    @ObservedObject var groupStore: GroupStore
    let shouldTriggerUnlock: Bool
    let notificationUserInfo: [String: Any]
    
    // Default initializer for existing usage
    init(groupId: String, groupStore: GroupStore) {
        self.groupId = groupId
        self.groupStore = groupStore
        self.shouldTriggerUnlock = false
        self.notificationUserInfo = [:]
    }
    
    // New initializer for notification handling
    init(groupId: String, groupStore: GroupStore, shouldTriggerUnlock: Bool, notificationUserInfo: [String: Any]) {
        self.groupId = groupId
        self.groupStore = groupStore
        self.shouldTriggerUnlock = shouldTriggerUnlock
        self.notificationUserInfo = notificationUserInfo
    }
    
    var body: some View {
        if let group = groupStore.getGroup(withId: groupId) {
            GroupDetailView(
                group: group, 
                groupStore: groupStore,
                shouldTriggerUnlock: shouldTriggerUnlock,
                notificationUserInfo: notificationUserInfo
            )
        } else {
            // Group not found - show error or navigate back
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                
                Text("Group not found")
                    .font(.title2)
                    .foregroundColor(.gray)
                
                Text("This group may have been deleted or you may no longer be a member.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Go Back") {
                    print("🔴 Group not found - sending reset navigation notification")
                    // Send reset navigation notification to return to main tab view
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ResetMainTabNavigation"),
                        object: nil
                    )
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 120, height: 44)
                .background(Color.blue)
                .cornerRadius(8)
            }
            .padding()
            .background(Color(red: 1, green: 0.989, blue: 0.93))
        }
    }
}

