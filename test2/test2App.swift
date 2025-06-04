import SwiftUI
import FirebaseCore
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        // Set up notification center delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions with all options
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .provisional]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("🔔 Notification permission granted")
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
        
        return true
    }
    
    // Handle notifications when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                              willPresent notification: UNNotification, 
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("🔔 === FOREGROUND NOTIFICATION ===")
        print("🔔 Title: \(notification.request.content.title)")
        print("🔔 Body: \(notification.request.content.body)")
        print("🔔 Identifier: \(notification.request.identifier)")
        
        // Show notification even when app is in foreground with all available options
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge, .list])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    // Handle notification tap (when app is backgrounded)
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                              didReceive response: UNNotificationResponse, 
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        print("🔔 === BACKGROUND NOTIFICATION TAPPED ===")
        print("🔔 Title: \(response.notification.request.content.title)")
        print("🔔 Body: \(response.notification.request.content.body)")
        print("🔔 Identifier: \(response.notification.request.identifier)")
        print("🔔 Action Identifier: \(response.actionIdentifier)")
        
        completionHandler()
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
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if authManager.isCompletingProfile {
                    NavigationView {
                        BuildProfileFlowView()
                    }
                } else if authManager.isAuthenticated {
                    NavigationView {
                        MainTabView(currentTab: .home)
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                } else {
                    NavigationView {
                        LoginScreen()
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
            .animation(.easeInOut(duration: 0.3), value: authManager.isCompletingProfile)
            .environmentObject(authManager)
        }
    }
}
