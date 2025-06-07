import SwiftUI
import AVFoundation
import FirebaseAuth

struct ProfilePicSetup: View {
    @StateObject private var viewModel = ProfileViewModel.shared
    @Environment(\.dismiss) var dismiss
    @State private var image: UIImage?
    @State private var showImagePicker = false
    @State private var showActionSheet = false
    @State private var useCamera = false
    @State private var showPermissionAlert = false
    @State private var pendingProfileImage: UIImage?
    @State private var showCropPreview = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var navigateToNext = false
    
    var body: some View {
        ZStack {
            Color(red: 1, green: 0.989, blue: 0.93)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) { // Reduced spacing
                    // Add top padding
                    Spacer()
                        .frame(height: 20)
                    
                    // Logo
                    Image("DIML_Logo")
                        .resizable()
                        .frame(width: 60, height: 60)
                    
                    // Title and subtitle
                    VStack(spacing: 12) {
                        Text("Add Your Profile Picture")
                            .font(.custom("Markazi Text", size: 32)) // Reduced font size
                            .foregroundColor(Color(red: 0.969, green: 0.757, blue: 0.224))
                        
                        Text("Let your friends recognize you!")
                            .font(.custom("Markazi Text", size: 20)) // Reduced font size
                            .foregroundColor(.gray)
                    }
                    
                    // Profile image display
                    ZStack {
                        if let image = image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120) // Slightly reduced size
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Image(systemName: "person.circle")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .foregroundColor(Color.gray.opacity(0.3))
                                        .frame(width: 120, height: 120)
                                )
                        }
                        
                        Button(action: {
                            showActionSheet = true
                        }) {
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.blue)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                        .offset(x: 45, y: 45)
                    }
                    .padding(.vertical, 20)
                    
                    NavigationLink(destination: PronounSelectionView(), isActive: $navigateToNext) {
                        EmptyView()
                    }

                    // Navigation Arrows
                    HStack {
                        // Back Arrow
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "arrow.left.circle.fill")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        // Next Arrow
                        Button(action: {
                            // Save profile image to UserDefaults if selected
                            if let image = image {
                                viewModel.updateProfileImage(image)
                            }
                            navigateToNext = true
                        }) {
                            Image(systemName: "arrow.right.circle.fill")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(Color.mainBlue)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 30)
                    
                    // Add bottom padding for scroll content
                    Spacer()
                        .frame(height: 60)
                }
                .padding(.bottom, 20) // Extra bottom padding
            }
            .confirmationDialog("Choose a photo", isPresented: $showActionSheet, titleVisibility: .visible) {
                Button("Take Photo") {
                    checkCameraPermission()
                }
                Button("Choose from Library") {
                    sourceType = .photoLibrary
                    showImagePicker = true
                }
                if image != nil {
                    Button("Remove Photo", role: .destructive) {
                        image = nil
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: Binding(
                    get: { pendingProfileImage },
                    set: { newImage in
                        if let newImage = newImage {
                            pendingProfileImage = newImage
                            showCropPreview = true
                        }
                    }
                ), sourceType: sourceType)
            }
            .sheet(isPresented: $showCropPreview) {
                if let previewImage = pendingProfileImage {
                    if #available(iOS 16.0, *) {
                        VStack(spacing: 24) {
                            Text("Adjust Your Photo")
                                .font(.title2)
                                .padding(.top)
                            
                            GeometryReader { geometry in
                                ImageAdjustmentView(image: previewImage) { adjustedImage in
                                    image = adjustedImage
                                    pendingProfileImage = nil
                                    showCropPreview = false
                                }
                            }
                            .aspectRatio(1, contentMode: .fit)
                            .padding(.horizontal)
                            
                            Text("Pinch to zoom • Drag to adjust")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Button("Cancel") {
                                pendingProfileImage = nil
                                showCropPreview = false
                            }
                            .foregroundColor(.red)
                            .padding(.bottom)
                        }
                        .padding()
                        .presentationDetents([.height(600)])
                        .background(Color(red: 1, green: 0.989, blue: 0.93))
                    }
                }
            }
            .alert(isPresented: $showPermissionAlert) {
                Alert(
                    title: Text("Camera Access Required"),
                    message: Text("Please enable camera access in Settings to take photos."),
                    primaryButton: .default(Text("Settings"), action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }),
                    secondaryButton: .cancel()
                )
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            print("🎯 ProfilePicSetup: onAppear - Current ProfileViewModel data:")
            print("    name: '\(viewModel.name)'")
            print("    username: '\(viewModel.username)'")
            print("    isInitializing: \(viewModel.isInitializing)")
            
            // Check UserDefaults too
            let savedName = UserDefaults.standard.string(forKey: "profile_name") ?? ""
            let savedUsername = UserDefaults.standard.string(forKey: "profile_username") ?? ""
            print("🎯 ProfilePicSetup: UserDefaults data:")
            print("    name: '\(savedName)'")
            print("    username: '\(savedUsername)'")
        }
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sourceType = .camera
            showImagePicker = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        sourceType = .camera
                        showImagePicker = true
                    } else {
                        showPermissionAlert = true
                    }
                }
            }
        default:
            showPermissionAlert = true
        }
    }
}

#Preview {
    NavigationView {
        ProfilePicSetup()
    }
}
