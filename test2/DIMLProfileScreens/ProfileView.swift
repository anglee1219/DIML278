import SwiftUI
import AVFoundation

// Import TopNavBar if it's in a separate module
// If TopNavBar is in the same module, no additional import is needed

struct ProfileView: View {
    @State private var currentTab: Tab = .profile
    @State private var showCamera = false
    @State private var showPermissionAlert = false

    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.showCamera = granted
                }
            }
        default:
            showPermissionAlert = true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top Navigation
            TopNavBar(showsMenu: true)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Image with Edit Button
                    ZStack(alignment: .topTrailing) {
                        Image("Rebecca_Profile")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 150, height: 150)
                            .clipShape(Circle())
                        
                        // Edit Button Overlay
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                            .offset(x: 8, y: 8)
                    }
                    .padding(.top, 20)
                    
                    // Name and Pronouns
                    Text("Rebecca")
                        .font(.system(size: 32, weight: .bold))
                    
                    Text("she/ her || scorpio")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    // User Details
                    VStack(alignment: .leading, spacing: 4) {
                        Text("location: miami, fl")
                        Text("school: stanford")
                        Text("interests: hiking, cooking, & taking pictures")
                    }
                    .font(.system(size: 16))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    
                    // Edit Profile Button
                    Button(action: {
                        // Edit profile action
                    }) {
                        HStack {
                            Image(systemName: "pencil.circle.fill")
                            Text("Edit Profile")
                                .font(.system(size: 18, weight: .medium))
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.4, green: 0.45, blue: 0.25))
                        .cornerRadius(12)
                        .padding(.horizontal, 24)
                    }
                    
                    // My Capsule Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("My Capsule")
                            .font(.custom("Markazi Text", size: 28))
                            .bold()
                            .padding(.horizontal, 24)
                        
                        VStack {
                            HStack {
                                Image("Rebecca_Profile")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                Text("May 9th, 2025")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                
                                Spacer()
                            }
                            .padding()
                        }
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
                        .padding(.horizontal, 24)
                    }
                    .padding(.top, 20)
                }
            }
        }
        .background(Color(red: 1, green: 0.989, blue: 0.93).ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showCamera) {
            CameraView(isPresented: $showCamera) { image in
                print("Captured image from ProfileView")
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

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
