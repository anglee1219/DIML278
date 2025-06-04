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
    @State private var showingCreateGroup = false
    @State private var showingAddFriends = false
    @State private var showCamera = false
    @State private var showPermissionAlert = false
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var isRefreshing = false
    @State private var groupToLeave: Group?
    @State private var showLeaveConfirmation = false
    @State private var swipedGroupId: String?
    @State private var offset: CGFloat = 0
    @State private var isNavigating = false
    @State private var keyboardVisible = false
    @State private var statusRefreshTimer: Timer?
    @State private var lastRefresh = Date() // Force view updates for status changes
    
    private func handleInitialSetup() {
        if groupStore.groups.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingCreateGroup = true
            }
        }
    }
    
    private func checkCameraPermission() {
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
    
    // Add function to get dynamic status for each group
    private func getGroupStatus(for group: Group) -> (message: String, color: Color) {
        // Use lastRefresh to ensure this recalculates when timer triggers
        let _ = lastRefresh
        
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        let isInfluencer = group.currentInfluencerId == currentUserId
        
        // Create a mock entry store to check for recent activity (in real app, this would be from GroupStore)
        let entryStore = EntryStore(groupId: group.id)
        
        // Get the most recent entry to see what was just shared
        if let mostRecentEntry = entryStore.entries.max(by: { $0.timestamp < $1.timestamp }) {
            let influencerName = group.members.first(where: { $0.id == group.currentInfluencerId })?.name ?? "Someone"
            
            // Check if next prompt should be available
            let nextPromptTime = calculateNextPromptTime(for: group, lastEntry: mostRecentEntry)
            let isNewPromptReady = nextPromptTime <= Date()
            
            if isNewPromptReady && isInfluencer {
                return ("✨ New prompt ready to answer!", Color(red: 1.0, green: 0.815, blue: 0.0))
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
            // No entries yet
            if isInfluencer {
                return ("🌟 Start your first DIML!", Color(red: 1.0, green: 0.815, blue: 0.0))
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
        let intervalMinutes = group.promptFrequency.intervalMinutes
        
        if group.promptFrequency == .testing {
            return calendar.date(byAdding: .minute, value: 1, to: lastEntry.timestamp) ?? lastEntry.timestamp
        } else {
            return calendar.date(byAdding: .minute, value: intervalMinutes, to: lastEntry.timestamp) ?? lastEntry.timestamp
        }
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
        if #available(iOS 16.0, *) {
            VStack(spacing: 0) {
                // ✅ Reusable Top Nav
                TopNavBar(showsMenu: false)
                
                // Title and Action Menu
                HStack {
                    Text("Your Circles")
                        .font(.custom("Fredoka-Medium", size: 32))
                        .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                    
                    Spacer()
                    Menu {
                        Button("Create a Circle") {
                            showingCreateGroup = true
                        }
                        Button("Add Friends") {
                            showingAddFriends = true
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                            .resizable()
                            .frame(width: 25, height: 25)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
                
                // Search Bar
                HStack {
                    TextField("Search", text: $searchText)
                        .focused($isSearchFocused)
                        .padding(5)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(6)
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                
                Divider()
                    .padding(.top, 10)
                    .padding(.horizontal, 24)
                
                // Main Content
                ScrollView {
                    RefreshableScrollView(onRefresh: { done in
                        // Start refreshing
                        isRefreshing = true
                        
                        // Simulate refresh delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            isRefreshing = false
                            done()
                        }
                    }) {
                        if groupStore.groups.isEmpty {
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
                        } else {
                            VStack(spacing: 20) {
                                ForEach(groupStore.groups) { group in
                                    ZStack(alignment: .trailing) {
                                        // Leave Button
                                        Button {
                                            groupToLeave = group
                                            showLeaveConfirmation = true
                                            withAnimation {
                                                swipedGroupId = nil
                                                offset = 0
                                            }
                                        } label: {
                                            HStack {
                                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                                Text("Leave")
                                            }
                                            .foregroundColor(.white)
                                            .frame(width: 80, height: 70)
                                            .background(Color.red)
                                        }
                                        .offset(x: swipedGroupId == group.id ? 0 : 80)
                                        .opacity(swipedGroupId == group.id ? 1 : 0)
                                        
                                        // Main Content
                                        HStack {
                                            NavigationLink(destination: GroupDetailViewWrapper(groupId: group.id, groupStore: groupStore)) {
                                                HStack(spacing: 12) {
                                                    HStack(spacing: -8) {
                                                        ForEach(0..<min(3, group.members.count), id: \.self) { _ in
                                                            Circle()
                                                                .fill(Color.gray.opacity(0.3))
                                                                .frame(width: 40, height: 40)
                                                        }
                                                    }
                                                    
                                                    VStack(alignment: .leading) {
                                                        Text(group.name)
                                                            .font(.custom("Fredoka-Regular", size: 18))
                                                            .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                                                        
                                                        let status = getGroupStatus(for: group)
                                                        Text(status.message)
                                                            .font(.custom("Markazi Text", size: 16))
                                                            .foregroundColor(status.color)
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    VStack(alignment: .trailing) {
                                                        Text("10:28 PM")
                                                            .font(.footnote)
                                                            .foregroundColor(.gray)
                                                        
                                                        Image(systemName: "chevron.right")
                                                            .foregroundColor(.gray.opacity(0.6))
                                                    }
                                                }
                                                .padding(.horizontal)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color(red: 0.98, green: 0.97, blue: 0.95))
                                                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                                                )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .simultaneousGesture(
                                                TapGesture()
                                                    .onEnded { _ in
                                                        if swipedGroupId == group.id {
                                                            withAnimation {
                                                                swipedGroupId = nil
                                                                offset = 0
                                                            }
                                                        }
                                                    }
                                            )
                                        }
                                        .offset(x: swipedGroupId == group.id ? -80 : 0)
                                        .gesture(
                                            DragGesture()
                                                .onChanged { gesture in
                                                    if gesture.translation.width < 0 {
                                                        withAnimation {
                                                            swipedGroupId = group.id
                                                            offset = -80
                                                        }
                                                    } else if gesture.translation.width > 0 {
                                                        withAnimation {
                                                            swipedGroupId = nil
                                                            offset = 0
                                                        }
                                                    }
                                                }
                                                .onEnded { _ in
                                                    withAnimation {
                                                        if offset < -40 {
                                                            swipedGroupId = group.id
                                                            offset = -80
                                                        } else {
                                                            swipedGroupId = nil
                                                            offset = 0
                                                        }
                                                    }
                                                }
                                        )
                                    }
                                    .padding(.horizontal)
                                    .background(Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding(.top, 20)
                        }
                    }
                }
                .refreshable {
                    isRefreshing = true
                    // Add your refresh logic here
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        isRefreshing = false
                    }
                }
                .confirmationDialog(
                    "Leave Circle",
                    isPresented: $showLeaveConfirmation,
                    presenting: groupToLeave
                ) { group in
                    Button("Leave \(group.name)", role: .destructive) {
                        withAnimation {
                            groupStore.deleteGroup(group)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { group in
                    Text("Are you sure you want to leave '\(group.name)'?\nYou'll need to be invited back to rejoin.")
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isSearchFocused)
            .background(Color(red: 1, green: 0.989, blue: 0.93).ignoresSafeArea())
            .navigationBarHidden(true)
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
                    title: Text("Camera Access Required"),
                    message: Text("Please enable camera access in Settings to take photos."),
                    primaryButton: .default(Text("Settings"), action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }),
                    secondaryButton: .cancel()
                )
            }
            .scrollDismissesKeyboard(.immediately)
            .contentShape(Rectangle())
            .onTapGesture {
                isSearchFocused = false
            }
            .ignoresSafeArea(.keyboard)
            .onAppear {
                handleInitialSetup()
                
                // Start status refresh timer
                statusRefreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
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
            }
            .onDisappear {
                // Stop the timer when view disappears
                statusRefreshTimer?.invalidate()
                statusRefreshTimer = nil
            }
        } else {
            // Fallback on earlier versions
        }
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

// MARK: - Preview
struct GroupListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GroupListView()
        }
    }
}
