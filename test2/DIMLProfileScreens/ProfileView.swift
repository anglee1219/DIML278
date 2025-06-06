import SwiftUI
import AVFoundation
import MapKit

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel.shared
    @State private var currentTab: Tab = .profile
    @State private var showCamera = false
    @State private var showPermissionAlert = false
    @State private var showSettings = false
    @State private var isEditing = false
    @State private var showImagePicker = false
    @State private var showPhotoOptions = false
    @State private var pendingProfileImage: UIImage? = nil
    @State private var showCropPreview: Bool = false
    @State private var keyboardVisible = false
    @Environment(\.presentationMode) var presentationMode

    @FocusState private var focusedField: String?
    
    let profileImageSize: CGFloat = 120
    
    // Pronouns options
    let pronounOptions = [
        "she/her",
        "he/him",
        "they/them",
        "other",
        "prefer not to answer"
    ]
    
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
                TopNavBar(showsMenu: true, onMenu: {
                    showSettings = true
                })
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Image Section
                        VStack {
                            ZStack(alignment: .topTrailing) {
                                if let profileImage = viewModel.profileImage {
                                    Image(uiImage: profileImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: profileImageSize, height: profileImageSize)
                                        .clipShape(Circle())
                                } else {
                                    // Placeholder profile image
                                    Circle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                        .frame(width: profileImageSize, height: profileImageSize)
                                        .overlay(
                                            VStack(spacing: 0) {
                                                Spacer()
                                                    .frame(height: 25)
                                                
                                                // Head
                                                Circle()
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                                    .frame(width: 40, height: 40)
                                                    .padding(.bottom, 4)
                                                
                                                // Body
                                                Circle()
                                                    .trim(from: 0, to: 0.5)
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                                    .frame(width: 65, height: 65)
                                                    .rotationEffect(.degrees(180))
                                                
                                                Spacer()
                                                    .frame(height: 5)
                                            }
                                        )
                                }
                                
                                // Edit Photo Button
                                Button(action: {
                                    showPhotoOptions = true
                                }) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                        .padding(8)
                                        .background(
                                            Circle()
                                                .fill(.white)
                                                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                .offset(x: -4, y: 0)
                            }
                            .padding(.top, 40)
                        }
                        
                        // Name
                        Text(viewModel.name.isEmpty ? "Your Name" : viewModel.name)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(viewModel.name.isEmpty ? .gray : .black)
                            .padding(.top, 8)
                        
                        // Username
                        Text(viewModel.username.isEmpty ? "@username" : "@\(viewModel.username)")
                            .font(.system(size: 16))
                            .foregroundColor(viewModel.username.isEmpty ? .gray : .black.opacity(0.6))
                            .padding(.bottom, 4)
                        
                        // Pronouns and Sign
                        let pronounsText = viewModel.pronouns.isEmpty ? "pronouns" : viewModel.pronouns
                        let zodiacText = viewModel.zodiac.isEmpty ? "zodiac" : viewModel.zodiac
                        Text("\(pronounsText) || \(zodiacText)")
                            .font(.system(size: 16))
                            .foregroundColor(.black.opacity(0.6))
                        
                        // Info Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("location: \(viewModel.location.isEmpty ? "Add your location" : viewModel.location)")
                                .opacity(viewModel.showLocation ? 1 : 0)
                                .animation(.easeInOut, value: viewModel.showLocation)
                                .foregroundColor(viewModel.location.isEmpty ? .gray : .black)
                            Text("school: \(viewModel.school.isEmpty ? "Add your school" : viewModel.school)")
                                .opacity(viewModel.showSchool ? 1 : 0)
                                .animation(.easeInOut, value: viewModel.showSchool)
                                .foregroundColor(viewModel.school.isEmpty ? .gray : .black)
                            Text("interests: \(viewModel.interests.isEmpty ? "Add your interests" : viewModel.interests)")
                                .foregroundColor(viewModel.interests.isEmpty ? .gray : .black)
                        }
                        .font(.system(size: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 40)
                        .padding(.top, 16)
                        
                        // Edit Profile Button
                        Button(action: {
                            withAnimation {
                                isEditing = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 20))
                                Text("Edit Profile")
                                    .font(.system(size: 18))
                                Spacer()
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.mainBlue)
                            .cornerRadius(12)
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                        }
                        
                        // My Capsule Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("My Capsule")
                                .font(.system(size: 28, weight: .bold))
                                .padding(.horizontal, 24)
                                .padding(.top, 24)
                            
                            MyCapsuleView()
                                .padding(.horizontal, 24)
                        }
                        
                        Spacer(minLength: 80)
                    }
                }
                
                if !keyboardVisible {
                    BottomNavBar(currentTab: $currentTab) {
                        checkCameraPermission()
                    }
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
                            // Already on profile
                            break
                        case .camera:
                            // Camera is handled by onCameraTap
                            break
                        }
                    }
                }
            }
            .background(Color(red: 1, green: 0.989, blue: 0.93).ignoresSafeArea())
            
            // Edit Profile Overlay
            if isEditing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isEditing = false
                        }
                    }
                
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        // Profile Image that extends above the sheet
                        ZStack(alignment: .topTrailing) {
                            if let profileImage = viewModel.profileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: profileImageSize, height: profileImageSize)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: profileImageSize, height: profileImageSize)
                                    .overlay(
                                        Image(systemName: "person.circle")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .foregroundColor(Color.gray.opacity(0.3))
                                            .frame(width: profileImageSize, height: profileImageSize)
                                    )
                            }
                            
                            Button(action: {
                                showPhotoOptions = true
                            }) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .padding(8)
                                    .background(Circle().fill(.white))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .offset(x: 8, y: 8)
                        }
                        .offset(y: -profileImageSize/2)
                        .zIndex(1)
                        
                        // Edit Form
                        EditProfileSheet(viewModel: viewModel, isPresented: $isEditing)
                    }
                    .frame(width: geometry.size.width)
                    .position(x: geometry.size.width/2, y: geometry.size.height * 0.7)
                }
            }
        }
        .confirmationDialog("Change Profile Picture", isPresented: $showPhotoOptions, titleVisibility: .visible) {
            Button("Take Photo") {
                checkCameraPermission()
            }
            Button("Choose from Library") {
                showImagePicker = true
            }
            if viewModel.profileImage != nil {
                Button("Remove Photo", role: .destructive) {
                    viewModel.removeProfileImage()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showCamera) {
            CameraView(isPresented: $showCamera) { image in
                viewModel.updateProfileImage(image)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: Binding(
                get: { pendingProfileImage },
                set: { if let image = $0 { pendingProfileImage = image
                    showCropPreview = true
                }
            }
        ))
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
                                viewModel.updateProfileImage(adjustedImage)
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

        .sheet(isPresented: $showSettings) {
            ProfileSettingsView()
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
            
            print("🔍 ProfileView onAppear - Loading profile data")
            print("📊 Current viewModel data:")
            print("   name: '\(viewModel.name)'")
            print("   username: '\(viewModel.username)'") 
            print("   pronouns: '\(viewModel.pronouns)'")
            print("   zodiac: '\(viewModel.zodiac)'")
            print("   location: '\(viewModel.location)'")
            print("   school: '\(viewModel.school)'")
            print("   interests: '\(viewModel.interests)'")
            
            // Always force refresh to ensure latest data
            print("🔄 Forcing profile data refresh...")
            viewModel.forceRefresh()
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private var editForm: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    withAnimation {
                        isEditing = false
                        hideKeyboard()
                    }
                }
                .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0))
                
                Spacer()
                
                Button("Save") {
                    withAnimation {
                        isEditing = false
                        hideKeyboard()
                    }
                }
                .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0))
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Text("Edit Profile")
                .font(.system(size: 32, weight: .bold))
                .padding(.vertical, 24)
            
            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 24) {
                    ProfileField(title: "name", text: $viewModel.name)
                    
                    ProfileField(title: "username", text: $viewModel.username)
                    
                    // Custom Pronouns Menu
                    VStack(alignment: .leading, spacing: 4) {
                        Text("pronouns:")
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                        Menu(content: {
                            ForEach(pronounOptions, id: \.self) { option in
                                Button(action: {
                                    viewModel.pronouns = option
                                }) {
                                    Text(option)
                                        .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0))
                                }
                            }
                        }, label: {
                            HStack {
                                Text(viewModel.pronouns)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0))
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0))
                            }
                        })
                        .padding(.bottom, 4)
                        .overlay(
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0).opacity(0.4)),
                            alignment: .bottom
                        )
                    }
                    
                    ProfileField(title: "zodiac sign", text: $viewModel.zodiac)
                    ProfileField(title: "location", text: $viewModel.location)
                    ProfileField(title: "school", text: $viewModel.school)
                    ProfileField(title: "interests", text: $viewModel.interests)
                    
                    // Add padding at the bottom to ensure last field is visible
                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal, 24)
            }
        }
        .background(Color(red: 1, green: 0.988, blue: 0.929))
        .cornerRadius(32, corners: [.topLeft, .topRight])
    }
}

struct ProfileField: View {
    var title: String
    @Binding var text: String
    @State private var isEditing: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(title):")
                .font(.system(size: 16))
                .foregroundColor(.black)
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(title)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                TextField("", text: $text)
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0))
                    .tint(Color(red: 0.722, green: 0.369, blue: 0))
                    .textFieldStyle(.plain)
            }
            .padding(.vertical, 8)
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0).opacity(0.4))
        }
    }
}

// Helper extension for custom corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}

// Add LocationSearchField
struct LocationSearchField: View {
    @Binding var text: String
    @State private var searchText = ""
    @State private var locations: [String] = []
    @State private var isSearching = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("location:")
                .font(.system(size: 16))
                .foregroundColor(.black)
            
            ZStack(alignment: .leading) {
                if searchText.isEmpty {
                    Text("city, state")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                
                TextField("", text: $searchText)
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0))
                    .tint(Color(red: 0.722, green: 0.369, blue: 0))
                    .textFieldStyle(.plain)
                    .autocapitalization(.words)
                    .onChange(of: searchText) { newValue in
                        if !newValue.isEmpty {
                            searchLocations(query: newValue)
                        } else {
                            locations.removeAll()
                            isSearching = false
                        }
                    }
                    .onAppear {
                        searchText = text
                    }
            }
            .padding(.vertical, 8)
            
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0).opacity(0.4))
            
            if !locations.isEmpty && isSearching {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(locations, id: \.self) { location in
                        Button(action: {
                            text = location
                            searchText = location
                            isSearching = false
                            locations.removeAll()
                        }) {
                            Text(location)
                                .font(.system(size: 16))
                                .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(Color.white)
                        }
                        
                        if location != locations.last {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
    
    private func searchLocations(query: String) {
        isSearching = true
        
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = query
        searchRequest.resultTypes = .address
        
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            guard let response = response else {
                DispatchQueue.main.async {
                    locations.removeAll()
                    isSearching = false
                }
                return
            }
            
            DispatchQueue.main.async {
                let filteredLocations = response.mapItems
                    .compactMap { item -> String? in
                        guard let city = item.placemark.locality,
                              let state = item.placemark.administrativeArea else {
                            return nil
                        }
                        return "\(city), \(state)"
                    }
                    .removingDuplicates()
                    .sorted()
                    .prefix(5)
                
                locations = Array(filteredLocations)
                
                if locations.isEmpty {
                    isSearching = false
                }
            }
        }
    }
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// Update EditProfileSheet to use LocationSearchField
struct EditProfileSheet: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Binding var isPresented: Bool
    @FocusState private var focusedField: String?
    
    let pronounOptions = [
        "she/her",
        "he/him",
        "they/them",
        "other",
        "prefer not to answer"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ProfileField(title: "name", text: $viewModel.name)
                    
                    ProfileField(title: "username", text: $viewModel.username)
                    
                    // Custom Pronouns Menu
                    VStack(alignment: .leading, spacing: 4) {
                        Text("pronouns:")
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                        Menu(content: {
                            ForEach(pronounOptions, id: \.self) { option in
                                Button(action: {
                                    viewModel.pronouns = option
                                }) {
                                    Text(option)
                                        .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0))
                                }
                            }
                        }, label: {
                            HStack {
                                Text(viewModel.pronouns)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0))
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0))
                            }
                        })
                        .padding(.bottom, 4)
                        .overlay(
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0).opacity(0.4)),
                            alignment: .bottom
                        )
                    }
                    
                    ProfileField(title: "zodiac sign", text: $viewModel.zodiac)
                    LocationSearchField(text: $viewModel.location)
                    ProfileField(title: "school", text: $viewModel.school)
                    ProfileField(title: "interests", text: $viewModel.interests)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                // Add generous bottom spacing to ensure last item is visible
                Spacer(minLength: UIScreen.main.bounds.height * 0.3)
            }
            .background(Color(red: 1, green: 0.988, blue: 0.929))
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // Force sync all profile data across systems
                        viewModel.forceSyncAfterEdit()
                        isPresented = false
                    }
                    .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0))
                }
            }
        }
    }
}
