import SwiftUI
import AVFoundation
import FirebaseStorage
import FirebaseAuth
import FirebaseFirestore

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

struct DIMLFeedView: View {
    let group: Group
    @StateObject private var entryStore: EntryStore
    @State private var showCamera = false
    @State private var showImagePicker = false
    @State private var showPermissionAlert = false
    @State private var currentPrompt: String = ""
    @State private var responseText = ""
    @State private var capturedImage: UIImage?
    @State private var capturedFrameSize: FrameSize = FrameSize.random
    @State private var currentTab: Tab = .home
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var nextPromptCountdown = ""
    @State private var countdownTimer: Timer?
    
    // Initialize with group ID for persistence
    init(group: Group) {
        self.group = group
        self._entryStore = StateObject(wrappedValue: EntryStore(groupId: group.id))
    }
    
    private let promptManager = PromptManager.shared
    private let storage = StorageManager.shared
    
    private var isInfluencer: Bool {
        print("Checking influencer status - Current user ID: \(Auth.auth().currentUser?.uid ?? "none"), Influencer ID: \(group.currentInfluencerId)")
        return group.currentInfluencerId == Auth.auth().currentUser?.uid
    }
    
    private func getCurrentPrompt() -> String {
        let timeOfDay = TimeOfDay.current()
        
        // Create a daily seed based on current date to ensure consistency
        let calendar = Calendar.current
        let today = Date()
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: today) ?? 1
        let year = calendar.component(.year, from: today)
        let dailySeed = year * 1000 + dayOfYear
        
        // Include group ID in seed to ensure different prompts per group
        // Use absolute values and proper UInt64 conversion to avoid negative value errors
        let groupSeed = abs(group.id.hashValue)
        let timeSeed = abs(timeOfDay.hashValue)
        
        // Use seeded random to get consistent prompt for the day + group combination
        var generator = SeededRandomNumberGenerator(seed: UInt64(abs(dailySeed)) + UInt64(timeSeed) + UInt64(groupSeed))
        
        return promptManager.getSeededPrompt(for: timeOfDay, using: &generator) ?? "What does your day look like?"
    }
    
    private func loadDailyPrompt() {
        currentPrompt = getCurrentPrompt()
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
    
    private func checkCameraPermission() {
        // Check if user is the influencer for this specific group
        if !isInfluencer {
            // User is not the influencer for this group
            errorMessage = "Only today's influencer can take photos for this circle. You can view and react to their posts!"
            showError = true
            return
        }
        
        // User is the influencer - check if they should go to the main circle chat instead
        errorMessage = "Go to your circle chat to snap pictures for your prompts! This is just the feed view."
        showError = true
    }
    
    private func sendNewPostNotifications() async {
        print("📱 === SENDING NEW POST NOTIFICATIONS ===")
        
        guard let currentUserId = Auth.auth().currentUser?.uid,
              let influencerName = group.members.first(where: { $0.id == currentUserId })?.name else {
            print("❌ Could not get current user info for notifications")
            return
        }
        
        print("📱 Current influencer: \(influencerName) (ID: \(currentUserId))")
        
        // Get all circle members except the influencer (current user)
        let otherMembers = group.members.filter { $0.id != currentUserId }
        
        print("📱 Total circle members: \(group.members.count)")
        print("📱 Other members to notify: \(otherMembers.count)")
        
        // Debug: Print all members
        print("📱 📋 All circle members:")
        for (index, member) in group.members.enumerated() {
            let isCurrentUser = member.id == currentUserId
            print("📱 📋 [\(index + 1)] \(member.name) (ID: \(member.id)) - Current user: \(isCurrentUser)")
        }
        
        print("📱 📋 Other members to notify:")
        for (index, member) in otherMembers.enumerated() {
            print("📱 📋 [\(index + 1)] \(member.name) (ID: \(member.id))")
        }
        
        guard !otherMembers.isEmpty else {
            print("📱 ℹ️ No other members to notify - user might be the only member")
            return
        }
        
        let db = Firestore.firestore()
        
        // Send notification to each other member
        for member in otherMembers {
            print("📱 📤 Sending notification to: \(member.name) (ID: \(member.id))")
            
            do {
                // Get member's FCM token
                let userDoc = try await db.collection("users").document(member.id).getDocument()
                guard let userData = userDoc.data(),
                      let fcmToken = userData["fcmToken"] as? String else {
                    print("⚠️ No FCM token found for user \(member.name)")
                    continue
                }
                
                // Send FCM push notification
                await sendCirclePostNotification(
                    token: fcmToken,
                    influencerName: influencerName,
                    circleName: group.name,
                    targetUserId: member.id
                )
                
            } catch {
                print("❌ Error getting FCM token for \(member.name): \(error.localizedDescription)")
            }
        }
        
        print("📱 === NEW POST NOTIFICATIONS COMPLETE ===")
    }
    
    private func sendCirclePostNotification(token: String, influencerName: String, circleName: String, targetUserId: String) async {
        print("📱 Sending FCM notification for new circle post...")
        
        // Create notification request for Cloud Function
        let notificationRequest: [String: Any] = [
            "fcmToken": token,
            "title": "📷 New DIML Post",
            "body": "\(influencerName) just shared their day in \(circleName)!",
            "data": [
                "type": "diml_upload",
                "groupId": group.id,
                "groupName": group.name,
                "uploaderName": influencerName,
                "prompt": currentPrompt,
                "targetUserId": targetUserId
            ],
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        do {
            let db = Firestore.firestore()
            _ = try await db.collection("notificationRequests").addDocument(data: notificationRequest)
            print("✅ Circle post notification queued via Cloud Function")
        } catch {
            print("❌ Error queuing circle post notification: \(error.localizedDescription)")
        }
    }
    
    private func uploadImage(_ image: UIImage) {
        print("📤 === STARTING IMAGE UPLOAD ===")
        print("📤 Current user ID: \(Auth.auth().currentUser?.uid ?? "none")")
        print("📤 Group: \(group.name)")
        print("📤 Group members: \(group.members.count)")
        
        isUploading = true
        
        Task {
            do {
                let imagePath = "diml_images/\(UUID().uuidString).jpg"
                print("📤 Uploading to path: \(imagePath)")
                let downloadURL = try await storage.uploadImage(image, path: imagePath)
                print("📤 Upload successful, URL: \(downloadURL)")
                
                let entry = DIMLEntry(
                    id: UUID().uuidString,
                    userId: Auth.auth().currentUser?.uid ?? "",
                    prompt: currentPrompt,
                    response: responseText,
                    image: nil, // Don't store local image since we have Firebase URL
                    imageURL: downloadURL, // Use Firebase Storage URL
                    timestamp: Date(),
                    frameSize: capturedFrameSize,
                    promptType: .image // Explicitly set as image prompt
                )
                
                await MainActor.run {
                    print("📤 Adding entry to store...")
                    entryStore.addEntry(entry)
                    capturedImage = nil
                    responseText = ""
                    capturedFrameSize = FrameSize.random
                    isUploading = false
                    print("📤 Entry added to store successfully - EntryStore will handle notifications")
                }
                
            } catch {
                print("❌ Upload error: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isUploading = false
                }
            }
        }
    }
    
    private func calculateNextPromptTime() -> Date? {
        let calendar = Calendar.current
        
        // Get the group's frequency settings
        let frequency = group.promptFrequency
        
        // Find the most recent entry to calculate from
        guard let mostRecentEntry = entryStore.entries.max(by: { $0.timestamp < $1.timestamp }) else {
            return nil
        }
        
        let completionTime = mostRecentEntry.timestamp
        
        // Handle testing mode (1 minute intervals)
        if frequency == .testing {
            return calendar.date(byAdding: .minute, value: 1, to: completionTime)
        }
        
        // For regular frequencies, use the actual interval hours from the enum
        let intervalHours = frequency.intervalHours
        
        // Calculate the next prompt time by adding the correct interval
        let nextPromptTime = calendar.date(byAdding: .hour, value: intervalHours, to: completionTime) ?? completionTime
        
        // ALWAYS respect the exact frequency interval - no active hours restriction
        return nextPromptTime
    }
    
    private func updateCountdown() {
        // Check if user has completed the current prompt
        let hasCompletedCurrentPrompt = entryStore.entries.contains { entry in
            entry.prompt == currentPrompt
        }
        
        guard isInfluencer else {
            nextPromptCountdown = ""
            return
        }
        
        // CRITICAL: Only show countdown if current prompt is completed
        guard hasCompletedCurrentPrompt else {
            nextPromptCountdown = "Complete current prompt first"
            return
        }
        
        guard let nextPromptTime = calculateNextPromptTime() else {
            nextPromptCountdown = "Error calculating next prompt"
            return
        }
        
        let now = Date()
        let timeInterval = nextPromptTime.timeIntervalSince(now)
        
        if timeInterval <= 0 {
            nextPromptCountdown = "New prompt available!"
            return
        }
        
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60
        
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
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
            updateCountdown()
        }
    }
    
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                ScrollViewReader { proxy in
                    VStack(spacing: 16) {
                        // Header
                        HStack {
                            Text("\(group.members.first(where: { $0.id == group.currentInfluencerId })?.name ?? "")'s DIML")
                                .font(.title3)
                                .foregroundColor(Color(red: 1.0, green: 0.815, blue: 0.0))
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        if isInfluencer {
                            // Show user's name and pronouns header (always visible)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(group.members.first(where: { $0.id == group.currentInfluencerId })?.name ?? "")'s DIML")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(red: 1.0, green: 0.815, blue: 0.0))
                                
                                Text("she/her") // This could be made dynamic later
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                            
                            VStack(spacing: 16) {
                                if let image = capturedImage {
                                    // Prompt box with image inside (like Rebecca's example)
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
                                            TextField("What's on your mind?", text: $responseText, axis: .vertical)
                                                .foregroundColor(.black)
                                                .textFieldStyle(PlainTextFieldStyle())
                                                .frame(minHeight: 40)
                                                .onTapGesture {
                                                    withAnimation(.easeInOut(duration: 0.5)) {
                                                        proxy.scrollTo("responseField", anchor: .center)
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
                                                .foregroundColor(.blue)
                                                .padding(.vertical, 6)
                                                .padding(.horizontal, 12)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(8)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .disabled(isUploading)
                                        
                                        Button(action: { 
                                            print("Retake button tapped")
                                            capturedImage = nil 
                                        }) {
                                            Text("Retake")
                                                .foregroundColor(.red)
                                                .padding(.vertical, 6)
                                                .padding(.horizontal, 12)
                                                .background(Color.red.opacity(0.1))
                                                .cornerRadius(8)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 12)
                                    .padding(.bottom, 20)
                                } else {
                                    // Check if there's already an entry for today's prompt
                                    let todaysEntry = entryStore.entries.first { entry in
                                        entry.prompt == currentPrompt
                                    }
                                    
                                    if let entry = todaysEntry {
                                        // Show the completed entry instead of prompt area
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
                                            AsyncImage(url: URL(string: entry.imageURL)) { image in
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(height: entry.frameSize.height)
                                                    .cornerRadius(12)
                                                    .clipped()
                                            } placeholder: {
                                                ProgressView()
                                            }
                                            .padding(.horizontal, 16)
                                            
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
                                    } else {
                                        // Large grey box with sun icon and call to action
                                        VStack(spacing: 16) {
                                            Image(systemName: getPromptIcon())
                                                .resizable()
                                                .frame(width: 60, height: 60)
                                                .foregroundColor(Color(red: 0.95, green: 0.77, blue: 0.06))

                                            // Show the actual prompt as the main text
                                            VStack(spacing: 8) {
                                                Text(currentPrompt)
                                                    .font(.custom("Fredoka-Medium", size: 18))
                                                    .multilineTextAlignment(.center)
                                                    .foregroundColor(.black)
                                                    .lineLimit(4)
                                                    .padding(.horizontal, 16)
                                            }
                                            }
                                            .padding(.top, 8)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 40)
                                        .background(Color(red: 0.92, green: 0.92, blue: 0.92))
                                        .cornerRadius(16)
                                        .padding(.horizontal)
                                    }
                                }
                                
                                // Yellow box with lock icon and timer (always visible for influencers)
                                if isInfluencer {
                                    HStack {
                                        Image(systemName: "lock.fill")
                                            .foregroundColor(.gray)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Next Prompt Unlocking in...")
                                                .font(.body)
                                                .foregroundColor(.gray)
                                            if nextPromptCountdown.isEmpty {
                                                Text("Upload current prompt first")
                                                    .font(.custom("Fredoka-Medium", size: 16))
                                                    .foregroundColor(.gray)
                                            } else if nextPromptCountdown == "Complete current prompt first" {
                                                Text("Upload current prompt first")
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
                                    .background(Color(red: 1.0, green: 0.95, blue: 0.80))
                                    .cornerRadius(16)
                                    .padding(.horizontal)
                                }
                            }
                        }
                        
                        // Previous Entries (excluding current prompt)
                        ForEach(entryStore.entries.filter { $0.prompt != currentPrompt }) { entry in
                            // Unified entry layout with cream background
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
                                AsyncImage(url: URL(string: entry.imageURL)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: entry.frameSize.height)
                                        .cornerRadius(12)
                                        .clipped()
                                } placeholder: {
                                    ProgressView()
                                }
                                .padding(.horizontal, 16)
                                
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
                        }
                    }
                    .padding(.vertical)
                }
            }
            
            // Bottom Navigation Bar
            VStack {
                Spacer()
                BottomNavBar(
                    currentTab: $currentTab,
                    onCameraTap: {
                        print("Camera tap triggered")
                        checkCameraPermission()
                    },
                    isInfluencer: isInfluencer
                )
            }
        }
        .background(Color(red: 1, green: 0.989, blue: 0.93))
        .sheet(isPresented: $showCamera) {
            InFrameCameraView(
                isPresented: $showCamera,
                capturedImage: $capturedImage,
                capturedFrameSize: $capturedFrameSize,
                prompt: currentPrompt
            )
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: Binding(
                get: { capturedImage },
                set: { capturedImage = $0 }
            ))
        }
        .alert(isPresented: $showPermissionAlert) {
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
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Load current prompt based on time of day
            if currentPrompt.isEmpty {
                loadDailyPrompt()
            }
            // Start the countdown timer
            startCountdownTimer()
        }
        .onDisappear {
            // Stop the countdown timer
            stopCountdownTimer()
        }
    }
}

struct GroupHeaderView: View {
    let group: Group
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.name)
                .font(.title2)
                .fontWeight(.bold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(group.members) { member in
                        VStack {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(member.name.prefix(1).uppercased())
                                        .foregroundColor(.gray)
                                )
                            
                            Text(member.name)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }
}

// Preview
struct DIMLFeedView_Previews: PreviewProvider {
    static var previews: some View {
        DIMLFeedView(group: Group(
            id: "1",
            name: "Morning Circle",
            members: [
                User(id: "1", name: "John"),
                User(id: "2", name: "Sarah"),
                User(id: "3", name: "Mike")
            ],
            currentInfluencerId: "1",
            promptFrequency: .sixHours,
            notificationsMuted: false
        ))
    }
} 