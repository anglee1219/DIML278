import SwiftUI
import AVFoundation
import FirebaseStorage
import FirebaseAuth

struct DIMLFeedView: View {
    let group: Group
    @StateObject private var entryStore = EntryStore()
    @State private var showCamera = false
    @State private var showImagePicker = false
    @State private var showPermissionAlert = false
    @State private var selectedPromptIndex = 0
    @State private var responseText = ""
    @State private var capturedImage: UIImage?
    @State private var currentTab: Tab = .home
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private let prompts = [
        "What does your typical morning look like?",
        "my simple pleasure",
        "late-day spirits?",
        "finishing up my day at my all"
    ]
    
    private let storage = StorageManager.shared
    
    private var isInfluencer: Bool {
        print("Checking influencer status - Current user ID: \(Auth.auth().currentUser?.uid ?? "none"), Influencer ID: \(group.currentInfluencerId)")
        return group.currentInfluencerId == Auth.auth().currentUser?.uid
    }
    
    private func checkCameraPermission() {
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
                    prompt: prompts[selectedPromptIndex],
                    imageURL: downloadURL,
                    response: responseText,
                    timestamp: Date()
                )
                
                await MainActor.run {
                    print("Adding entry to store...")
                    entryStore.addEntry(entry)
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
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    HStack {
                        Text("\(group.members.first(where: { $0.id == group.currentInfluencerId })?.name ?? "")'s DIML")
                            .font(.title3)
                            .foregroundColor(Color(red: 1.0, green: 0.815, blue: 0.0))
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    if isInfluencer {
                        if let image = capturedImage {
                            // Show captured image with prompt
                            VStack(alignment: .leading, spacing: 8) {
                                // Prompt text above image
                                Text(prompts[selectedPromptIndex])
                                    .padding(12)
                                    .background(Color(red: 1.0, green: 0.95, blue: 0.80))
                                    .cornerRadius(12)
                                
                                // Image
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 300)
                                    .cornerRadius(12)
                                
                                // Response Text Field
                                TextField("Add your response...", text: $responseText, axis: .vertical)
                                    .padding(12)
                                    .background(Color(red: 1.0, green: 0.95, blue: 0.80))
                                    .cornerRadius(12)
                                
                                // Action Buttons
                                HStack {
                                    Button(action: {
                                        print("Share button tapped")
                                        uploadImage(image)
                                    }) {
                                        Text(isUploading ? "Uploading..." : "Share")
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
                            // Show prompt card
                            VStack(spacing: 12) {
                                Text(prompts[selectedPromptIndex])
                                    .padding(12)
                                    .background(Color(red: 1.0, green: 0.95, blue: 0.80))
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Previous Entries
                    ForEach(entryStore.entries) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            // Prompt text above image
                            Text(entry.prompt)
                                .padding(12)
                                .background(Color(red: 1.0, green: 0.95, blue: 0.80))
                                .cornerRadius(12)
                            
                            // Image
                            AsyncImage(url: URL(string: entry.imageURL)) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 300)
                                    .cornerRadius(12)
                            } placeholder: {
                                ProgressView()
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
            
            // Bottom Navigation Bar
            VStack {
                Spacer()
                BottomNavBar(
                    currentTab: $currentTab,
                    onCameraTap: {
                        print("Camera tap triggered")
                        checkCameraPermission()
                    },
                    isInfluencer: isInfluencer
                )
            }
        }
        .background(Color(red: 1, green: 0.989, blue: 0.93))
        .sheet(isPresented: $showCamera) {
            CameraView(isPresented: $showCamera) { image in
                print("Image captured in CameraView")
                capturedImage = image
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: Binding(
                get: { capturedImage },
                set: { capturedImage = $0 }
            ))
        }
        .alert(isPresented: $showPermissionAlert) {
            Alert(
                title: Text("Camera Access Required"),
                message: Text("Please enable camera access in Settings to take photos."),
                primaryButton: .default(Text("Settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}

struct GroupHeaderView: View {
    let group: Group
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.name)
                .font(.title2)
                .fontWeight(.bold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(group.members) { member in
                        VStack {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(member.name.prefix(1).uppercased())
                                        .foregroundColor(.gray)
                                )
                            
                            Text(member.name)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }
}

// Preview
struct DIMLFeedView_Previews: PreviewProvider {
    static var previews: some View {
        DIMLFeedView(group: Group(
            id: "1",
            name: "Morning Circle",
            members: [
                User(id: "1", name: "John"),
                User(id: "2", name: "Sarah"),
                User(id: "3", name: "Mike")
            ],
            currentInfluencerId: "1"
        ))
    }
} 