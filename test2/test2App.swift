import SwiftUI

@main
struct test2App: App {
    @StateObject private var authManager = AuthenticationManager.shared
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                NavigationView {
                    MainTabView(currentTab: .home)
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
