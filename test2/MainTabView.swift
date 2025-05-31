import SwiftUI
import AVFoundation

struct MainTabView: View {
    @State private var currentTab: Tab = .home
    @State private var showCamera = false
    @State private var showPermissionAlert = false

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
        NavigationView {
            VStack(spacing: 0) {
                // Switch tabs
                switch currentTab {
                case .home:
                    GroupListView()
                case .profile:
                    ProfileView()
                case .camera:
                    EmptyView() // Camera doesn’t have its own screen
                }

                Spacer()

                // Bottom NavBar
                BottomNavBar(currentTab: $currentTab) {
                    checkCameraPermission()
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
            .navigationBarHidden(true)
        }
    }
}
