import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
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
