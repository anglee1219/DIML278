import SwiftUI
import AVFoundation
import FirebaseAuth
import FirebaseStorage
import Foundation

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
    
    private func getCurrentPrompt() -> String {
        return currentPrompt
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
                    
                    // Clear captured image and reset states
                    capturedImage = nil
                    responseText = ""
                    capturedFrameSize = FrameSize.random // Reset for next capture
                    hasInteractedWithCurrentPrompt = false // Reset interaction flag
                    
                    // Reset animation states when prompt is completed
                    resetAnimationStates()
                    
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
        
        print("⏰ intervalHours: \(intervalHours)")
        print("⏰ group.promptFrequency: \(group.promptFrequency)")
        
        // Find the current prompt entry to get its upload timestamp
        guard let currentEntry = store.entries.first(where: { $0.prompt == currentPrompt }) else {
            print("⏰ No entry found for current prompt: '\(currentPrompt)'")
            // If no entry found for current prompt, they haven't uploaded yet
            return nil
        }
        
        print("⏰ Found current entry with timestamp: \(currentEntry.timestamp)")
        
        // Special case: Testing mode (0 hours) - next prompt available immediately
        if intervalHours == 0 {
            print("⏰ Testing mode detected - next prompt available immediately")
            return currentEntry.timestamp // Return upload time, so timeInterval will be negative and show "New prompt available!"
        }
        
        // Active day is 7 AM to 9 PM
        let activeDayStart = 7
        let activeDayEnd = 21
        
        // Calculate the next prompt time by adding the interval to the upload time
        let uploadTime = currentEntry.timestamp
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
            
            // Generate a new prompt when countdown reaches zero
            let newPrompt = getCurrentPrompt()
            if newPrompt != currentPrompt {
                print("🎯 New prompt available: '\(newPrompt)'")
                triggerPromptUnlockAnimation(newPrompt: newPrompt)
            } else {
                print("🎯 Generated prompt is same as current, forcing new prompt generation")
                // Force a different prompt with much more variation
                let calendar = Calendar.current
                let today = Date()
                let timeOfDay = TimeOfDay.current()
                
                // Get all completed prompts to avoid repeating any of them
                let completedPrompts = Set(store.entries.map { $0.prompt })
                
                // Try multiple different seeds until we get a unique prompt
                var attempts = 0
                var uniquePrompt: String?
                let maxAttempts = 50 // Prevent infinite loop
                
                while attempts < maxAttempts {
                    // Create a highly varied seed using attempt number, timestamp, and other factors
                    let timestamp = Int(Date().timeIntervalSince1970)
                    let baseDailySeed = calendar.component(.year, from: today) * 1000 + (calendar.ordinality(of: .day, in: .year, for: today) ?? 1)
                    let variationSeed = UInt64(abs(baseDailySeed)) + 
                                       UInt64(attempts * 7919) + // Prime number multiplier for attempts
                                       UInt64(timestamp % 10000) + // Timestamp variation
                                       UInt64(abs(group.id.hashValue * (attempts + 1))) + // Group variation
                                       UInt64(completedPrompts.count * 1337) // Completion count variation
                    
                    var generator = SeededRandomNumberGenerator(seed: variationSeed)
                    let candidatePrompt = promptManager.getSeededPrompt(for: timeOfDay, using: &generator) ?? "What does your day look like?"
                    
                    print("🎯 Attempt \(attempts + 1): Generated candidate prompt: '\(candidatePrompt)'")
                    
                    // Check if this prompt is different from current and not in completed prompts
                    if candidatePrompt != currentPrompt && !completedPrompts.contains(candidatePrompt) {
                        uniquePrompt = candidatePrompt
                        print("🎯 Found unique prompt after \(attempts + 1) attempts")
                        break
                    }
                    
                    attempts += 1
                }
                
                // Use the unique prompt or fallback
                if let uniquePrompt = uniquePrompt {
                    print("🎯 Successfully set new unique prompt: '\(uniquePrompt)'")
                    triggerPromptUnlockAnimation(newPrompt: uniquePrompt)
                } else {
                    // Fallback: append a number to make it unique
                    let fallbackPrompt = "Tell me about this moment in your day (\(completedPrompts.count + 1))"
                    print("🎯 Using fallback prompt with counter: '\(fallbackPrompt)'")
                    triggerPromptUnlockAnimation(newPrompt: fallbackPrompt)
                }
            }
            return
        }
        
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        print("⏰ Calculated: \(hours)h \(minutes)m")
        
        if hours > 0 {
            nextPromptCountdown = "\(hours)h \(minutes)m"
        } else {
            nextPromptCountdown = "\(minutes)m"
        }
        
        print("⏰ Final countdown: '\(nextPromptCountdown)'")
    }
    
    private func startCountdownTimer() {
        stopCountdownTimer()
        updateCountdown()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
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
        print("🎬 Starting prompt unlock animation sequence")
        
        // Haptic feedback for unlock start
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Step 1: Start countdown refresh animation (increased from 0.3 to 0.5)
        withAnimation(.easeInOut(duration: 0.5)) {
            animateCountdownRefresh = true
        }
        
        // Step 2: After refresh, start unlocking (increased delay from 0.3 to 0.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Haptic feedback for unlock phase
            let unlockFeedback = UIImpactFeedbackGenerator(style: .light)
            unlockFeedback.impactOccurred()
            
            // Increased spring duration and made it more gentle
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                isUnlockingPrompt = true
            }
            
            // Step 3: Update the prompt and show new card (increased delay from 0.3 to 0.6)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
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
                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)
                
                // Slower, more dramatic spring animation
                withAnimation(.spring(response: 1.2, dampingFraction: 0.6)) {
                    showNewPromptCard = true
                    hasUnlockedNewPrompt = true
                    isUnlockingPrompt = false
                    animateCountdownRefresh = false
                }
                
                // Step 4: Reset countdown text but keep card visible (increased delay from 0.5 to 0.8)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    nextPromptCountdown = "Complete current prompt first"
                    // Don't hide showNewPromptCard - let it stay visible until user completes prompt
                }
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
            
            // Load current prompt based on time of day
            if currentPrompt.isEmpty {
                print("🔍 Loading daily prompt...")
                loadDailyPrompt()
                print("🔍 Loaded prompt: '\(currentPrompt)'")
            }
            // Start the countdown timer
            print("🔍 Starting countdown timer...")
            startCountdownTimer()
            // Update cached influencer status
            print("🔍 Updating influencer status...")
            updateInfluencerStatus()
            // Auto-scroll to active prompt for influencers when main view appears
            print("🔄 Main content view appeared")
            if isInfluencer {
                let hasCompletedCurrentPrompt = store.entries.contains { $0.prompt == currentPrompt }
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
                }
                .padding(.horizontal)
                .padding(.top, 12)
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
            } else {
                // Show current prompt card when:
                // 1. No entries (initial state)
                // 2. New prompt card animation is active
                // 3. Current prompt hasn't been completed yet (regardless of animation states)
                let hasCompletedCurrentPrompt = store.entries.contains { $0.prompt == currentPrompt }
                let shouldShowPromptCard = store.entries.isEmpty || showNewPromptCard || !hasCompletedCurrentPrompt
                
                if shouldShowPromptCard {
                    currentPromptAreaView
                        .scaleEffect(showNewPromptCard ? 1.05 : 1.0)
                        .opacity(showNewPromptCard ? 1.0 : (store.entries.isEmpty ? 1.0 : 0.8))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showNewPromptCard)
                        .id("activePrompt")
                        .onAppear {
                            print("🎬 Prompt visibility: isEmpty=\(store.entries.isEmpty), showNewCard=\(showNewPromptCard), hasCompleted=\(hasCompletedCurrentPrompt), shouldShow=\(shouldShowPromptCard)")
                            logPromptVisibility(
                                isEmpty: store.entries.isEmpty,
                                showNewCard: showNewPromptCard,
                                hasUnlocked: hasUnlockedNewPrompt,
                                hasCompleted: hasCompletedCurrentPrompt,
                                shouldShow: shouldShowPromptCard
                            )
                        }
                } else {
                    // Empty view when prompt card is hidden
                    EmptyView()
                        .onAppear {
                            print("🎬 Active prompt card HIDDEN - prompt completed")
                        }
                }
            }
            
            // Always show countdown timer at the bottom (shows timing for NEXT prompt)
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
                    
                    // Reset states
                    print("📝 Resetting states...")
                    hasInteractedWithCurrentPrompt = false
                    resetAnimationStates()
                    isUploading = false
                    
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
        showNewPromptCard = false
        hasUnlockedNewPrompt = false
        isUnlockingPrompt = false
        animateCountdownRefresh = false
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
        // Countdown box (always visible - shows timing for NEXT prompt)
        HStack {
            // Animated lock icon
            if isUnlockingPrompt {
                Image(systemName: "lock.open.fill")
                    .foregroundColor(.green)
                    .scaleEffect(1.2)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isUnlockingPrompt)
            } else {
            Image(systemName: "lock.fill")
                .foregroundColor(.gray)
                    .rotationEffect(.degrees(animateCountdownRefresh ? 360 : 0))
                    .scaleEffect(animateCountdownRefresh ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.8), value: animateCountdownRefresh)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                if isUnlockingPrompt {
                    Text("Unlocking new prompt...")
                        .font(.custom("Fredoka-Regular", size: 14))
                        .foregroundColor(.green)
                        .transition(.opacity)
                } else {
                Text("Next Prompt Unlocking in...")
                    .font(.custom("Fredoka-Regular", size: 14))
                    .foregroundColor(.gray)
                }
                
                let hasCompletedCurrentPrompt = store.entries.contains { $0.prompt == currentPrompt }
                
                if isUnlockingPrompt {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Creating your prompt...")
                            .font(.custom("Fredoka-Medium", size: 16))
                            .foregroundColor(.green)
                    }
                    .transition(.slide)
                } else if nextPromptCountdown.isEmpty {
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
                    Text("Generating new prompt...")
                        .font(.custom("Fredoka-Medium", size: 16))
                        .foregroundColor(.gray)
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
                        .stroke(isUnlockingPrompt ? Color.green : Color.clear, lineWidth: 2)
                        .animation(.easeInOut(duration: 0.3), value: isUnlockingPrompt)
                )
        )
        .scaleEffect(isUnlockingPrompt ? 1.02 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isUnlockingPrompt)
        .padding(.horizontal)
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

