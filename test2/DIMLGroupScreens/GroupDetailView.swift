import SwiftUI
import AVFoundation
import FirebaseAuth
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
    @State private var navigateToProfile = false

    // Get the user's name from UserDefaults
    private var userName: String {
        SharedProfileViewModel.shared.name
    }

    // Use the saved name for current user
    var currentUser: User {
        let profile = SharedProfileViewModel.shared
        return User(
            id: "1", // same as currentInfluencerId for testing or actual ID if stored
            name: profile.name,
            username: "@\(profile.name.lowercased())",
            role: .admin
        )
    }

    var influencer: User? {
        group.members.first(where: { $0.id == group.currentInfluencerId })
    }

    var isInfluencer: Bool {
        currentUser.id == group.currentInfluencerId
    }

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
        ZStack {
            VStack(spacing: 0) {
                // MARK: - Top Bar
                HStack {
                    Button(action: {
                        dismiss()
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
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            if isInfluencer {
                                Text("\(currentUser.name)'s DIML")
                                    .font(.custom("Fredoka-Regular", size: 22))
                                    .foregroundColor(Color(red: 0.16, green: 0.21, blue: 0.09))
                                Text(currentUser.username ?? "@\(currentUser.name.lowercased())")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } else if let influencer = influencer {
                                Text("\(influencer.name)'s DIML")
                                    .font(.custom("Fredoka-Regular", size: 22))
                                    .foregroundColor(Color(red: 0.16, green: 0.21, blue: 0.09))
                                Text(influencer.username ?? "@\(influencer.name.lowercased())")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal)

                        if isInfluencer {
                            // Show prompt for influencer
                            PromptCard(prompt: "Today's Prompt", response: currentPrompt)
                                .padding(.horizontal)
                            
                            // Message Box for Influencer
                            VStack(spacing: 12) {
                                Image(systemName: "sun.max.fill")
                                    .resizable()
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.yellow)

                                Text("Snap a picture to kick off your day!")
                                    .font(.system(size: 16))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.black.opacity(0.7))
                                
                                Button(action: {
                                    showAddEntry = true
                                }) {
                                    Text("Add Entry")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 30)
                                        .padding(.vertical, 10)
                                        .background(Color.blue)
                                        .cornerRadius(10)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(red: 0.94, green: 0.93, blue: 0.88))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        } else {
                            // Message Box for non-Influencer
                            if let latestEntry = store.entries.first {
                                PromptCard(prompt: latestEntry.prompt, response: latestEntry.response)
                                    .padding(.horizontal)
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "sun.max.fill")
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(.gray)

                                    Text("\(influencer?.name ?? "Someone") is starting today's DIML")
                                        .font(.system(size: 18, weight: .medium))
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.black)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(red: 0.94, green: 0.93, blue: 0.88))
                                .cornerRadius(16)
                                .padding(.horizontal)
                            }
                        }

                        // Locked Box
                        VStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.gray)

                            Text("Next Prompt Unlocking in…")
                                .font(.custom("Markazi Text", size: 18))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 1, green: 0.89, blue: 0.64))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    .padding(.top)
                }

                if !keyboardVisible {
                    BottomNavBar(currentTab: $currentTab, onCameraTap: {
                        if isInfluencer {
                            showAddEntry = true
                        } else {
                            checkCameraPermission()
                        }
                    })
                    .onChange(of: currentTab) { newTab in
                        switch newTab {
                        case .home:
                            // Switch to main tab view with home selected and proper navigation
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = windowScene.windows.first {
                                window.rootViewController = UIHostingController(rootView: 
                                    NavigationView {
                                        MainTabView(currentTab: .home)
                                    }
                                )
                            }
                        case .profile:
                            // Switch to profile view
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = windowScene.windows.first {
                                window.rootViewController = UIHostingController(rootView: ProfileView())
                            }
                        case .camera:
                            // Camera is handled by onCameraTap
                            break
                        }
                    }
                }

                NavigationLink(destination: DIMLView(store: store, group: group), isActive: $goToDIML) {
                    EmptyView()
                }
                
                NavigationLink(destination: ProfileView(), isActive: $navigateToProfile) {
                    EmptyView()
                }
            }
        }
        .background(Color(red: 1, green: 0.989, blue: 0.93).ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showCamera) {
            CameraView(isPresented: $showCamera) { image in
                print("Image captured")
            }
        }
        .sheet(isPresented: $showAddEntry) {
            AddEntryView(store: store)
        }
        .sheet(isPresented: $showSettings) {
            GroupSettingsView(groupStore: groupStore, group: group)
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
