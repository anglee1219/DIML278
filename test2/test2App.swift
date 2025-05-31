import SwiftUI

@main
struct test2App: App {
    init() {
        // FOR TESTING: Reset login state on launch
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
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
