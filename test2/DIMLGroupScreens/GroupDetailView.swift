import SwiftUI
import AVFoundation
import FirebaseAuth
import FirebaseStorage
import Foundation

// Seeded random number generator for consistent daily prompts
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var seed: UInt64
    
    init(seed: UInt64) {
        self.seed = seed
    }
    
    mutating func next() -> UInt64 {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return seed
    }
}

// Extension to make TimeOfDay hashable for seeded random
extension TimeOfDay: Hashable {
    var hashValue: Int {
        switch self {
        case .morning: return 1
        case .afternoon: return 2
        case .night: return 3
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(hashValue)
    }
}

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
    @State private var currentPrompt = ""
    @Environment(\.presentationMode) var presentationMode
    @State private var capturedImage: UIImage?
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var responseText = ""
    @State private var capturedFrameSize: FrameSize = FrameSize.random
    
    private let promptManager = PromptManager.shared
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
    
    private func getCurrentPrompt() -> String {
        let timeOfDay = TimeOfDay.current()
        
        // Create a daily seed based on current date to ensure consistency
        let calendar = Calendar.current
        let today = Date()
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: today) ?? 1
        let year = calendar.component(.year, from: today)
        let dailySeed = year * 1000 + dayOfYear
        
        // Use seeded random to get consistent prompt for the day
        var generator = SeededRandomNumberGenerator(seed: UInt64(dailySeed + timeOfDay.hashValue))
        
        return promptManager.getSeededPrompt(for: timeOfDay, using: &generator) ?? "What does your day look like?"
    }
    
    private func loadDailyPrompt() {
        currentPrompt = getCurrentPrompt()
    }

    private func getTimeOfDayDisplay() -> String {
        let timeOfDay = TimeOfDay.current()
        switch timeOfDay {
        case .morning:
            return "☀️ Morning"
        case .afternoon:
            return "🌞 Afternoon" 
        case .night:
            return "🌙 Evening"
        }
    }

    private func getTimeOfDayIcon() -> String {
        let timeOfDay = TimeOfDay.current()
        switch timeOfDay {
        case .morning:
            return "sunrise"
        case .afternoon:
            return "sun.max"
        case .night:
            return "moon.stars"
        }
    }

    private func getPromptIcon() -> String {
        let prompt = currentPrompt.lowercased()
        
        // Activity-based icons
        if prompt.contains("workout") || prompt.contains("exercise") || prompt.contains("gym") || prompt.contains("fitness") {
            return "figure.run"
        } else if prompt.contains("coffee") || prompt.contains("cafe") || prompt.contains("latte") {
            return "cup.and.saucer"
        } else if prompt.contains("food") || prompt.contains("eat") || prompt.contains("meal") || prompt.contains("lunch") || prompt.contains("dinner") || prompt.contains("breakfast") {
            return "fork.knife"
        } else if prompt.contains("work") || prompt.contains("office") || prompt.contains("meeting") {
            return "briefcase"
        } else if prompt.contains("read") || prompt.contains("book") || prompt.contains("study") {
            return "book"
        } else if prompt.contains("music") || prompt.contains("song") || prompt.contains("listen") {
            return "music.note"
        } else if prompt.contains("walk") || prompt.contains("outside") || prompt.contains("nature") {
            return "leaf"
        } else if prompt.contains("friend") || prompt.contains("people") || prompt.contains("social") {
            return "person.2"
        } else if prompt.contains("travel") || prompt.contains("trip") || prompt.contains("vacation") {
            return "airplane"
        } else if prompt.contains("home") || prompt.contains("house") || prompt.contains("room") {
            return "house"
        } else if prompt.contains("phone") || prompt.contains("call") || prompt.contains("text") {
            return "phone"
        } else if prompt.contains("creative") || prompt.contains("art") || prompt.contains("design") {
            return "paintbrush"
        } else if prompt.contains("relax") || prompt.contains("chill") || prompt.contains("rest") {
            return "bed.double"
        } else if prompt.contains("shop") || prompt.contains("buy") || prompt.contains("store") {
            return "bag"
        } else if prompt.contains("car") || prompt.contains("drive") || prompt.contains("transport") {
            return "car"
        } else if prompt.contains("weather") || prompt.contains("rain") || prompt.contains("sunny") {
            return "cloud.sun"
        } else if prompt.contains("love") || prompt.contains("heart") || prompt.contains("relationship") {
            return "heart"
        } else if prompt.contains("goal") || prompt.contains("achieve") || prompt.contains("accomplish") {
            return "target"
        } else if prompt.contains("think") || prompt.contains("mind") || prompt.contains("reflect") {
            return "brain.head.profile"
        } else if prompt.contains("celebrate") || prompt.contains("party") || prompt.contains("fun") {
            return "party.popper"
        } else {
            // Fallback to time-based icons
            let timeOfDay = TimeOfDay.current()
            switch timeOfDay {
            case .morning:
                return "sunrise"
            case .afternoon:
                return "sun.max"
            case .night:
                return "moon.stars"
            }
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
                    prompt: currentPrompt,
                    response: responseText,
                    image: image,
                    frameSize: capturedFrameSize
                )
                
                await MainActor.run {
                    print("Adding entry to store...")
                    store.addEntry(
                        prompt: entry.prompt,
                        response: entry.response,
                        image: entry.image,
                        frameSize: entry.frameSize
                    )
                    capturedImage = nil
                    responseText = ""
                    capturedFrameSize = FrameSize.random // Reset for next capture
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
                    ScrollViewReader { proxy in
                        VStack(spacing: 16) {
                            if isInfluencer {
                                // Show user's name and pronouns header (always visible)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\(currentUser.name)'s DIML")
                                        .font(.custom("Fredoka-Regular", size: 24))
                                        .fontWeight(.bold)
                                        .foregroundColor(Color(red: 1.0, green: 0.815, blue: 0.0))
                                    
                                    Text("she/her") // This could be made dynamic later
                                        .font(.custom("Fredoka-Regular", size: 14))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                                
                                VStack(spacing: 16) {
                                    if let image = capturedImage {
                                        // Prompt box with image inside (like Rebecca's example)
                                        VStack(alignment: .leading, spacing: 0) {
                                            // Prompt text at the top
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(currentPrompt)
                                                    .font(.custom("Fredoka-Medium", size: 16))
                                                    .foregroundColor(.black)
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.top, 16)
                                            .padding(.bottom, 12)
                                            
                                            // Image in the middle
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(height: capturedFrameSize.height)
                                                .cornerRadius(12)
                                                .clipped()
                                                .padding(.horizontal, 16)
                                            
                                            // Response text field at the bottom
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text("Add your response...")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                                
                                                if #available(iOS 16.0, *) {
                                                    TextField("e.g., corepower w/ eliza", text: $responseText, axis: .vertical)
                                                        .font(.custom("Fredoka-Regular", size: 16))
                                                        .textFieldStyle(PlainTextFieldStyle())
                                                        .frame(minHeight: 40)
                                                        .submitLabel(.done)
                                                        .onSubmit {
                                                            hideKeyboard()
                                                        }
                                                        .onTapGesture {
                                                            withAnimation(.easeInOut(duration: 0.5)) {
                                                                proxy.scrollTo("responseField", anchor: .center)
                                                            }
                                                        }
                                                } else {
                                                    TextEditor(text: $responseText)
                                                        .font(.custom("Fredoka-Regular", size: 16))
                                                        .frame(minHeight: 60)
                                                        .onTapGesture {
                                                            withAnimation(.easeInOut(duration: 0.5)) {
                                                                proxy.scrollTo("responseField", anchor: .center)
                                                            }
                                                        }
                                                }
                                            }
                                            .id("responseField")
                                            .padding(.horizontal, 16)
                                            .padding(.top, 12)
                                            .padding(.bottom, 16)
                                        }
                                        .background(Color(red: 1.0, green: 0.95, blue: 0.80))
                                        .cornerRadius(15)
                                        .padding(.horizontal)
                                        
                                        // Action Buttons outside the frame
                                        HStack {
                                            Button(action: {
                                                print("Share button tapped")
                                                uploadImage(capturedImage!)
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
                                                print("Retake button tapped")
                                                capturedImage = nil 
                                            }) {
                                                Text("Retake")
                                                    .font(.custom("Fredoka-Regular", size: 16))
                                                    .foregroundColor(.red)
                                                    .padding(.vertical, 6)
                                                    .padding(.horizontal, 12)
                                                    .background(Color.red.opacity(0.1))
                                                    .cornerRadius(8)
                                            }
                                        }
                                        .padding(.horizontal)
                                        .padding(.top, 12)
                                        .padding(.bottom, 20)
                                    } else {
                                        // Check if there's already an entry for today's prompt
                                        let todaysEntry = store.entries.first { entry in
                                            entry.prompt == currentPrompt
                                        }
                                        
                                        if let entry = todaysEntry {
                                            // Show the completed entry instead of prompt area
                                            VStack(alignment: .leading, spacing: 0) {
                                                // Prompt text at the top
                                                VStack(alignment: .leading, spacing: 6) {
                                                    Text(entry.prompt)
                                                        .font(.custom("Fredoka-Medium", size: 16))
                                                        .foregroundColor(.black)
                                                        .multilineTextAlignment(.leading)
                                                }
                                                .padding(.horizontal, 16)
                                                .padding(.top, 16)
                                                .padding(.bottom, 12)
                                                
                                                // Image in the middle
                                                if let image = entry.image {
                                                    Image(uiImage: image)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(height: entry.frameSize.height)
                                                        .cornerRadius(12)
                                                        .clipped()
                                                        .padding(.horizontal, 16)
                                                }
                                                
                                                // Response text at the bottom
                                                if !entry.response.isEmpty {
                                                    VStack(alignment: .leading, spacing: 6) {
                                                        Text(entry.response)
                                                            .font(.custom("Fredoka-Regular", size: 16))
                                                            .foregroundColor(.black)
                                                            .multilineTextAlignment(.leading)
                                                    }
                                                    .padding(.horizontal, 16)
                                                    .padding(.top, 12)
                                                    .padding(.bottom, 16)
                                                }
                                            }
                                            .background(Color(red: 1.0, green: 0.95, blue: 0.80))
                                            .cornerRadius(15)
                                            .padding(.horizontal)
                                        } else {
                                            // Large grey box with sun icon and call to action
                                            VStack(spacing: 16) {
                                                Image(systemName: getPromptIcon())
                                                    .resizable()
                                                    .frame(width: 60, height: 60)
                                                    .foregroundColor(Color(red: 0.95, green: 0.77, blue: 0.06))

                                                // Show the actual prompt as the main text
                                                VStack(spacing: 8) {
                                                    Text(currentPrompt)
                                                        .font(.custom("Fredoka-Medium", size: 18))
                                                        .fontWeight(.medium)
                                                        .multilineTextAlignment(.center)
                                                        .foregroundColor(.black)
                                                        .lineLimit(4)
                                                        .padding(.horizontal, 16)
                                                }
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 40)
                                            .background(Color(red: 0.92, green: 0.92, blue: 0.92))
                                            .cornerRadius(16)
                                            .padding(.horizontal)
                                        }
                                    }
                                    
                                    // Yellow box with lock icon and timer (always visible)
                                    HStack {
                                        Image(systemName: "lock.fill")
                                            .foregroundColor(.gray)
                                        Text("Next Prompt Unlocking in...")
                                            .font(.custom("Fredoka-Regular", size: 14))
                                            .foregroundColor(.gray)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color(red: 1.0, green: 0.95, blue: 0.80))
                                    .cornerRadius(16)
                                    .padding(.horizontal)
                                }
                            }

                            // Previous Entries (excluding current prompt)
                            ForEach(store.entries.filter { $0.prompt != currentPrompt }) { entry in
                                // Unified entry layout with cream background
                                VStack(alignment: .leading, spacing: 0) {
                                    // Prompt text at the top
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(entry.prompt)
                                            .font(.custom("Fredoka-Medium", size: 16))
                                            .foregroundColor(.black)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                                    .padding(.bottom, 12)
                                    
                                    // Image in the middle
                                    if let image = entry.image {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: entry.frameSize.height)
                                            .cornerRadius(12)
                                            .clipped()
                                            .padding(.horizontal, 16)
                                    }
                                    
                                    // Response text at the bottom
                                    if !entry.response.isEmpty {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(entry.response)
                                                .font(.custom("Fredoka-Regular", size: 16))
                                                .foregroundColor(.black)
                                                .multilineTextAlignment(.leading)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.top, 12)
                                        .padding(.bottom, 16)
                                    }
                                }
                                .background(Color(red: 1.0, green: 0.95, blue: 0.80))
                                .cornerRadius(15)
                                .padding(.horizontal)
                            }
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
        .sheet(isPresented: $showCamera) {
            InFrameCameraView(
                isPresented: $showCamera,
                capturedImage: $capturedImage,
                capturedFrameSize: $capturedFrameSize,
                prompt: currentPrompt
            )
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
        .onAppear {
            // Load current prompt based on time of day
            if currentPrompt.isEmpty {
                loadDailyPrompt()
            }
        }
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
