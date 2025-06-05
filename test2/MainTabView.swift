import SwiftUI
import AVFoundation

struct MainTabView: View {
    @State private var currentTab: Tab
    @State private var showCamera = false
    @State private var showPermissionAlert = false
    @State private var keyboardVisible = false
    @StateObject private var authManager = AuthenticationManager.shared
    
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
            // Switch tabs
            switch currentTab {
            case .home:
                GroupListView()
            case .profile:
                ProfileView()
            case .camera:
                EmptyView() // Camera doesn't have its own screen
            }

            VStack {
                Spacer()
                // Bottom NavBar
                if !keyboardVisible {
                    BottomNavBar(currentTab: $currentTab) {
                        checkCameraPermission()
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
