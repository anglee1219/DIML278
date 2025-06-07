import SwiftUI
import AVFoundation
import FirebaseAuth

// Rebecca's initial
/*struct GroupListView: View {
    @State private var groups: [Group] = []
    @State private var showingCreateGroup = false

    var body: some View {
        NavigationView {
            List {
                ForEach(groups) { group in
                    NavigationLink(destination: GroupDetailView(group: group)) {
                        VStack(alignment: .leading) {
                            Text(group.name)
                                .font(.headline)
                            Text("Influencer: \(group.members.first(where: { $0.id == group.currentInfluencerId })?.name ?? "Unknown")")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("My Groups")
            .navigationBarItems(trailing:
                Button(action: {
                    showingCreateGroup = true
                }) {
                    Image(systemName: "plus")
                }
            )
            .sheet(isPresented: $showingCreateGroup) {
                CreateGroupView { newGroup in
                    groups.append(newGroup)
                }
            }
        }
    }
}
*/
struct GroupListView: View {
    @StateObject private var groupStore = GroupStore()
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var friendRequestManager = FriendRequestManager.shared
    var sharedTutorialManager: TutorialManager?
    @StateObject private var privateTutorialManager = TutorialManager()
    @State private var showingCreateGroup = false
    @State private var showingAddFriends = false
    @State private var showCamera = false
    @State private var showPermissionAlert = false
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var isRefreshing = false
    @State private var groupToLeave: Group?
    @State private var showLeaveConfirmation = false
    @State private var isNavigating = false
    @State private var keyboardVisible = false
    @State private var statusRefreshTimer: Timer?
    @State private var lastRefresh = Date() // Force view updates for status changes
    @State private var entryStoreCache: [String: EntryStore] = [:] // Add cache for EntryStore instances
    @State private var hasRecentFriendActivity = false // Track recent friend request activity
    @State private var showTapDebugMessage = false // Show which tap method was triggered
    @State private var tapDebugMessage = "" // The debug message to show
    
    private var tutorialManager: TutorialManager {
        return sharedTutorialManager ?? privateTutorialManager
    }
    
    // Computed properties to break up complex expressions
    private var hasPendingRequests: Bool {
        return friendRequestManager.pendingRequests.count > 0
    }
    
    private var pendingRequestCount: Int {
        return friendRequestManager.pendingRequests.count
    }
    
    // MARK: - Navigation Helper Functions
    private func debugDeviceAndOS() {
        print("🔍 === DEVICE & OS DEBUG INFO ===")
        print("🔍 Device Model: \(UIDevice.current.model)")
        print("🔍 Device Name: \(UIDevice.current.name)")
        print("🔍 System Name: \(UIDevice.current.systemName)")
        print("🔍 System Version: \(UIDevice.current.systemVersion)")
        print("🔍 Screen Size: \(UIScreen.main.bounds)")
        print("🔍 Screen Scale: \(UIScreen.main.scale)")
        
        // Check iOS version specific capabilities
        if #available(iOS 18.0, *) {
            print("🔍 iOS 18+ features available")
        } else if #available(iOS 17.0, *) {
            print("🔍 iOS 17+ features available")
        } else if #available(iOS 16.0, *) {
            print("🔍 iOS 16+ features available")
        } else {
            print("🔍 Older iOS version")
        }
        print("🔍 === END DEBUG INFO ===")
    }
    
    private func handleGroupNavigation(group: Group) {
        print("📱 🏠 === UNIVERSAL NAVIGATION TRIGGERED ===")
        print("📱 🏠 Group: \(group.name)")
        
        // Debug device and OS info
        debugDeviceAndOS()
        
        // Add haptic feedback for immediate user feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        print("📱 🏠 Haptic feedback triggered")
        
        // Add authentication check before navigation
        if let currentUser = Auth.auth().currentUser {
            print("📱 🏠 ✅ User authenticated: \(currentUser.uid)")
            print("📱 🏠 User email: \(currentUser.email ?? "no email")")
            
            // Use notification-based navigation
            print("📱 🏠 🚀 Posting navigation notification...")
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToGroupFromList"),
                object: nil,
                userInfo: ["groupId": group.id]
            )
            print("📱 🏠 ✅ Navigation notification posted successfully")
        } else {
            print("📱 🏠 ❌ USER NOT AUTHENTICATED - Cannot navigate to group")
            print("📱 🏠 This might be why navigation isn't working on some devices")
            
            // Create visual feedback to show the tap was detected even if auth fails
            print("📱 🏠 🔄 Attempting anonymous authentication...")
            Auth.auth().signInAnonymously { result, error in
                if let error = error {
                    print("📱 🏠 ❌ Auth error: \(error.localizedDescription)")
                } else if let user = result?.user {
                    print("📱 🏠 ✅ Anonymous auth successful: \(user.uid)")
                    DispatchQueue.main.async {
                        // Use notification-based navigation after auth
                        print("📱 🏠 🚀 Posting navigation notification after auth...")
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NavigateToGroupFromList"),
                            object: nil,
                            userInfo: ["groupId": group.id]
                        )
                        print("📱 🏠 ✅ Navigation notification posted successfully after auth")
                    }
                }
            }
        }
        print("📱 🏠 === UNIVERSAL NAVIGATION COMPLETED ===")
    }
    
    private func handleGroupLongPress(group: Group) {
        print("📱 🏠 === RELIABLE LONG PRESS TRIGGERED ===")
        print("📱 🏠 Group: \(group.name)")
        
        groupToLeave = group
        showLeaveConfirmation = true
        print("📱 🏠 ✅ Long press action completed")
    }
    
    private func handleInitialSetup() {
        // Remove automatic sheet trigger - let users choose to create groups manually
        // This was causing unwanted popups when switching between user accounts
        print("📋 GroupListView: Initial setup - user has \(groupStore.groups.count) groups")
    }
    
    private func checkCameraPermission() {
        // Show helpful message directing users to their active circles
        showPermissionAlert = true
    }
    
    // Add function to get dynamic status for each group
    private func getGroupStatus(for group: Group) -> (message: String, color: Color) {
        // Use lastRefresh to ensure this recalculates when timer triggers
        let _ = lastRefresh
        
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        let isInfluencer = group.currentInfluencerId == currentUserId
        
        // Use cached EntryStore or create new one and cache it
        let entryStore: EntryStore
        if let cachedStore = entryStoreCache[group.id] {
            entryStore = cachedStore
        } else {
            entryStore = EntryStore(groupId: group.id)
            entryStoreCache[group.id] = entryStore
            
            // For new EntryStore instances, show loading state initially
            // Give it a moment to load data before showing the "no entries" state
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // Force a refresh after EntryStore has had time to load
                lastRefresh = Date()
            }
        }
        
        // Check if EntryStore is still loading (entries array is empty but it's a new instance)
        if entryStore.entries.isEmpty {
            // Check if this is a newly created EntryStore that might still be loading
            if !entryStoreCache.keys.contains(group.id) || entryStore.entries.count == 0 {
                // Could be loading, show a neutral message
                if isInfluencer {
                    return ("⏳ Loading your DIML...", .gray)
                } else {
                    return ("⏳ Loading chat...", .gray)
                }
            }
        }
        
        // Get the most recent entry to see what was just shared
        if let mostRecentEntry = entryStore.entries.max(by: { $0.timestamp < $1.timestamp }) {
            let influencerName = group.members.first(where: { $0.id == group.currentInfluencerId })?.name ?? "Someone"
            
            // Check if next prompt should be available
            let nextPromptTime = calculateNextPromptTime(for: group, lastEntry: mostRecentEntry)
            let isNewPromptReady = nextPromptTime <= Date()
            
            if isNewPromptReady && isInfluencer {
                return ("🎉 Your next DIML prompt is ready to answer!", Color(red: 1.0, green: 0.815, blue: 0.0))
            } else if isNewPromptReady && !isInfluencer {
                return ("👀 Check for new updates!", .blue)
            } else {
                // Show what was recently shared
                let timeSince = Date().timeIntervalSince(mostRecentEntry.timestamp)
                let prompt = mostRecentEntry.prompt
                
                // Create a more engaging description based on the prompt
                let activityDescription = getActivityDescription(prompt: prompt, influencerName: influencerName, isInfluencer: isInfluencer)
                
                if timeSince < 3600 { // Within last hour
                    return (activityDescription, .green)
                } else if timeSince < 86400 { // Within last day
                    let hours = Int(timeSince / 3600)
                    return ("\(activityDescription) • \(hours)h ago", .gray)
                } else {
                    let days = Int(timeSince / 86400)
                    return ("\(activityDescription) • \(days)d ago", .gray)
                }
            }
        } else {
            // No entries yet (after loading is complete)
            if isInfluencer {
                return ("🌟 Start your day in the life!", Color(red: 1.0, green: 0.815, blue: 0.0))
            } else {
                return ("👋 Waiting for first post!", .gray)
            }
        }
    }
    
    private func getActivityDescription(prompt: String, influencerName: String, isInfluencer: Bool) -> String {
        let name = isInfluencer ? "You" : influencerName
        
        // Create contextual descriptions based on prompt content
        let lowerPrompt = prompt.lowercased()
        
        if lowerPrompt.contains("morning") {
            return "\(name) shared their morning"
        } else if lowerPrompt.contains("coffee") || lowerPrompt.contains("drink") {
            return "\(name) showed us their drink"
        } else if lowerPrompt.contains("workout") || lowerPrompt.contains("exercise") || lowerPrompt.contains("gym") {
            return "\(name) shared their workout"
        } else if lowerPrompt.contains("food") || lowerPrompt.contains("eat") || lowerPrompt.contains("meal") {
            return "\(name) showed us their meal"
        } else if lowerPrompt.contains("outfit") || lowerPrompt.contains("wear") || lowerPrompt.contains("clothes") {
            return "\(name) shared their outfit"
        } else if lowerPrompt.contains("music") || lowerPrompt.contains("song") || lowerPrompt.contains("listen") {
            return "\(name) shared their music"
        } else if lowerPrompt.contains("work") || lowerPrompt.contains("office") || lowerPrompt.contains("meeting") {
            return "\(name) showed us their work"
        } else if lowerPrompt.contains("friend") || lowerPrompt.contains("people") || lowerPrompt.contains("hang") {
            return "\(name) shared time with friends"
        } else if lowerPrompt.contains("color") || lowerPrompt.contains("feeling") || lowerPrompt.contains("mood") {
            return "\(name) shared their vibe"
        } else if lowerPrompt.contains("home") || lowerPrompt.contains("room") || lowerPrompt.contains("space") {
            return "\(name) showed us their space"
        } else if lowerPrompt.contains("outside") || lowerPrompt.contains("walk") || lowerPrompt.contains("nature") {
            return "\(name) shared their adventure"
        } else if lowerPrompt.contains("evening") || lowerPrompt.contains("night") {
            return "\(name) shared their evening"
        } else if lowerPrompt.contains("afternoon") {
            return "\(name) shared their afternoon"
        } else {
            // Generic fallback
            return "\(name) shared their day"
        }
    }
    
    private func calculateNextPromptTime(for group: Group, lastEntry: DIMLEntry) -> Date {
        let calendar = Calendar.current
        let frequency = group.promptFrequency
        
        // Handle testing mode (1 minute intervals)
        if frequency == .testing {
            return calendar.date(byAdding: .minute, value: 1, to: lastEntry.timestamp) ?? lastEntry.timestamp
        }
        
        // For regular frequencies, use the actual interval hours from the enum
        let intervalHours = frequency.intervalHours
        
        // Calculate the next prompt time by adding the correct interval
        let nextPromptTime = calendar.date(byAdding: .hour, value: intervalHours, to: lastEntry.timestamp) ?? lastEntry.timestamp
        
        // ALWAYS respect the exact frequency interval - no active hours restriction
        return nextPromptTime
    }
    
    struct AnimatedMoonView: View {
        @Binding var isRefreshing: Bool
        @State private var moonOffset: CGFloat = 0
        @State private var z1Offset: CGFloat = 0
        @State private var z2Offset: CGFloat = 0
        @State private var z3Offset: CGFloat = 0
        @State private var moonScale: CGFloat = 1.0
        
        var body: some View {
            Image(systemName: "moon.zzz")
                .resizable()
                .frame(width: 200, height: 225)
                .foregroundColor(.gray.opacity(0.4))
                .offset(y: moonOffset)
                .scaleEffect(moonScale)
                .onChange(of: isRefreshing) { isRefreshing in
                    if isRefreshing {
                        startAnimation()
                    } else {
                        stopAnimation()
                    }
                }
        }
        
        private func startAnimation() {
            // Continuous moon bounce and scale
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                moonOffset = -30  // More pronounced bounce
                moonScale = 1.1   // Slight grow effect
            }
            
            // Start Z animations
            animateZs()
        }
        
        private func stopAnimation() {
            withAnimation(.easeInOut) {
                moonOffset = 0
                moonScale = 1.0
                z1Offset = 0
                z2Offset = 0
                z3Offset = 0
            }
        }
        
        private func animateZs() {
            guard isRefreshing else { return }
            
            // First Z - higher and with scale
            withAnimation(.easeInOut(duration: 1.0)) {
                z1Offset = -50
            }
            
            // Second Z
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    z2Offset = -50
                }
            }
            
            // Third Z
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    z3Offset = -50
                }
            }
            
            // Reset and repeat with slight pause
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    z1Offset = 0
                    z2Offset = 0
                    z3Offset = 0
                }
                
                // Continue if still refreshing with a slight pause
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if isRefreshing {
                        animateZs()
                    }
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
                // ✅ Reusable Top Nav
                TopNavBar(showsMenu: false)
                
                // Title and Action Menu - Fixed spacing and alignment
                HStack(alignment: .center) {
                    Text("Your Circles")
                        .font(.custom("Fredoka-Medium", size: 32))
                        .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                    
                    Spacer()
                    
                    // Cleaner plus button with friend indicator
                    Menu {
                        Button("Create a Circle") {
                            showingCreateGroup = true
                        }
                        Button("Add Friends") {
                            showingAddFriends = true
                        }
                    } label: {
                        ZStack {
                            Image(systemName: "plus.circle")
                                .resizable()
                                .frame(width: 26, height: 26)
                                .foregroundColor(.gray)
                            
                            // Friend request indicator badge - show different states
                            if hasPendingRequests {
                                // Red badge with count for pending requests
                                ZStack {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 16, height: 16)
                                    
                                    Text("\(pendingRequestCount)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .minimumScaleFactor(0.5)
                                }
                                .offset(x: 12, y: -12)
                            } else if hasRecentFriendActivity {
                                // Green checkmark for recent activity (accepted/declined)
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 12, height: 12)
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 7, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                    .offset(x: 12, y: -12)
                                    .onAppear {
                                        // Auto-hide the activity indicator after 3 seconds
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                            withAnimation(.easeOut(duration: 0.5)) {
                                                hasRecentFriendActivity = false
                                            }
                                        }
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                // Search Bar - improved spacing
                HStack {
                    TextField("Search", text: $searchText)
                        .focused($isSearchFocused)
                        .foregroundColor(.black) // Fixed dark color for visibility in all modes
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                
                // Divider - cleaner appearance
                Divider()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                
                // Main Content
                if groupStore.groups.isEmpty {
                    ScrollView {
                        VStack(spacing: 10) {
                            AnimatedMoonView(isRefreshing: $isRefreshing)
                                .padding(.bottom, 20)
                            
                            Text("You have no Circles.")
                                .font(.custom("Fredoka-Regular", size: 22))
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                            
                            Text("Tap the ⊕ in the upper right corner\nto create a Circle!")
                                .multilineTextAlignment(.center)
                                .font(.custom("Markazi Text", size: 18))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                    }
                } else {
                    List {
                        ForEach(groupStore.groups) { group in
                            ZStack {
                                GroupRowContent(
                                    group: group,
                                    groupStore: groupStore,
                                    getGroupStatus: getGroupStatus
                                )
                                
                                // iOS 16 compatible touch handler
                                UIKitTouchHandler(group: group) { tappedGroup in
                                    print("📱 🎯 === UIKIT TOUCH TRIGGERED ===")
                                    print("📱 🎯 Group: \(tappedGroup.name)")
                                    print("📱 🎯 iOS Version: \(UIDevice.current.systemVersion)")
                                    
                                    // Visual feedback (can be removed for production)
                                    tapDebugMessage = "✅ Touch Working"
                                    showTapDebugMessage = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        showTapDebugMessage = false
                                    }
                                    
                                    handleGroupNavigation(group: tappedGroup)
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .simultaneousGesture(
                                // Additional SwiftUI gesture as backup
                                TapGesture()
                                    .onEnded { _ in
                                        print("📱 🔄 === SIMULTANEOUS GESTURE TRIGGERED ===")
                                        print("📱 🔄 Group: \(group.name)")
                                        print("📱 🔄 iOS Version: \(UIDevice.current.systemVersion)")
                                        
                                        // Backup gesture feedback
                                        tapDebugMessage = "✅ Backup Touch"
                                        showTapDebugMessage = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                            showTapDebugMessage = false
                                        }
                                        
                                        // Small delay to avoid conflict with UIKit handler
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                            handleGroupNavigation(group: group)
                                        }
                                    }
                            )
                            .onLongPressGesture(minimumDuration: 1.0) {
                                print("🔴 DEBUG: Long press detected for group: \(group.name)")
                                
                                // Add haptic feedback to confirm the long press was detected
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                
                                groupToLeave = group
                                showLeaveConfirmation = true
                                print("🔴 DEBUG: showLeaveConfirmation set to: \(showLeaveConfirmation)")
                                print("🔴 DEBUG: groupToLeave set to: \(group.name)")
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.clear)
                    .refreshable {
                        isRefreshing = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            isRefreshing = false
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        // Add bottom safe area inset to ensure last group is visible
                        Spacer()
                            .frame(height: 100) // Generous bottom padding for tab bar and safe area
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isSearchFocused)
            .background(Color(red: 1, green: 0.989, blue: 0.93).ignoresSafeArea())
            .navigationBarHidden(true)
            .confirmationDialog(
                "Leave Circle",
                isPresented: $showLeaveConfirmation,
                presenting: groupToLeave
            ) { group in
                Button("Leave \(group.name)", role: .destructive) {
                    print("🔴 DEBUG: Confirmation dialog Leave button tapped for group: \(group.name)")
                    let success = groupStore.leaveGroup(group)
                    print("🔴 DEBUG: leaveGroup result: \(success)")
                    if success {
                        print("✅ Successfully left group: \(group.name)")
                        
                        // Add haptic feedback for successful leaving
                        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                        impactFeedback.impactOccurred()
                    } else {
                        print("❌ Failed to leave group: \(group.name)")
                    }
                }
                Button("Cancel", role: .cancel) { 
                    print("🔴 DEBUG: Confirmation dialog Cancel button tapped")
                }
            } message: { group in
                if group.members.count <= 1 {
                    Text("You are the only member of '\(group.name)'. Leaving will delete the entire circle permanently and all chat history will be lost.")
                } else {
                    Text("Are you sure you want to leave '\(group.name)'?\n\nThis will remove the circle from your list and you'll need to be invited back to rejoin. Other members will see that you've left.")
                }
            }
            .onChange(of: showLeaveConfirmation) { isShowing in
                print("🔴 DEBUG: showLeaveConfirmation changed to: \(isShowing)")
                if isShowing {
                    print("🔴 DEBUG: groupToLeave is: \(groupToLeave?.name ?? "nil")")
                }
            }
            .onChange(of: groupToLeave) { group in
                print("🔴 DEBUG: groupToLeave changed to: \(group?.name ?? "nil")")
            }
            .sheet(isPresented: $showingCreateGroup) {
                CreateGroupView { newGroup in
                    groupStore.addGroup(newGroup)
                }
            }
            .sheet(isPresented: $showingAddFriends) {
                AddFriendsView()
            }
            .sheet(isPresented: $showCamera) {
                CameraView(isPresented: $showCamera) { image in
                    print("Image captured")
                }
            }
            .alert(isPresented: $showPermissionAlert) {
                Alert(
                    title: Text("📱 Camera for DIML"),
                    message: Text("To take photos for your prompts, enter one of your circles! Only today's influencer can snap pictures for their group."),
                    dismissButton: .default(Text("Got it!"))
                )
            }
            .modifier(ScrollDismissKeyboardModifier(.immediately))
            // Remove contentShape to prevent interfering with swipe gestures
            .onTapGesture {
                // Only dismiss keyboard if search is focused
                if isSearchFocused {
                    isSearchFocused = false
                }
            }
            .ignoresSafeArea(.keyboard)
            .tutorialOverlay(tutorialManager: tutorialManager, tutorialID: "onboarding")
            .onAppear {
                print("🎯 GroupListView: onAppear called")
                handleInitialSetup()
                
                // Check if this is a first-time user who should see the tutorial
                if tutorialManager.shouldShowTutorial(for: "onboarding") {
                    print("🎯 GroupListView: Tutorial should show - starting tutorial for new user")
                    
                    // Start tutorial after a brief delay to ensure view is fully loaded
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        let steps = TutorialManager.createOnboardingTutorial()
                        print("🎯 GroupListView: Created \(steps.count) tutorial steps")
                        tutorialManager.startTutorial(steps: steps)
                        print("🎯 GroupListView: Tutorial started, isShowingTutorial = \(tutorialManager.isShowingTutorial)")
                    }
                } else {
                    print("🎯 GroupListView: Tutorial should NOT show (already completed)")
                }
                
                // Initialize friend request manager
                friendRequestManager.startListening()
                
                // Debug friend request status
                print("🤝 GroupListView: Friend request status on appear")
                print("🤝 Pending requests: \(friendRequestManager.pendingRequests.count)")
                print("🤝 Sent requests: \(friendRequestManager.sentRequests.count)")
                for request in friendRequestManager.pendingRequests {
                    print("🤝 Pending: from \(request.from), status: \(request.status)")
                }
                
                // Pre-load EntryStore instances for all groups to avoid loading delays
                for group in groupStore.groups {
                    if entryStoreCache[group.id] == nil {
                        print("📋 Pre-loading EntryStore for group: \(group.name)")
                        entryStoreCache[group.id] = EntryStore(groupId: group.id)
                    }
                }
                
                // Start status refresh timer
                statusRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
                    // Force view refresh by updating a state variable
                    DispatchQueue.main.async {
                        // This will trigger a re-render and update the status messages
                        lastRefresh = Date()
                    }
                }
                
                // Setup keyboard notifications
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
                    withAnimation {
                        keyboardVisible = true
                    }
                }
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                    withAnimation {
                        keyboardVisible = false
                    }
                }
                
                // Setup friend request activity observers
                NotificationCenter.default.addObserver(forName: NSNotification.Name("FriendRequestAccepted"), object: nil, queue: .main) { _ in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        hasRecentFriendActivity = true
                    }
                }
                NotificationCenter.default.addObserver(forName: NSNotification.Name("FriendRequestDeclined"), object: nil, queue: .main) { _ in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        hasRecentFriendActivity = true
                    }
                }
            }
            .onDisappear {
                // Stop the timer when view disappears
                statusRefreshTimer?.invalidate()
                statusRefreshTimer = nil
            }
            .overlay(
                // Debug message overlay
                VStack {
                    if showTapDebugMessage {
                        Text(tapDebugMessage)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Spacer()
                }
                .padding(.top, 100)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showTapDebugMessage)
            )
    }
}

// Custom RefreshableScrollView
struct RefreshableScrollView<Content: View>: View {
    let onRefresh: (@escaping () -> Void) -> Void
    let content: Content
    
    init(onRefresh: @escaping (@escaping () -> Void) -> Void, @ViewBuilder content: () -> Content) {
        self.onRefresh = onRefresh
        self.content = content()
    }
    
    var body: some View {
        ScrollView {
            GeometryReader { geometry in
                let offset = geometry.frame(in: .global).minY
                Color.clear.preference(key: ScrollViewOffsetPreferenceKey.self, value: offset)
            }
            .frame(height: 0)
            .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { offset in
                if offset > 70 {
                    onRefresh {
                        // Refresh complete
                    }
                }
            }
            
            content
        }
    }
}

// Preference key for tracking scroll offset
private struct ScrollViewOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - UIKit Touch Handler for iOS 16 Compatibility
struct UIKitTouchHandler: UIViewRepresentable {
    let group: Group
    let onTap: (Group) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = TouchDebugView()
        view.backgroundColor = UIColor.clear
        view.group = group
        
        // Create tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.numberOfTouchesRequired = 1
        tapGesture.delegate = context.coordinator
        view.addGestureRecognizer(tapGesture)
        
        print("🎯 UIKitTouchHandler: Created for group \(group.name)")
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(group: group, onTap: onTap)
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let group: Group
        let onTap: (Group) -> Void
        
        init(group: Group, onTap: @escaping (Group) -> Void) {
            self.group = group
            self.onTap = onTap
        }
        
        @objc func handleTap() {
            print("🎯 UIKit tap gesture recognized for group: \(group.name)")
            
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            // Trigger the callback
            DispatchQueue.main.async {
                self.onTap(self.group)
            }
        }
        
        // Allow simultaneous gestures
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            print("🎯 Gesture delegate: shouldRecognizeSimultaneouslyWith called")
            return true
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            print("🎯 Gesture delegate: shouldReceive touch for group \(group.name)")
            return true
        }
    }
}

// Custom UIView for touch debugging
class TouchDebugView: UIView {
    var group: Group?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("🎯 TouchDebugView: touchesBegan for group \(group?.name ?? "unknown")")
        super.touchesBegan(touches, with: event)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("🎯 TouchDebugView: touchesEnded for group \(group?.name ?? "unknown")")
        super.touchesEnded(touches, with: event)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("🎯 TouchDebugView: touchesCancelled for group \(group?.name ?? "unknown")")
        super.touchesCancelled(touches, with: event)
    }
}

// MARK: - GroupRowContent Component
struct GroupRowContent: View {
    let group: Group
    let groupStore: GroupStore
    let getGroupStatus: (Group) -> (message: String, color: Color)
    @State private var isPressed = false // For visual feedback
    
    var body: some View {
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        let otherMembers = group.members.filter { $0.id != currentUserId }
        let displayMembers = Array(otherMembers.prefix(3)) // Show up to 3 members
        
        HStack(spacing: 12) {
            HStack(spacing: -8) {
                ForEach(displayMembers, id: \.id) { member in
                    ProfilePictureView(userId: member.id, size: 40, groupMembers: group.members)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
                
                // Show a "+" circle if there are more than 3 other members
                if otherMembers.count > 3 {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Text("+\(otherMembers.count - 3)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gray)
                        )
                        .frame(width: 40, height: 40)
                }
                
                // If no other members (only current user), show a single placeholder
                if displayMembers.isEmpty {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        )
                        .frame(width: 40, height: 40)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.custom("Fredoka-Regular", size: 18))
                    .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                
                let status = getGroupStatus(group)
                Text(status.message)
                    .font(.custom("Markazi Text", size: 16))
                    .foregroundColor(status.color)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("10:28 PM")
                    .font(.footnote)
                    .foregroundColor(.gray)
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(minHeight: 88) // Increased minimum height for better touch targets
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isPressed ? 
                    Color(red: 0.95, green: 0.94, blue: 0.92) : // Darker when pressed
                    Color(red: 0.98, green: 0.97, blue: 0.95)   // Normal color
                )
                .shadow(color: Color.black.opacity(isPressed ? 0.1 : 0.05), radius: isPressed ? 6 : 4, x: 0, y: 2)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0) // Subtle scale effect when pressed
        .animation(.easeInOut(duration: 0.1), value: isPressed) // Smooth animation
        .contentShape(Rectangle()) // Ensure entire area is tappable
        .accessibility(addTraits: .isButton) // Improve accessibility for screen readers
        .accessibility(label: Text("Chat group: \(group.name)")) // Add accessibility label
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        // Immediate haptic feedback when touch begins
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Preview
struct GroupListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GroupListView()
        }
    }
}


