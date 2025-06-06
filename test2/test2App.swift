import SwiftUI
import FirebaseCore
import FirebaseAuth
import UserNotifications
import FirebaseFirestore
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Firebase only if not already configured
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // Set up Firebase Cloud Messaging
        Messaging.messaging().delegate = self
        
        // Set up notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions with all options
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .provisional]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("🔔 Notification permission granted")
                    // Register for remote notifications
                    UIApplication.shared.registerForRemoteNotifications()
                    
                    // Check current settings after permission granted
                    UNUserNotificationCenter.current().getNotificationSettings { settings in
                        print("🔔 === Initial Notification Settings ===")
                        print("🔔 Authorization Status: \(settings.authorizationStatus.rawValue)")
                        print("🔔 Alert Setting: \(settings.alertSetting.rawValue)")
                        print("🔔 Sound Setting: \(settings.soundSetting.rawValue)")
                        print("🔔 Badge Setting: \(settings.badgeSetting.rawValue)")
                        print("🔔 Lock Screen Setting: \(settings.lockScreenSetting.rawValue)")
                        print("🔔 Notification Center Setting: \(settings.notificationCenterSetting.rawValue)")
                    }
                } else {
                    print("🔔 Notification permission denied: \(error?.localizedDescription ?? "unknown error")")
                }
            }
        }
        
        // Initialize notification manager for push notifications
        _ = NotificationManager.shared
        
        return true
    }
    
    // MARK: - FCM Token Handling
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔔 📱 === FCM TOKEN RECEIVED ===")
        print("🔔 📱 FCM Token: \(fcmToken ?? "nil")")
        
        guard let token = fcmToken else {
            print("🔔 📱 ❌ No FCM token received")
            return
        }
        
        // Save token to Firestore so we can send push notifications
        saveFCMTokenToFirestore(token: token)
    }
    
    private func saveFCMTokenToFirestore(token: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("🔔 📱 ⚠️ No authenticated user to save FCM token, will retry when user is authenticated")
            // Store token temporarily to save it later when user authenticates
            UserDefaults.standard.set(token, forKey: "pendingFCMToken")
            return
        }
        
        print("🔔 📱 💾 Saving FCM token to Firestore for user: \(userId)")
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "fcmToken": token,
            "lastTokenUpdate": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("🔔 📱 ❌ Error saving FCM token: \(error.localizedDescription)")
            } else {
                print("🔔 📱 ✅ FCM token saved successfully")
                // Clear pending token
                UserDefaults.standard.removeObject(forKey: "pendingFCMToken")
            }
        }
    }
    
    // NEW: Manual FCM token request - call this after authentication
    func requestAndSaveFCMToken() {
        print("🔔 📱 🔄 Manually requesting FCM token after authentication...")
        
        // Get current FCM token
        Messaging.messaging().token { token, error in
            if let error = error {
                print("🔔 📱 ❌ Error fetching FCM token: \(error)")
            } else if let token = token {
                print("🔔 📱 ✅ Got FCM token manually: \(String(token.suffix(8)))")
                self.saveFCMTokenToFirestore(token: token)
            } else {
                print("🔔 📱 ⚠️ No FCM token available yet")
            }
        }
        
        // Also check if we have a pending token from before authentication
        if let pendingToken = UserDefaults.standard.string(forKey: "pendingFCMToken") {
            print("🔔 📱 🔄 Found pending FCM token, saving now...")
            saveFCMTokenToFirestore(token: pendingToken)
        }
    }
    
    // MARK: - Remote Notification Registration
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("🔔 📱 🎯 Device registered for remote notifications")
        print("🔔 📱 🎯 APNS token: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
        
        // Set APNS token for FCM
        Messaging.messaging().apnsToken = deviceToken
        
        // Force request FCM token now that we have APNS token
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.forceFCMTokenRequest()
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("🔔 📱 ❌ Failed to register for remote notifications: \(error.localizedDescription)")
        print("🔔 📱 ❌ Error details: \(error)")
        
        // Try to get FCM token anyway (for testing in simulator)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.forceFCMTokenRequest()
        }
    }
    
    // Force FCM token request with retry logic
    private func forceFCMTokenRequest() {
        print("🔔 📱 🔄 === FORCING FCM TOKEN REQUEST ===")
        
        Messaging.messaging().token { token, error in
            if let error = error {
                print("🔔 📱 ❌ Error fetching FCM token: \(error)")
                
                // Retry after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    self.forceFCMTokenRequest()
                }
            } else if let token = token {
                print("🔔 📱 ✅ FCM token received: \(String(token.suffix(8)))")
                self.saveFCMTokenToFirestore(token: token)
            } else {
                print("🔔 📱 ⚠️ No FCM token available yet, retrying...")
                
                // Retry after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.forceFCMTokenRequest()
                }
            }
        }
    }
    
    // MARK: - Notification Handling
    
    // Handle notifications when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                              willPresent notification: UNNotification, 
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("🔔 === FOREGROUND NOTIFICATION ===")
        print("🔔 Title: \(notification.request.content.title)")
        print("🔔 Body: \(notification.request.content.body)")
        print("🔔 Identifier: \(notification.request.identifier)")
        print("🔔 UserInfo: \(notification.request.content.userInfo)")
        
        // Check if this is a FCM notification
        if notification.request.content.userInfo["gcm.message_id"] != nil {
            print("🔔 📱 This is a Firebase Cloud Messaging (FCM) push notification!")
        }
        
        // Log notification type for debugging
        if let notificationType = notification.request.content.userInfo["type"] as? String {
            print("🔔 Notification Type: \(notificationType)")
            
            switch notificationType {
            case "prompt_unlock", "prompt_unlocked_immediate":
                print("🔔 📝 Prompt unlock notification received")
            case "diml_upload":
                print("🔔 📸 DIML upload notification received")
            case "reaction":
                print("🔔 🎉 Reaction notification received")
            case "comment":
                print("🔔 💬 Comment notification received")
            case "friend_request":
                print("🔔 🤝 Friend request notification received")
            default:
                print("🔔 ❓ Unknown notification type: \(notificationType)")
            }
        }
        
        // Show notification even when app is in foreground with all available options
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge, .list])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    // Handle notification tap (when app is backgrounded or terminated)
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                              didReceive response: UNNotificationResponse, 
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        print("🔔 === NOTIFICATION TAPPED (APP WAS BACKGROUNDED/TERMINATED) ===")
        print("🔔 Title: \(response.notification.request.content.title)")
        print("🔔 Body: \(response.notification.request.content.body)")
        print("🔔 Identifier: \(response.notification.request.identifier)")
        print("🔔 Action Identifier: \(response.actionIdentifier)")
        print("🔔 UserInfo: \(response.notification.request.content.userInfo)")
        
        // Check if this was a push notification
        if response.notification.request.content.userInfo["gcm.message_id"] != nil {
            print("🔔 📱 🎯 User tapped a Firebase push notification! App was completely off!")
        }
        
        // Handle different notification types
        if let notificationType = response.notification.request.content.userInfo["type"] as? String {
            print("🔔 📱 Handling notification tap for type: \(notificationType)")
            
            switch notificationType {
            case "prompt_unlock", "prompt_unlocked_immediate":
                print("🔔 📝 User tapped prompt unlock notification - navigating to group chat")
                handlePromptUnlockNotification(userInfo: response.notification.request.content.userInfo)
                
            case "diml_upload":
                print("🔔 📸 User tapped DIML upload notification - should navigate to group feed")
                handleDIMLUploadNotification(userInfo: response.notification.request.content.userInfo)
                
            case "reaction":
                print("🔔 🎉 User tapped reaction notification - should navigate to specific entry")
                handleReactionNotification(userInfo: response.notification.request.content.userInfo)
                
            case "comment":
                print("🔔 💬 User tapped comment notification - should navigate to comments view")
                handleCommentNotification(userInfo: response.notification.request.content.userInfo)
                
            case "friend_request":
                print("🔔 🤝 User tapped friend request notification - should navigate to friends view")
                // Navigate to friend requests/add friends view
                handleFriendRequestNotification(userInfo: response.notification.request.content.userInfo)
                
            default:
                print("🔔 ❓ Unknown notification type tapped: \(notificationType)")
            }
        }
        
        completionHandler()
    }
    
    // Handle prompt unlock notification tap
    private func handlePromptUnlockNotification(userInfo: [AnyHashable: Any]) {
        print("🔔 🎯 === HANDLING PROMPT UNLOCK NOTIFICATION TAP ===")
        
        guard let groupId = userInfo["groupId"] as? String,
              let userId = userInfo["userId"] as? String else {
            print("🔔 🎯 ❌ Missing groupId or userId in notification")
            return
        }
        
        let groupName = userInfo["groupName"] as? String ?? "Group"
        let prompt = userInfo["prompt"] as? String ?? ""
        
        print("🔔 🎯 Group ID: \(groupId)")
        print("🔔 🎯 User ID: \(userId)")
        print("🔔 🎯 Group Name: \(groupName)")
        print("🔔 🎯 Prompt: \(prompt)")
        
        // Post notification to navigate to the group and trigger unlock
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToGroupAndUnlock"),
                object: nil,
                userInfo: [
                    "groupId": groupId,
                    "userId": userId,
                    "groupName": groupName,
                    "prompt": prompt,
                    "shouldTriggerUnlock": true
                ]
            )
        }
    }
    
    // Handle DIML upload notification tap  
    private func handleDIMLUploadNotification(userInfo: [AnyHashable: Any]) {
        print("🔔 📸 === HANDLING DIML UPLOAD NOTIFICATION TAP ===")
        
        guard let groupId = userInfo["groupId"] as? String else {
            print("🔔 📸 ❌ Missing groupId in notification")
            return
        }
        
        let uploaderName = userInfo["uploaderName"] as? String ?? "Someone"
        let prompt = userInfo["prompt"] as? String ?? ""
        
        print("🔔 📸 Group ID: \(groupId)")
        print("🔔 📸 Uploader: \(uploaderName)")
        print("🔔 📸 Prompt: \(prompt)")
        
        // Post notification to navigate to the group
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToGroup"),
                object: nil,
                userInfo: [
                    "groupId": groupId,
                    "uploaderName": uploaderName,
                    "prompt": prompt
                ]
            )
        }
    }
    
    // Handle reaction notification tap
    private func handleReactionNotification(userInfo: [AnyHashable: Any]) {
        print("🔔 🎉 === HANDLING REACTION NOTIFICATION TAP ===")
        
        guard let groupId = userInfo["groupId"] as? String else {
            print("🔔 🎉 ❌ Missing groupId in notification")
            return
        }
        
        let reactorName = userInfo["reactorName"] as? String ?? "Someone"
        let reaction = userInfo["reaction"] as? String ?? "❤️"
        
        print("🔔 🎉 Group ID: \(groupId)")
        print("🔔 🎉 Reactor: \(reactorName)")
        print("🔔 🎉 Reaction: \(reaction)")
        
        // Navigate to group (reactions are visible in feed)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToGroup"),
                object: nil,
                userInfo: [
                    "groupId": groupId,
                    "reactorName": reactorName,
                    "reaction": reaction
                ]
            )
        }
    }
    
    // Handle comment notification tap
    private func handleCommentNotification(userInfo: [AnyHashable: Any]) {
        print("🔔 💬 === HANDLING COMMENT NOTIFICATION TAP ===")
        
        guard let groupId = userInfo["groupId"] as? String else {
            print("🔔 💬 ❌ Missing groupId in notification")
            return
        }
        
        let commenterName = userInfo["commenterName"] as? String ?? "Someone"
        let commentText = userInfo["commentText"] as? String ?? ""
        
        print("🔔 💬 Group ID: \(groupId)")
        print("🔔 💬 Commenter: \(commenterName)")
        print("🔔 💬 Comment: \(commentText)")
        
        // Navigate to group (comments are visible in feed)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToGroup"),
                object: nil,
                userInfo: [
                    "groupId": groupId,
                    "commenterName": commenterName,
                    "commentText": commentText
                ]
            )
        }
    }
    
    // Handle friend request notification tap
    private func handleFriendRequestNotification(userInfo: [AnyHashable: Any]) {
        print("🔔 🤝 === HANDLING FRIEND REQUEST NOTIFICATION TAP ===")
        
        // Navigate to friend requests/add friends view
        // Implement the navigation logic here
    }
    
    // This method is called when a notification is delivered to a backgrounded app
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive notification: UNNotification) {
        print("🔔 === BACKGROUND NOTIFICATION DELIVERED ===")
        print("🔔 Title: \(notification.request.content.title)")
        print("🔔 Body: \(notification.request.content.body)")
        print("🔔 Identifier: \(notification.request.identifier)")
        print("🔔 This notification was delivered while app was backgrounded")
    }
}

@main
struct test2App: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var showOnboarding = false
    @StateObject private var groupStore = GroupStore()
    
    init() {
        // Configure Firebase first, before initializing managers that might use it
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // Initialize notification and friend request managers
        _ = NotificationManager.shared
        _ = FriendRequestManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if authManager.isCompletingProfile {
                    NavigationView {
                        BuildProfileFlowView()
                    }
                    .onAppear {
                        print("🏠 Showing BuildProfileFlowView - isCompletingProfile: \(authManager.isCompletingProfile)")
                    }
                } else if showOnboarding {
                    OnboardingTutorialView()
                        .onAppear {
                            print("🏠 Showing OnboardingTutorialView for first-time user")
                        }
                } else if authManager.isAuthenticated {
                    // iOS version-specific navigation handling
                    if #available(iOS 16.0, *) {
                        NavigationStack {
                            MainTabView(currentTab: .home)
                                .environmentObject(groupStore)
                        }
                        .onAppear {
                            print("🏠 Showing MainTabView with NavigationStack - isAuthenticated: \(authManager.isAuthenticated)")
                        }
                    } else {
                        NavigationView {
                            MainTabView(currentTab: .home)
                                .environmentObject(groupStore)
                        }
                        .navigationViewStyle(StackNavigationViewStyle())
                        .onAppear {
                            print("🏠 Showing MainTabView with NavigationView - isAuthenticated: \(authManager.isAuthenticated)")
                        }
                    }
                } else {
                    NavigationView {
                        LoginScreen()
                    }
                    .onAppear {
                        print("🏠 Showing LoginScreen - isAuthenticated: \(authManager.isAuthenticated), isCompletingProfile: \(authManager.isCompletingProfile)")
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
            .animation(.easeInOut(duration: 0.3), value: authManager.isCompletingProfile)
            .animation(.easeInOut(duration: 0.3), value: showOnboarding)
            .environmentObject(authManager)
            .environmentObject(groupStore)
            .onChange(of: authManager.isAuthenticated) { newValue in
                print("🔄 AuthState Changed - isAuthenticated: \(newValue)")
                if newValue {
                    // IMPORTANT: Request FCM token after authentication
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        delegate.requestAndSaveFCMToken()
                    }
                }
            }
            .onChange(of: authManager.isCompletingProfile) { newValue in
                print("🔄 ProfileState Changed - isCompletingProfile: \(newValue)")
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // When app comes back to foreground, refresh any missed notifications
                print("📱 App entering foreground - checking for missed notifications")
                checkForMissedNotifications()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // Clear badge when app becomes active
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
            .onAppear {
                // Request notification permissions when app first appears
                requestNotificationPermissions()
            }
        }
    }
    
    private func requestNotificationPermissions() {
        print("📱 Requesting notification permissions...")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            print("📱 Notification permission granted: \(granted)")
            if let error = error {
                print("📱 Notification permission error: \(error)")
            }
        }
    }
    
    private func checkForMissedNotifications() {
        // Check if any notifications should have fired while app was inactive
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let now = Date()
            for request in requests {
                if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                    let scheduledTime = trigger.nextTriggerDate()
                    if let scheduledTime = scheduledTime, scheduledTime <= now {
                        print("📱 Found missed notification: \(request.identifier)")
                        // Optionally trigger the notification immediately or handle the missed event
                    }
                }
            }
        }
    }
}
