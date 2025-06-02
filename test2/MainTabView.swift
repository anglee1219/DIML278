import SwiftUI
import AVFoundation

struct MainTabView: View {
    @State private var currentTab: Tab
    @State private var showCamera = false
    @State private var showPermissionAlert = false
    @State private var keyboardVisible = false
    
    init(currentTab: Tab = .home) {
        _currentTab = State(initialValue: currentTab)
    }

    // Handle camera permission
    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    showCamera = granted
                }
            }
        default:
            showPermissionAlert = true
        }
    }

    var body: some View {
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
                title: Text("Camera Access Required"),
                message: Text("Please enable camera access in Settings."),
                primaryButton: .default(Text("Settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
}
