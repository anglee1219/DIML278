import SwiftUI
import AVFoundation

struct MainTabView: View {
    @State private var currentTab: Tab
    @State private var showCamera = false
    @State private var showPermissionAlert = false
    @State private var keyboardVisible = false
    @StateObject private var authManager = AuthenticationManager.shared
    @EnvironmentObject var groupStore: GroupStore
    
    // Notification navigation state
    @State private var shouldNavigateToGroup = false
    @State private var targetGroupId: String?
    @State private var shouldTriggerUnlock = false
    @State private var notificationUserInfo: [String: Any] = [:]
    
    init(currentTab: Tab = .home) {
        _currentTab = State(initialValue: currentTab)
    }

    // Handle camera permission
    func checkCameraPermission() {
        // Show helpful message directing users to their circles
        showPermissionAlert = true
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Show group if navigating from notification OR normal tab content
                if shouldNavigateToGroup, let groupId = targetGroupId {
                    GroupDetailViewWrapper(
                        groupId: groupId,
                        groupStore: groupStore,
                        shouldTriggerUnlock: shouldTriggerUnlock,
                        notificationUserInfo: notificationUserInfo
                    )
                } else {
                    // Normal tab content only when NOT navigating from notification
                    switch currentTab {
                    case .home:
                        GroupListView()
                            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToGroupFromList"))) { notification in
                                // Handle navigation from GroupListView when user taps a group normally
                                print("📱 🏠 GroupListView navigation received")
                                
                                if let userInfo = notification.userInfo,
                                   let groupId = userInfo["groupId"] as? String {
                                    print("📱 🏠 Navigating to group: \(groupId)")
                                    
                                    // Clear notification states for normal navigation
                                    self.targetGroupId = groupId
                                    self.shouldTriggerUnlock = false
                                    self.notificationUserInfo = [:]
                                    self.shouldNavigateToGroup = true
                                }
                            }
                    case .profile:
                        ProfileView()
                    case .camera:
                        EmptyView() // Camera doesn't have its own screen
                    }

                    // Bottom NavBar - only show when not in group view
                    VStack {
                        Spacer()
                        if !keyboardVisible {
                            BottomNavBar(currentTab: $currentTab) {
                                checkCameraPermission()
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToGroupAndUnlock"))) { notification in
            print("🔔 🎯 MainTabView received NavigateToGroupAndUnlock")
            
            guard let userInfo = notification.userInfo,
                  let groupId = userInfo["groupId"] as? String else {
                print("🔔 🎯 ❌ Missing required data in MainTabView navigation")
                return
            }
            
            print("🔔 🎯 MainTabView navigating to group: \(groupId)")
            
            DispatchQueue.main.async {
                self.targetGroupId = groupId
                self.shouldTriggerUnlock = true
                self.notificationUserInfo = userInfo as? [String: Any] ?? [:]
                
                // Clear any existing notification state first
                self.shouldNavigateToGroup = false
                
                // Then trigger navigation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.shouldNavigateToGroup = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToGroup"))) { notification in
            print("🔔 📸 MainTabView received NavigateToGroup")
            
            guard let userInfo = notification.userInfo,
                  let groupId = userInfo["groupId"] as? String else {
                print("🔔 📸 ❌ Missing required data in MainTabView navigation")
                return
            }
            
            print("🔔 📸 MainTabView navigating to group: \(groupId)")
            
            DispatchQueue.main.async {
                self.targetGroupId = groupId
                self.shouldTriggerUnlock = false
                self.notificationUserInfo = userInfo as? [String: Any] ?? [:]
                
                // Clear any existing notification state first
                self.shouldNavigateToGroup = false
                
                // Then trigger navigation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.shouldNavigateToGroup = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetMainTabNavigation"))) { _ in
            print("🔔 🔄 MainTabView received ResetMainTabNavigation")
            
            DispatchQueue.main.async {
                // Reset all navigation state
                self.shouldNavigateToGroup = false
                self.targetGroupId = nil
                self.shouldTriggerUnlock = false
                self.notificationUserInfo = [:]
                print("🔔 🔄 MainTabView navigation state reset - back to normal tabs")
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView(isPresented: $showCamera) { image in
                print("Image captured")
                // Handle image save if needed
            }
        }
        .alert(isPresented: $showPermissionAlert) {
            Alert(
                title: Text("📱 Camera for DIML"),
                message: Text("To take photos for your prompts, go to one of your circles! Only today's influencer can snap pictures for their group."),
                dismissButton: .default(Text("Got it!"))
            )
        }
    }
}
