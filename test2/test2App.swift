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
            if authManager.isAuthenticated {
                NavigationView {
                    MainTabView(currentTab: .home)
                }
            } else if authManager.isCompletingProfile {
                NavigationView {
                    BuildProfileFlowView()
                }
            } else {
                NavigationView {
                    LoginScreen()
                }
            }
        }
    }
}

struct RootView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false

    var body: some View {
        NavigationView {
            if isLoggedIn {
                MainTabView()
            } else {
                LoginScreen()
            }
        }
    }
}
