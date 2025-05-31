import SwiftUI
// Rebecca's initial
/*struct GroupListView: View {
    @State private var groups: [Group] = []
    @State private var showingCreateGroup = false

    var body: some View {
        NavigationView {
            List {
                ForEach(groups) { group in
                    NavigationLink(destination: GroupDetailView(group: group)) {
                        VStack(alignment: .leading) {
                            Text(group.name)
                                .font(.headline)
                            Text("Influencer: \(group.members.first(where: { $0.id == group.currentInfluencerId })?.name ?? "Unknown")")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("My Groups")
            .navigationBarItems(trailing:
                Button(action: {
                    showingCreateGroup = true
                }) {
                    Image(systemName: "plus")
                }
            )
            .sheet(isPresented: $showingCreateGroup) {
                CreateGroupView { newGroup in
                    groups.append(newGroup)
                }
            }
        }
    }
}
*/
import SwiftUI
import AVFoundation

struct GroupListView: View {
    @State private var groups: [Group] = []
    @State private var showingCreateGroup = false
    @State private var showingAddFriends = false
    @State private var showCamera = false
    @State private var showPermissionAlert = false
    @State private var currentTab: Tab = .home
    
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
        VStack(spacing: 0) {
            // ✅ Reusable Top Nav
            TopNavBar(showsMenu: false)
            
            // Title and Action Menu
            HStack {
                Text("Your Circles")
                    .font(.custom("Markazi Text", size: 32))
                    .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                
                Spacer()
                Menu {
                    Button("Create a Circle") {
                        showingCreateGroup = true
                    }
                    Button("Add Friends") {
                        showingAddFriends = true
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .resizable()
                        .frame(width: 25, height: 25)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            
            // Search Bar
            HStack {
                TextField("Search", text: .constant(""))
                    .padding(5)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(6)
                
                Image(systemName: "mic.fill")
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            
            Divider()
                .padding(.top, 10)
                .padding(.horizontal, 24)
            
            // Main Content
            if groups.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "moon.zzz")
                        .resizable()
                        .frame(width: 200, height: 225)
                        .foregroundColor(.gray.opacity(0.4))
                    
                    Text("You have no Circles.")
                        .font(.custom("Fredoka-Regular", size: 22))
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    Text("Tap the ⊕ in the upper right corner\nto create a Circle!")
                        .multilineTextAlignment(.center)
                        .font(.custom("Markazi Text", size: 18))
                        .foregroundColor(.black)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(groups) { group in
                            NavigationLink(destination: GroupDetailView(group: group)) {
                                HStack(spacing: 12) {
                                    HStack(spacing: -8) {
                                        ForEach(0..<min(3, group.members.count), id: \.self) { _ in
                                            Circle()
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 40, height: 40)
                                        }
                                    }
                                    
                                    VStack(alignment: .leading) {
                                        Text(group.name)
                                            .font(.custom("Fredoka-Regular", size: 18))
                                            .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                                        
                                        Text("Check out what’s happening!")
                                            .font(.custom("Markazi Text", size: 16))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing) {
                                        Text("10:28 PM")
                                            .font(.footnote)
                                            .foregroundColor(.gray)
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray.opacity(0.6))
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.top, 20)
                }
            }
            
            Spacer()
            
            
                .background(Color(red: 1, green: 0.989, blue: 0.93).ignoresSafeArea())
                .navigationBarHidden(true)
                .sheet(isPresented: $showingCreateGroup) {
                    CreateGroupView { newGroup in
                        groups.append(newGroup)
                    }
                }
                .sheet(isPresented: $showingAddFriends) {
                    AddFriendsView()
                }
                .sheet(isPresented: $showCamera) {
                    CameraView(isPresented: $showCamera) { image in
                        print("Image captured")
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
    }
    
    struct GroupListView_Previews: PreviewProvider {
        static var previews: some View {
            GroupListView()
        }
    }
}
