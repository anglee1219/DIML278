import SwiftUI
import AVFoundation

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
    @State private var selectedGroup: Group?
    @State private var swipedGroupId: String?
    @State private var offset: CGFloat = 0
    @State private var isNavigating = false
    @State private var keyboardVisible = false
    
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
                
                // Test Button
                Button("Test Prompt System") {
                    // Test the prompt loading and selection
                    PromptManager.shared.testPromptSystem()
                    
                    // Test the scheduler
                    PromptScheduler.shared.testScheduler()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
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
                                            Button(action: {
                                                if swipedGroupId == group.id {
                                                    withAnimation {
                                                        swipedGroupId = nil
                                                        offset = 0
                                                    }
                                                } else {
                                                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                                       let window = windowScene.windows.first {
                                                        window.rootViewController = UIHostingController(
                                                            rootView: GroupDetailView(group: group, groupStore: groupStore)
                                                        )
                                                    }
                                                }
                                            }) {
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
                                                    
                                                    Text("Check out what's happening!")
                                                        .font(.custom("Markazi Text", size: 16))
                                                        .foregroundColor(.gray)
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
