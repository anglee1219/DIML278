import SwiftUI
import AVFoundation
import FirebaseAuth
import FirebaseStorage
import Foundation
import UserNotifications

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
    
    private let promptManager = PromptManager.shared
    private let storage = StorageManager.shared

    // Initialize the store with the group ID
    init(group: Group, groupStore: GroupStore) {
        self._group = State(initialValue: group)
        self.groupStore = groupStore
        self._store = StateObject(wrappedValue: EntryStore(groupId: group.id))
        // Initialize cached influencer status
        self._cachedIsInfluencer = State(initialValue: Auth.auth().currentUser?.uid == group.currentInfluencerId)
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
        
        // If current prompt is completed, check if enough time has passed for next prompt
        guard let nextPromptTime = calculateNextPromptTime() else {
            print("🕐 shouldShowNextPrompt: No next prompt time calculated")
            return false
        }
        
        let now = Date()
        let timeRemaining = nextPromptTime.timeIntervalSince(now)
        let shouldShow = timeRemaining <= 0
        
        print("🕐 shouldShowNextPrompt: timeRemaining=\(timeRemaining), shouldShow=\(shouldShow)")
        
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
        isUploading = true
        
        Task {
            do {
                let imagePath = "diml_images/\(UUID().uuidString).jpg"
                print("🔥 Uploading to Firebase Storage path: \(imagePath)")
                let downloadURL = try await storage.uploadImage(image, path: imagePath)
                print("🔥 Firebase Storage upload successful!")
                print("🔥 Download URL: \(downloadURL)")
                
                let entry = DIMLEntry(
                    id: UUID().uuidString,
                    userId: Auth.auth().currentUser?.uid ?? "",
                    prompt: currentPrompt,
                    response: responseText,
                    image: nil, // Don't store local image since we have Firebase URL
                    imageURL: downloadURL, // Use Firebase Storage URL
                    frameSize: capturedFrameSize
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
                    
                    // Schedule background notification for next prompt unlock
                    self.scheduleNextPromptNotification()
                    
                    isUploading = false
                    print("🔥 Upload process completed successfully")
                }
            } catch {
                print("🔥 Firebase Storage upload error: \(error.localizedDescription)")
                print("🔥 Full error: \(error)")
                await MainActor.run {
                    errorMessage = "Upload failed: \(error.localizedDescription)"
                    showError = true
                    isUploading = false
                }
            }
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
        print("⏰ calculateNextPromptTime called")
        let calendar = Calendar.current
        let intervalHours = group.promptFrequency.intervalHours
        let intervalMinutes = group.promptFrequency.intervalMinutes
        
        print("⏰ intervalHours: \(intervalHours)")
        print("⏰ intervalMinutes: \(intervalMinutes)")
        print("⏰ group.promptFrequency: \(group.promptFrequency)")
        
        // Find the most recent entry (regardless of prompt text) to get timing
        guard let mostRecentEntry = store.entries.max(by: { $0.timestamp < $1.timestamp }) else {
            print("⏰ No entries found")
            return nil
        }
        
        print("⏰ Found most recent entry with timestamp: \(mostRecentEntry.timestamp)")
        print("⏰ Most recent entry prompt: '\(mostRecentEntry.prompt)'")
        
        let uploadTime = mostRecentEntry.timestamp
        
        // Handle testing mode (1 minute intervals)
        if group.promptFrequency == .testing {
            print("⏰ Testing mode detected - 1 minute intervals")
            let nextPromptTime = calendar.date(byAdding: .minute, value: 1, to: uploadTime) ?? uploadTime
            print("⏰ Next testing prompt time: \(nextPromptTime)")
            return nextPromptTime
        }
        
        // Active day is 7 AM to 9 PM for regular intervals
        let activeDayStart = 7
        let activeDayEnd = 21
        
        // Calculate the next prompt time by adding the interval to the upload time
        let nextPromptTime = calendar.date(byAdding: .hour, value: intervalHours, to: uploadTime) ?? uploadTime
        let nextPromptHour = calendar.component(.hour, from: nextPromptTime)
        
        print("⏰ Upload time: \(uploadTime)")
        print("⏰ Calculated next prompt time: \(nextPromptTime)")
        print("⏰ Next prompt hour: \(nextPromptHour)")
        
        // If the next prompt time falls within the active window (7 AM - 9 PM)
        if nextPromptHour >= activeDayStart && nextPromptHour <= activeDayEnd {
            print("⏰ Next prompt time is within active window")
            return nextPromptTime
        }
        
        print("⏰ Next prompt time is outside active window, scheduling for tomorrow")
        
        // If the next prompt would be outside the active window, schedule for tomorrow at 7 AM
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: uploadTime) ?? uploadTime
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        dateComponents.hour = activeDayStart
        dateComponents.minute = 0
        dateComponents.second = 0
        
        let finalTime = calendar.date(from: dateComponents)
        print("⏰ Final scheduled time: \(finalTime?.description ?? "nil")")
        
        return finalTime
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
        
        // If hasn't completed current prompt, show waiting message
        if !hasCompletedCurrentPrompt {
            print("⏰ Haven't completed current prompt")
            nextPromptCountdown = "Complete current prompt first"
            return
        }
        
        // If current prompt is completed, calculate time for NEXT prompt
        guard let nextPromptTime = calculateNextPromptTime() else {
            print("⏰ No next prompt time calculated")
            nextPromptCountdown = ""
            return
        }
        
        let now = Date()
        let timeInterval = nextPromptTime.timeIntervalSince(now)
        
        print("⏰ nextPromptTime: \(nextPromptTime)")
        print("⏰ now: \(now)")
        print("⏰ timeInterval: \(timeInterval) seconds")
        
        if timeInterval <= 0 {
            print("⏰ Next prompt time has passed - making new prompt available")
            
            // Only trigger unlock animation if we haven't already done so for this timing cycle
            if !hasTriggeredUnlockForCurrentPrompt {
                print("🎯 🎬 Setting flag for delayed prompt unlock animation")
                print("🎯 🎬 Previous hasNewPromptReadyForAnimation: \(hasNewPromptReadyForAnimation)")
                hasTriggeredUnlockForCurrentPrompt = true
                
                // Generate a new prompt when countdown reaches zero
                let newPrompt = getCurrentPrompt()
                print("🎯 🎬 getCurrentPrompt() returned: '\(newPrompt)'")
                print("🎯 🎬 Current stored prompt: '\(currentPrompt)'")
                if newPrompt != currentPrompt {
                    print("🎯 New prompt available: '\(newPrompt)'")
                    // Instead of triggering animation immediately, just set flag and update prompt
                    currentPrompt = newPrompt
                    hasNewPromptReadyForAnimation = true
                    print("🎯 🎬 SET hasNewPromptReadyForAnimation = true")
                    
                    // Update prompt configuration for consistency
                    currentPromptConfiguration = getCurrentPromptConfiguration()
                    if let newConfig = currentPromptConfiguration {
                        isImagePrompt = newConfig.fields.isEmpty
                        if !newConfig.prompt.isEmpty {
                            currentPrompt = newConfig.prompt
                            print("🎯 🎬 Updated currentPrompt from config: '\(currentPrompt)'")
                        }
                    }
                } else {
                    print("🎯 Generated prompt is same as current, generating simple unique prompt")
                    
                    // Use a simple, guaranteed unique prompt to avoid freezing
                    let completedCount = store.entries.count
                    let fallbackPrompt = "What's happening in your day right now? (\(completedCount + 1))"
                    
                    print("🎯 Using simple fallback prompt: '\(fallbackPrompt)'")
                    // Set flag instead of triggering animation
                    currentPrompt = fallbackPrompt
                    hasNewPromptReadyForAnimation = true
                    print("🎯 🎬 SET hasNewPromptReadyForAnimation = true (fallback)")
                    
                    // Update prompt configuration for fallback prompt
                    isImagePrompt = true // Simple fallback prompts are typically image prompts
                }
                
                print("🎯 🎬 FINAL STATE:")
                print("🎯 🎬 - currentPrompt: '\(currentPrompt)'")
                print("🎯 🎬 - hasNewPromptReadyForAnimation: \(hasNewPromptReadyForAnimation)")
                print("🎯 🎬 - hasTriggeredUnlockForCurrentPrompt: \(hasTriggeredUnlockForCurrentPrompt)")
            } else {
                print("⏰ Prompt unlock already triggered for this timing cycle, skipping duplicate")
            }
            return
        }
        
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60
        
        print("⏰ Calculated: \(hours)h \(minutes)m \(seconds)s")
        
        // For testing mode, show seconds precision
        if group.promptFrequency == .testing {
            if minutes > 0 {
                nextPromptCountdown = "\(minutes)m \(seconds)s"
            } else {
                nextPromptCountdown = "\(seconds)s"
            }
        } else {
            // For regular modes, show hours and minutes
            if hours > 0 {
                nextPromptCountdown = "\(hours)h \(minutes)m"
            } else {
                nextPromptCountdown = "\(minutes)m"
            }
        }
        
        print("⏰ Final countdown: '\(nextPromptCountdown)'")
    }
    
    private func startCountdownTimer() {
        stopCountdownTimer()
        updateCountdown()
        
        // Use different timer intervals based on prompt frequency
        let timerInterval: TimeInterval = group.promptFrequency == .testing ? 1.0 : 60.0
        print("⏰ Starting countdown timer with interval: \(timerInterval) seconds")
        
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
        print("🎬 ===== STARTING PROMPT UNLOCK ANIMATION SEQUENCE =====")
        print("🎬 Function called with newPrompt: '\(newPrompt)'")
        print("🎬 Current time: \(Date())")
        
        // Haptic feedback for unlock start
        print("🎬 Triggering MEDIUM haptic feedback...")
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare() // Prepare the generator
        impactFeedback.impactOccurred()
        print("🎬 Medium haptic feedback triggered!")
        
        // Step 1: Start countdown refresh animation - this makes the countdown timer flash and indicate it's about to unlock
        print("🎬 Step 1: Starting countdown refresh animation...")
        withAnimation(.easeInOut(duration: 0.5)) {
            animateCountdownRefresh = true
        }
        print("🎬 animateCountdownRefresh set to: \(animateCountdownRefresh)")
        
        // Step 2: After refresh, start the unlock transition - countdown timer becomes the unlock state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🎬 Step 2: Starting unlock transition...")
            
            // Haptic feedback for unlock phase
            print("🎬 Triggering LIGHT haptic feedback...")
            let unlockFeedback = UIImpactFeedbackGenerator(style: .light)
            unlockFeedback.prepare()
            unlockFeedback.impactOccurred()
            print("🎬 Light haptic feedback triggered!")
            
            // Set unlocking state - this will make countdown timer transform into loading state
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                isUnlockingPrompt = true
            }
            print("🎬 isUnlockingPrompt set to: \(isUnlockingPrompt)")
            
            // Step 3: Complete the unlock and reveal the new prompt card
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                print("🎬 Step 3: Revealing new prompt card...")
                currentPrompt = newPrompt
                hasInteractedWithCurrentPrompt = false
                
                // Regenerate and store new configuration for consistency
                currentPromptConfiguration = getCurrentPromptConfiguration()
                if let newConfig = currentPromptConfiguration {
                    isImagePrompt = newConfig.fields.isEmpty
                    // Update currentPrompt from the stored configuration to ensure consistency
                    if !newConfig.prompt.isEmpty {
                        currentPrompt = newConfig.prompt
                    }
                }
                print("🎯 New prompt is image prompt: \(isImagePrompt)")
                print("🎯 Updated currentPrompt: '\(currentPrompt)'")
                
                // Haptic feedback for prompt reveal
                print("🎬 Triggering SUCCESS haptic feedback...")
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
            print("🔍 🎬 Animation flags on appear:")
            print("🔍 🎬 - hasNewPromptReadyForAnimation: \(hasNewPromptReadyForAnimation)")
            print("🔍 🎬 - hasTriggeredUnlockForCurrentPrompt: \(hasTriggeredUnlockForCurrentPrompt)")
            print("🔍 🎬 - isInfluencer: \(isInfluencer)")
            
            // Always load/check daily prompt - loadDailyPrompt handles timing logic
            print("🔍 Loading daily prompt...")
            let oldPrompt = currentPrompt
            loadDailyPrompt()
            print("🔍 Loaded prompt: '\(currentPrompt)'")
            
            // Check if we have a new prompt ready for animation when entering the view
            if isInfluencer && hasNewPromptReadyForAnimation {
                print("🔍 🎬 NEW PROMPT READY FOR ANIMATION DETECTED!")
                print("🔍 🎬 Current prompt: '\(currentPrompt)'")
                hasNewPromptReadyForAnimation = false // Clear the flag
                
                // Auto-scroll FIRST, then trigger animation so user can see it happen
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    print("🔄 Auto-scrolling to new prompt BEFORE animation")
                    shouldAutoScrollToPrompt = true
                    
                    // Then trigger animation after scroll completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        print("🔍 🎬 TRIGGERING UNLOCK ANIMATION NOW!")
                        triggerPromptUnlockAnimation(newPrompt: currentPrompt)
                    }
                }
            } else if isInfluencer {
                print("🔍 🎬 No animation flag set, checking for other prompt changes...")
                print("🔍 🎬 Reasons flag might not be set:")
                print("🔍 🎬 - isInfluencer: \(isInfluencer)")
                print("🔍 🎬 - hasNewPromptReadyForAnimation: \(hasNewPromptReadyForAnimation)")
                
                // Also check if we should trigger animation based on timing instead of flag
                let hasCompletedCurrentPrompt = store.entries.contains { $0.prompt == currentPrompt }
                if let nextPromptTime = calculateNextPromptTime() {
                    let timeRemaining = nextPromptTime.timeIntervalSince(Date())
                    print("🔍 🎬 Timing check - timeRemaining: \(timeRemaining)")
                    
                    if timeRemaining <= 0 && !hasCompletedCurrentPrompt {
                        print("🔍 🎬 FALLBACK: Triggering animation based on timing check!")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            shouldAutoScrollToPrompt = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                triggerPromptUnlockAnimation(newPrompt: currentPrompt)
                            }
                        }
                    }
                }
                
                // Standard check for prompt changes (existing logic)
                if currentPrompt != oldPrompt && !currentPrompt.isEmpty && !oldPrompt.isEmpty {
                    print("🔍 New prompt detected after timing check: '\(currentPrompt)', triggering animation")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        triggerPromptUnlockAnimation(newPrompt: currentPrompt)
                    }
                }
                
                // Auto-scroll to active prompt for influencers when main view appears (existing logic)
                // Reuse the hasCompletedCurrentPrompt variable from above instead of redeclaring
                print("🔄 Auto-scroll check: isInfluencer=\(isInfluencer), currentPrompt='\(currentPrompt)', hasCompleted=\(hasCompletedCurrentPrompt)")
                
                if !hasCompletedCurrentPrompt && !currentPrompt.isEmpty {
                    print("🔄 Scheduling auto-scroll to activePrompt in 0.8 seconds")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        print("🔄 Triggering auto-scroll...")
                        shouldAutoScrollToPrompt = true
                    }
                } else {
                    print("🔄 Auto-scroll skipped: prompt completed or empty")
                }
            } else {
                print("🔄 Auto-scroll skipped: not influencer")
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
                    Image(systemName: "sparkles")
                        .foregroundColor(Color(red: 1.0, green: 0.815, blue: 0.0))
                    Text("New prompt unlocked! Scroll down to answer it.")
                        .font(.custom("Fredoka-Medium", size: 14))
                        .foregroundColor(Color(red: 1.0, green: 0.815, blue: 0.0))
                    Spacer()
                    Button(action: { showNewPromptUnlockedFeedback = false }) {
                        Image(systemName: "xmark")
                            .foregroundColor(Color(red: 1.0, green: 0.815, blue: 0.0))
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(red: 1.0, green: 0.815, blue: 0.0).opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Main top bar
            HStack {
                Button(action: {
                    print("🔴 Back button tapped - dismissing GroupDetailView")
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.black)
                }

                Spacer()

                Image("DIML_Logo")
                    .resizable()
                    .frame(width: 40, height: 40)

                Spacer()

                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.black)
                }
                
                // Temporary test notification button (for debugging)
                if isInfluencer {
                    Button(action: {
                        print("🧪 Test notification button tapped")
                        
                        // Check notification settings in detail
                        UNUserNotificationCenter.current().getNotificationSettings { settings in
                            print("🧪 === Notification Settings Debug ===")
                            print("🧪 Authorization Status: \(settings.authorizationStatus.rawValue)")
                            print("🧪 Alert Setting: \(settings.alertSetting.rawValue)")
                            print("🧪 Sound Setting: \(settings.soundSetting.rawValue)")
                            print("🧪 Badge Setting: \(settings.badgeSetting.rawValue)")
                            print("🧪 Notification Center Setting: \(settings.notificationCenterSetting.rawValue)")
                            print("🧪 Lock Screen Setting: \(settings.lockScreenSetting.rawValue)")
                            print("🧪 Car Play Setting: \(settings.carPlaySetting.rawValue)")
                            print("🧪 Critical Alert Setting: \(settings.criticalAlertSetting.rawValue)")
                            print("🧪 Announcement Setting: \(settings.announcementSetting.rawValue)")
                            print("🧪 Scheduled Delivery Setting: \(settings.scheduledDeliverySetting.rawValue)")
                            print("🧪 === End Notification Settings ===")
                            
                            // Check if we can send notifications
                            if settings.authorizationStatus == .authorized {
                                print("🧪 ✅ Authorized - sending test notification")
                                print("🧪 💡 To test background notifications:")
                                print("🧪    1. Tap this button")
                                print("🧪    2. Immediately close the app (swipe up, don't just minimize)")
                                print("🧪    3. Wait 2 seconds")
                                print("🧪    4. You should see a notification on your lock screen/home screen")
                                
                                // Test different notification types
                                self.sendTestNotifications()
                            } else {
                                print("🧪 ❌ Not authorized - status: \(settings.authorizationStatus)")
                            }
                        }
                        
                    }) {
                        Image(systemName: "bell.badge")
                            .foregroundColor(.blue)
                    }
                }
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
            
    private var bottomNavigationView: some View {
            VStack {
                Spacer()
                BottomNavBar(
                    currentTab: Binding(
                        get: { currentTab },
                        set: { newTab in
                            print("🔴 Bottom nav tab changed to: \(newTab)")
                            if newTab == .camera {
                            checkCameraPermission()
                            } else if newTab == .home {
                                print("🔴 Home tab selected - dismissing GroupDetailView")
                                dismiss()
                            } else if newTab == .profile {
                                print("🔴 Profile tab selected - dismissing GroupDetailView")
                                dismiss()
                            }
                            currentTab = newTab
                        }
                    ),
                    onCameraTap: {
                        print("Camera tap triggered")
                        checkCameraPermission()
                    },
                    isInfluencer: isInfluencer,
                    shouldBounceCamera: isImagePrompt && isInfluencer
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
        
        return ForEach(sortedEntries) { entry in
            entryView(entry: entry)
        }
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
                    frameSize: FrameSize.random
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
                    
                    // Schedule background notification for next prompt unlock
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
            print("📱 Skipping notification scheduling: not influencer or notifications muted")
            return
        }
        
        guard let nextPromptTime = calculateNextPromptTime() else {
            print("📱 No next prompt time calculated, cannot schedule notification")
            return
        }
        
        let now = Date()
        let timeInterval = nextPromptTime.timeIntervalSince(now)
        
        print("📱 🕐 Scheduling background notification for next prompt")
        print("📱 🕐 Current time: \(now)")
        print("📱 🕐 Next prompt time: \(nextPromptTime)")
        print("📱 🕐 Time interval: \(timeInterval) seconds")
        
        // Only schedule if it's in the future
        guard timeInterval > 0 else {
            print("📱 🕐 Next prompt time is in the past, not scheduling notification")
            return
        }
        
        // Cancel any existing prompt unlock notifications for this user
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let existingPromptNotifications = requests.filter { 
                $0.identifier.contains("prompt_unlocked_\(currentUserId)")
            }
            
            if !existingPromptNotifications.isEmpty {
                let identifiersToRemove = existingPromptNotifications.map { $0.identifier }
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
                print("📱 🕐 Cancelled \(identifiersToRemove.count) existing prompt unlock notifications")
            }
            
            // Schedule the new notification
            let content = UNMutableNotificationContent()
            content.title = "🔓 New Prompt Ready!"
            content.body = "Your next DIML prompt is ready to answer!"
            content.sound = .default
            content.badge = 1
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
            let identifier = "prompt_unlocked_\(currentUserId)_\(nextPromptTime.timeIntervalSince1970)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("📱 🕐 ❌ Error scheduling background notification: \(error)")
                } else {
                    print("📱 🕐 ✅ Successfully scheduled background notification")
                    print("📱 🕐 ✅ Will fire in \(Int(timeInterval)) seconds at \(nextPromptTime)")
                    
                    // Verify it was scheduled
                    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                        let scheduledPromptNotifications = requests.filter { 
                            $0.identifier.contains("prompt_unlocked")
                        }
                        print("📱 🕐 📋 Total scheduled prompt notifications: \(scheduledPromptNotifications.count)")
                    }
                }
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
            HStack {
                Button(action: {
                    print("Share button tapped")
                    uploadImage(capturedImage!)
                }) {
                    Text(isUploading ? "Uploading..." : "Share")
                        .font(.custom("Fredoka-Regular", size: 16))
                        .foregroundColor(.blue)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .disabled(isUploading)
            
                Button(action: {
                    print("Retake button tapped")
                    capturedImage = nil 
                }) {
                    Text("Retake")
                        .font(.custom("Fredoka-Regular", size: 16))
                        .foregroundColor(.red)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
    }
    
    private var animatedCountdownTimerView: some View {
        VStack(spacing: 16) {
            let hasCompletedCurrentPrompt = store.entries.contains { $0.prompt == currentPrompt }
            let shouldShowNextPrompt = shouldShowNextPrompt()
            let isInitialPrompt = store.entries.isEmpty
            
            // Show prompt card when:
            // 1. No entries yet (initial state)
            // 2. During unlock animation
            // 3. After unlock animation is complete
            // 4. Current prompt hasn't been completed and timing allows
            let shouldShowPromptCard = isInitialPrompt || 
                                     isUnlockingPrompt || 
                                     showNewPromptCard ||
                                     (!hasCompletedCurrentPrompt && shouldShowNextPrompt)
            
            if shouldShowPromptCard {
                // Show the prompt card
                if let config = currentPromptConfiguration {
                    PromptCard(configuration: config) { response in
                        handlePromptResponse(response)
                    }
                    .scaleEffect(showNewPromptCard ? 1.0 : (isInitialPrompt ? 1.0 : 0.95))
                    .opacity(showNewPromptCard ? 1.0 : (isInitialPrompt ? 1.0 : 0.8))
                    .animation(.spring(response: 1.2, dampingFraction: 0.6), value: showNewPromptCard)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Text("Loading prompt...")
                        .font(.custom("Fredoka-Regular", size: 16))
                        .foregroundColor(.gray)
                        .padding()
                }
            } else {
                // Show countdown timer card only when prompt is completed and waiting for next
                HStack {
                    // Animated lock icon
                    Image(systemName: "lock.fill")
                        .foregroundColor(.gray)
                        .rotationEffect(.degrees(animateCountdownRefresh ? 360 : 0))
                        .scaleEffect(animateCountdownRefresh ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.8), value: animateCountdownRefresh)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next Prompt Unlocking in...")
                            .font(.custom("Fredoka-Regular", size: 14))
                            .foregroundColor(.gray)
                        
                        if nextPromptCountdown.isEmpty {
                            Text("Upload current prompt first")
                                .font(.custom("Fredoka-Medium", size: 16))
                                .foregroundColor(.gray)
                        } else if nextPromptCountdown == "Complete current prompt first" {
                            Text("Upload current prompt first")
                                .font(.custom("Fredoka-Medium", size: 16))
                                .foregroundColor(.gray)
                        } else if nextPromptCountdown == "New prompt available!" && !hasCompletedCurrentPrompt {
                            Text("Answer the prompt above!")
                                .font(.custom("Fredoka-Medium", size: 16))
                                .foregroundColor(.black)
                                .scaleEffect(animateCountdownRefresh ? 1.05 : 1.0)
                                .animation(.easeInOut(duration: 0.5).repeatCount(3, autoreverses: true), value: animateCountdownRefresh)
                        } else if nextPromptCountdown == "New prompt available!" && hasCompletedCurrentPrompt {
                            Text("Ready to unlock!")
                                .font(.custom("Fredoka-Medium", size: 16))
                                .foregroundColor(.green)
                        } else {
                            Text(nextPromptCountdown)
                                .font(.custom("Fredoka-Medium", size: 16))
                                .foregroundColor(.black)
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 1.0, green: 0.95, blue: 0.80))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(animateCountdownRefresh ? Color.green : Color.clear, lineWidth: 2)
                                .animation(.easeInOut(duration: 0.3), value: animateCountdownRefresh)
                        )
                )
                .scaleEffect(animateCountdownRefresh ? 1.02 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: animateCountdownRefresh)
                .transition(.scale.combined(with: .opacity))
            }
            
            // Show countdown for NEXT prompt after current one is unlocked and completed
            if showNewPromptCard && hasCompletedCurrentPrompt {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.gray)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next Prompt Unlocking in...")
                            .font(.custom("Fredoka-Regular", size: 14))
                            .foregroundColor(.gray)
                        
                        Text("Complete current prompt first")
                            .font(.custom("Fredoka-Medium", size: 16))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.95, green: 0.95, blue: 0.95))
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
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
                                      Color.gray.opacity(0.3))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Text(member.name.prefix(1).uppercased())
                                        .font(.custom("Fredoka-Medium", size: 20))
                                        .foregroundColor(member.id == group.currentInfluencerId ? 
                                                       .white : .gray)
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
    
    private var influencerEntryView: some View {
        // Check if influencer has posted today's prompt
        let influencerTodayEntry = store.entries.first { entry in
            entry.prompt == currentPrompt && entry.userId == group.currentInfluencerId
        }
        
        if let entry = influencerTodayEntry {
            // Show influencer's completed entry for today
            return AnyView(
                VStack(alignment: .leading, spacing: 0) {
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
                                    .onAppear {
                                        print("🖼️ Image loaded successfully from: \(imageURL)")
                                    }
                            case .failure(let error):
                                VStack {
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                    Text("Failed to load image")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .frame(height: entry.frameSize.height)
                                .onAppear {
                                    print("🖼️ Image load failed: \(error.localizedDescription)")
                                    print("🖼️ URL was: \(imageURL)")
                                }
                            case .empty:
                                ProgressView()
                                    .frame(height: entry.frameSize.height)
                                    .onAppear {
                                        print("🖼️ Loading image from: \(imageURL)")
                                    }
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .padding(.horizontal, 16)
                    } else {
                        Text("No image URL")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(height: 100)
                            .onAppear {
                                print("🖼️ Entry has no imageURL. Entry: \(entry.id)")
                            }
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
                    
                    // Reactions and comments section for non-influencers
                    VStack(spacing: 12) {
                        Divider()
                            .padding(.horizontal, 16)
                        
                        // Reaction buttons
                        HStack(spacing: 20) {
                            Button(action: {
                                store.addReaction(to: entry.id, reaction: "❤️")
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "heart")
                                        .foregroundColor(.red)
                                    Text("\(entry.reactions["❤️", default: 0])")
                                        .font(.custom("Fredoka-Regular", size: 14))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Button(action: {
                                store.addReaction(to: entry.id, reaction: "🔥")
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "flame")
                                        .foregroundColor(.orange)
                                    Text("\(entry.reactions["🔥", default: 0])")
                                        .font(.custom("Fredoka-Regular", size: 14))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Button(action: {
                                selectedEntryForComments = entry
                                showComments = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "message")
                                        .foregroundColor(.blue)
                                    Text("Comment (\(entry.comments.count))")
                                        .font(.custom("Fredoka-Regular", size: 14))
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
                .background(Color(red: 1.0, green: 0.95, blue: 0.80))
                .cornerRadius(15)
                .padding(.horizontal)
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
    
    private func entryView(entry: DIMLEntry) -> some View {
        // Create the same configuration that would have been used for this entry
        let entryConfiguration = getEntryConfigurationMatchingPrompt(for: entry)
        
        // Display completed entry using the same PromptCard styling
        return PromptCard(
            configuration: entryConfiguration,
            onComplete: nil // No completion handler for completed entries
        )
        .opacity(0.9) // Slightly dimmed to show it's completed
    }
    
    private func getEntryConfigurationMatchingPrompt(for entry: DIMLEntry) -> PromptConfiguration {
        // Sort all entries by timestamp to get chronological order
        let sortedEntries = store.entries.sorted { $0.timestamp < $1.timestamp }
        
        // Find the chronological index of this entry
        let entryIndex = sortedEntries.firstIndex(where: { $0.id == entry.id }) ?? 0
        let isEvenPrompt = entryIndex % 2 == 0
        
        if isEvenPrompt {
            // This was an image prompt - show with date bubble only if it was the first entry
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
            // This was a text prompt - determine which type
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
    
    private func sendTestNotifications() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("🧪 ❌ No current user ID")
            return
        }
        
        print("🧪 Sending single test notification...")
        
        // Single test notification
        let content = UNMutableNotificationContent()
        content.title = "🧪 Test Notification"
        content.body = "This should appear both in foreground and background"
        content.sound = .default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2.0, repeats: false)
        let request = UNNotificationRequest(identifier: "single_test_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🧪 ❌ Test notification error: \(error.localizedDescription)")
            } else {
                print("🧪 ✅ Test notification scheduled successfully")
                
                // Check what's pending
                UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                    print("🧪 📋 Total pending notifications: \(requests.count)")
                    for request in requests {
                        if request.identifier.contains("test") {
                            print("🧪 📋 Test notification: \(request.identifier) - \(request.content.title)")
                        }
                    }
                }
            }
        }
    }
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
    
    var body: some View {
        if let group = groupStore.getGroup(withId: groupId) {
            GroupDetailView(group: group, groupStore: groupStore)
        } else {
            // Group not found - show error or navigate back
            VStack {
                Text("Group not found")
                    .font(.title)
                    .foregroundColor(.gray)
                Button("Go Back") {
                    // This will be handled by the navigation
                }
            }
        }
    }
}

