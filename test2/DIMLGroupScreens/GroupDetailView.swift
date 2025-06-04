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
    var group: Group
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
    
    private let promptManager = PromptManager.shared
    private let storage = StorageManager.shared

    // Initialize the store with the group ID
    init(group: Group, groupStore: GroupStore) {
        self.group = group
        self.groupStore = groupStore
        self._store = StateObject(wrappedValue: EntryStore(groupId: group.id))
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
        print("Checking influencer status - Current user ID: \(Auth.auth().currentUser?.uid ?? "none"), Influencer ID: \(group.currentInfluencerId)")
        return Auth.auth().currentUser?.uid == group.currentInfluencerId
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
                
                await MainActor.run {
                    print("🔥 Adding entry to store...")
                    store.addEntry(entry)
                    print("🔥 Entry added to store. Total entries: \(store.entries.count)")
                    print("🔥 First entry imageURL: \(store.entries.first?.imageURL ?? "nil")")
                    capturedImage = nil
                    responseText = ""
                    capturedFrameSize = FrameSize.random // Reset for next capture
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
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.showCamera = granted
                }
            }
        default:
            showPermissionAlert = true
        }
    }

    private func calculateNextPromptTime() -> Date? {
        let calendar = Calendar.current
        let intervalHours = group.promptFrequency.intervalHours
        
        // Active day is 7 AM to 9 PM
        let activeDayStart = 7
        let activeDayEnd = 21
        
        // Find the current prompt entry to get its upload timestamp
        guard let currentEntry = store.entries.first(where: { $0.prompt == currentPrompt }) else {
            // If no entry found for current prompt, they haven't uploaded yet
            return nil
        }
        
        // Calculate the next prompt time by adding the interval to the upload time
        let uploadTime = currentEntry.timestamp
        let nextPromptTime = calendar.date(byAdding: .hour, value: intervalHours, to: uploadTime) ?? uploadTime
        let nextPromptHour = calendar.component(.hour, from: nextPromptTime)
        
        // If the next prompt time falls within the active window (7 AM - 9 PM)
        if nextPromptHour >= activeDayStart && nextPromptHour <= activeDayEnd {
            return nextPromptTime
        }
        
        // If the next prompt would be outside the active window, schedule for tomorrow at 7 AM
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: uploadTime) ?? uploadTime
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        dateComponents.hour = activeDayStart
        dateComponents.minute = 0
        dateComponents.second = 0
        
        return calendar.date(from: dateComponents)
    }
    
    private func updateCountdown() {
        // Check if user has completed the current prompt
        let hasCompletedCurrentPrompt = store.entries.contains { entry in
            entry.prompt == currentPrompt
        }
        
        guard isInfluencer else {
            nextPromptCountdown = ""
            return
        }
        
        // If hasn't completed current prompt, don't show countdown number
        guard hasCompletedCurrentPrompt else {
            nextPromptCountdown = "Complete current prompt first"
            return
        }
        
        guard let nextPromptTime = calculateNextPromptTime() else {
            nextPromptCountdown = ""
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
        
        if hours > 0 {
            nextPromptCountdown = "\(hours)h \(minutes)m"
        } else {
            nextPromptCountdown = "\(minutes)m"
        }
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

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topBarView
                mainContentView
            }
            bottomNavigationView
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
        .sheet(isPresented: $showSettings) {
            GroupSettingsView(groupStore: groupStore, group: group)
                .onDisappear {
                    // Refresh countdown when returning from settings
                    startCountdownTimer()
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
            // TEMPORARY: Clear all entries once
            // UserDefaults.standard.removeObject(forKey: "entries_\(group.id)")
            // print("🗑️ Cleared local entries for group \(group.id)")
            
            // Force reload entries from UserDefaults to ensure UI reflects the cleared state
            print("🔄 Forcing EntryStore to reload from UserDefaults...")
            // store.reloadEntries() // Commenting out due to property wrapper issues
            print("🔄 Current entry count: \(store.entries.count)")
            
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
    
    // MARK: - View Components
    
    private var topBarView: some View {
        HStack {
            Button(action: {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController = UIHostingController(rootView: GroupListView())
                }
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
                    previousEntriesView
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
            }
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    hideKeyboard()
                }
        )
    }
    
    private var bottomNavigationView: some View {
        VStack {
            Spacer()
            BottomNavBar(
                currentTab: Binding(
                    get: { currentTab },
                    set: { newTab in
                        if newTab == .camera {
                            checkCameraPermission()
                        } else if newTab == .home {
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = windowScene.windows.first {
                                window.rootViewController = UIHostingController(rootView: GroupListView())
                            }
                        } else if newTab == .profile {
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = windowScene.windows.first {
                                window.rootViewController = UIHostingController(rootView: ProfileView())
                            }
                        }
                        currentTab = newTab
                    }
                ),
                onCameraTap: {
                    print("Camera tap triggered")
                    checkCameraPermission()
                },
                isInfluencer: isInfluencer
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
            
            if let image = capturedImage {
                capturedImageView(image: image)
            } else {
                promptAreaView
            }
            
            countdownTimerView
            circleMembersView
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
    
    private var previousEntriesView: some View {
        ForEach(store.entries.filter { $0.prompt != currentPrompt }) { entry in
            entryView(entry: entry)
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
    
    private var promptAreaView: some View {
        // Check if there's already an entry for today's prompt
        let todaysEntry = store.entries.first { entry in
            entry.prompt == currentPrompt
        }
        
        if let entry = todaysEntry {
            // Show the completed entry instead of prompt area
            return AnyView(entryView(entry: entry))
        } else {
            // Large grey box with sun icon and call to action
            return AnyView(
                VStack(spacing: 16) {
                    Image(systemName: getPromptIcon())
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(Color(red: 0.95, green: 0.77, blue: 0.06))

                    // Show the actual prompt as the main text
                    VStack(spacing: 8) {
                        Text(currentPrompt)
                            .font(.custom("Fredoka-Medium", size: 18))
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                            .lineLimit(4)
                            .padding(.horizontal, 16)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(red: 0.92, green: 0.92, blue: 0.92))
                .cornerRadius(16)
                .padding(.horizontal)
            )
        }
    }
    
    private var countdownTimerView: some View {
        // Yellow box with lock icon and timer (always visible for influencers)
        HStack {
            Image(systemName: "lock.fill")
                .foregroundColor(.gray)
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
                                // Add heart reaction
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "heart")
                                        .foregroundColor(.red)
                                    Text("3")
                                        .font(.custom("Fredoka-Regular", size: 14))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Button(action: {
                                // Add fire reaction
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "flame")
                                        .foregroundColor(.orange)
                                    Text("5")
                                        .font(.custom("Fredoka-Regular", size: 14))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Button(action: {
                                // Open comments
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "message")
                                        .foregroundColor(.blue)
                                    Text("Comment")
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
        }
        .background(Color(red: 1.0, green: 0.95, blue: 0.80))
        .cornerRadius(15)
        .padding(.horizontal)
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
