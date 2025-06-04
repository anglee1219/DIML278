import SwiftUI
import AVFoundation
import FirebaseAuth
import FirebaseStorage
import Foundation

// Create a shared instance of ProfileViewModel
class SharedProfileViewModel {
    static let shared = ProfileViewModel()
}

struct GroupDetailView: View {
    var group: Group
    @StateObject var store = EntryStore()
    @ObservedObject var groupStore: GroupStore
    @State private var goToDIML = false
    @State private var showCamera = false
    @State private var showPermissionAlert = false
    @Environment(\.dismiss) private var dismiss
    @State private var currentTab: Tab = .home
    @State private var showSettings = false
    @State private var keyboardVisible = false
    @State private var showAddEntry = false
    @State private var currentPrompt = "What does your morning look like?"
    @Environment(\.presentationMode) var presentationMode
    @State private var capturedImage: UIImage?
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var responseText = ""
    @State private var showInlineCamera = false
    
    private let storage = StorageManager.shared

    // Get the user's name from UserDefaults
    private var userName: String {
        SharedProfileViewModel.shared.name
    }

    // Use the saved name for current user
    var currentUser: User {
        let profile = SharedProfileViewModel.shared
        return User(
            id: Auth.auth().currentUser?.uid ?? "", // Use actual Firebase Auth ID
            name: profile.name,
            username: "@\(profile.name.lowercased())",
            role: .admin
        )
    }

    var influencer: User? {
        group.members.first(where: { $0.id == group.currentInfluencerId })
    }

    var isInfluencer: Bool {
        print("Checking influencer status - Current user ID: \(Auth.auth().currentUser?.uid ?? "none"), Influencer ID: \(group.currentInfluencerId)")
        return Auth.auth().currentUser?.uid == group.currentInfluencerId
    }

    private func uploadImage(_ image: UIImage) {
        print("Starting image upload...")
        isUploading = true
        
        Task {
            do {
                let imagePath = "diml_images/\(UUID().uuidString).jpg"
                print("Uploading to path: \(imagePath)")
                let downloadURL = try await storage.uploadImage(image, path: imagePath)
                print("Upload successful, URL: \(downloadURL)")
                
                let entry = DIMLEntry(
                    id: UUID().uuidString,
                    userId: Auth.auth().currentUser?.uid ?? "",
                    prompt: currentPrompt,
                    response: responseText,
                    image: image,
                    comments: [],
                    reactions: [:]
                )
                
                await MainActor.run {
                    print("Adding entry to store...")
                    store.addEntry(
                        prompt: entry.prompt,
                        response: entry.response,
                        image: entry.image
                    )
                    capturedImage = nil
                    responseText = ""
                    isUploading = false
                    print("Upload process completed")
                }
            } catch {
                print("Upload error: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isUploading = false
                }
            }
        }
    }

    func checkCameraPermission() {
        print("Checking camera permission")
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showInlineCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.showInlineCamera = granted
                }
            }
        default:
            showPermissionAlert = true
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // MARK: - Top Bar
                HStack {
                    Button(action: {
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first {
                            window.rootViewController = UIHostingController(rootView: GroupListView())
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(.black)
                    }
                    
                    Spacer()
                    
                    Image("DIML_Logo")
                        .resizable()
                        .frame(width: 40, height: 40)
                    
                    Spacer()
                    
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                ScrollView {
                    VStack(spacing: 16) {
                        if isInfluencer {
                            if let image = capturedImage {
                                // Show captured image with prompt
                                VStack(spacing: 0) {
                                    Text("\(currentUser.name)'s DIML")
                                        .font(.custom("Fredoka-Regular", size: 24))
                                        .foregroundColor(Color(red: 0.95, green: 0.77, blue: 0.06))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.bottom, 4)
                                    
                                    Text(currentUser.username ?? "@\(currentUser.name.lowercased())")
                                        .font(.custom("Fredoka-Regular", size: 14))
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.bottom, 16)
                                    
                                    // Prompt text above image
                                    Text(currentPrompt)
                                        .font(.custom("Fredoka-Regular", size: 16))
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(red: 1.0, green: 0.95, blue: 0.80))
                                        .cornerRadius(12)
                                    
                                    // Image
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity)
                                        .frame(maxHeight: 300)
                                        .cornerRadius(12)
                                    
                                    // Response Text Field
                                    if #available(iOS 16.0, *) {
                                        TextField("Add your response...", text: $responseText, axis: .vertical)
                                            .font(.custom("Fredoka-Regular", size: 16))
                                            .padding(12)
                                            .frame(maxWidth: .infinity)
                                            .background(Color(red: 1.0, green: 0.95, blue: 0.80))
                                            .cornerRadius(12)
                                            .submitLabel(.done)
                                            .onSubmit {
                                                hideKeyboard()
                                            }
                                    } else {
                                        TextEditor(text: $responseText)
                                            .font(.custom("Fredoka-Regular", size: 16))
                                            .padding(12)
                                            .frame(maxWidth: .infinity)
                                            .background(Color(red: 1.0, green: 0.95, blue: 0.80))
                                            .cornerRadius(12)
                                            .frame(minHeight: 100)
                                    }
                                    
                                    // Action Buttons
                                    HStack {
                                        Button(action: {
                                            print("Share button tapped")
                                            uploadImage(image)
                                        }) {
                                            Text(isUploading ? "Uploading..." : "Share")
                                                .font(.custom("Fredoka-Regular", size: 16))
                                                .foregroundColor(.blue)
                                                .padding(.vertical, 6)
                                                .padding(.horizontal, 12)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(8)
                                        }
                                        .disabled(isUploading)
                                        
                                        Button(action: { 
                                            print("Delete button tapped")
                                            capturedImage = nil 
                                        }) {
                                            Text("Delete")
                                                .font(.custom("Fredoka-Regular", size: 16))
                                                .foregroundColor(.red)
                                                .padding(.vertical, 6)
                                                .padding(.horizontal, 12)
                                                .background(Color.red.opacity(0.1))
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            } else {
                                // Show prompt for influencer
                                VStack(spacing: 0) {
                                    Text("\(currentUser.name)'s DIML")
                                        .font(.custom("Fredoka-Regular", size: 24))
                                        .foregroundColor(Color(red: 0.95, green: 0.77, blue: 0.06))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.bottom, 4)
                                    
                                    Text(currentUser.username ?? "@\(currentUser.name.lowercased())")
                                        .font(.custom("Fredoka-Regular", size: 14))
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.bottom, 16)
                                    
                                    VStack(spacing: 16) {
                                        if showInlineCamera {
                                            CameraView(isPresented: $showInlineCamera) { image in
                                                print("Image captured in CameraView")
                                                capturedImage = image
                                                showInlineCamera = false
                                            }
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 300)
                                            .cornerRadius(16)
                                            
                                            Button(action: {
                                                showInlineCamera = false
                                            }) {
                                                Text("Cancel")
                                                    .font(.custom("Fredoka-Regular", size: 16))
                                                    .foregroundColor(.red)
                                                    .padding(.vertical, 12)
                                                    .padding(.horizontal, 30)
                                                    .background(Color.red.opacity(0.1))
                                                    .cornerRadius(25)
                                            }
                                            .padding(.top, 8)
                                        } else {
                                            Image(systemName: "sun.max.fill")
                                                .resizable()
                                                .frame(width: 60, height: 60)
                                                .foregroundColor(Color(red: 0.95, green: 0.77, blue: 0.06))
                                            
                                            Text("Snap a picture to\nkick off your day!")
                                                .font(.custom("Fredoka-Regular", size: 20))
                                                .multilineTextAlignment(.center)
                                                .foregroundColor(.black.opacity(0.8))
                                            
                                            Button(action: {
                                                checkCameraPermission()
                                            }) {
                                                Text("Take Photo")
                                                    .font(.custom("Fredoka-Regular", size: 16))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 30)
                                                    .padding(.vertical, 12)
                                                    .background(Color.blue)
                                                    .cornerRadius(25)
                                            }
                                            .padding(.top, 8)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                    .background(Color(red: 0.96, green: 0.96, blue: 0.96))
                                    .cornerRadius(16)
                                    
                                    HStack {
                                        Image(systemName: "lock.fill")
                                            .foregroundColor(.gray)
                                        Text("Next Prompt Unlocking in...")
                                            .font(.custom("Fredoka-Regular", size: 14))
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.top, 16)
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Previous Entries
                        ForEach(store.entries) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                // Prompt text above image
                                Text(entry.prompt)
                                    .padding(12)
                                    .background(Color(red: 1.0, green: 0.95, blue: 0.80))
                                    .cornerRadius(12)
                                
                                // Image
                                if let image = entry.image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 300)
                                        .cornerRadius(12)
                                }
                                
                                if !entry.response.isEmpty {
                                    Text(entry.response)
                                        .padding(12)
                                        .background(Color(red: 1.0, green: 0.95, blue: 0.80))
                                        .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .simultaneousGesture(
                    TapGesture()
                        .onEnded { _ in
                            hideKeyboard()
                        }
                )
            }
            
            // Bottom Navigation Bar
            VStack {
                Spacer()
                BottomNavBar(
                    currentTab: Binding(
                        get: { currentTab },
                        set: { newTab in
                            if newTab == .camera {
                                checkCameraPermission()
                            } else if newTab == .home {
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let window = windowScene.windows.first {
                                    window.rootViewController = UIHostingController(rootView: GroupListView())
                                }
                            } else if newTab == .profile {
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let window = windowScene.windows.first {
                                    window.rootViewController = UIHostingController(rootView: ProfileView())
                                }
                            }
                            currentTab = newTab
                        }
                    ),
                    onCameraTap: {
                        print("Camera tap triggered")
                        checkCameraPermission()
                    },
                    isInfluencer: isInfluencer
                )
            }
        }
        .background(Color(red: 1, green: 0.989, blue: 0.93))
        .navigationBarHidden(true)
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
        .contentShape(Rectangle())
        .onTapGesture {
            hideKeyboard()
        }
        .ignoresSafeArea(.keyboard)
        .modifier(KeyboardDismissModifier())
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Preview
struct GroupDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let mockMembers = [
            User(id: "1", name: "Rebecca"),
            User(id: "2", name: "Taylor")
        ]

        let mockGroup = Group(
            id: "g1",
            name: "Test Group",
            members: mockMembers,
            currentInfluencerId: "1",
            date: Date()
        )

        GroupDetailView(
            group: mockGroup,
            groupStore: GroupStore()
        )
    }
}

// Add this at the bottom of the file, outside the GroupDetailView struct
struct KeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollDismissesKeyboard(.immediately)
        } else {
            content
        }
    }
}
