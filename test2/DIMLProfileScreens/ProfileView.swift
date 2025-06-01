import SwiftUI
import AVFoundation

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var currentTab: Tab = .profile
    @State private var showCamera = false
    @State private var showPermissionAlert = false
    @State private var showSettings = false
    @State private var isEditing = false
    @State private var showImagePicker = false
    @State private var showPhotoOptions = false
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
            // Main Profile View
            VStack(spacing: 0) {
                TopNavBar(showsMenu: true) {
                    showSettings = true
                }
                
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
                        Text(viewModel.name)
                            .font(.system(size: 32, weight: .bold))
                            .padding(.top, 8)
                        
                        // Pronouns and Sign
                        Text("\(viewModel.pronouns) || \(viewModel.zodiac)")
                            .font(.system(size: 16))
                            .foregroundColor(.black.opacity(0.6))
                        
                        // Info Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("location: \(viewModel.location)")
                            Text("school: \(viewModel.school)")
                            Text("interests: \(viewModel.interests)")
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
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 18))
                            }
                            .foregroundColor(.white)
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
                            
                            VStack(spacing: 0) {
                                Text("May 9th, 2025")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                            }
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
                            .padding(.horizontal, 24)
                        }
                        
                        Spacer(minLength: 80)
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
                        editForm
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
                get: { viewModel.profileImage },
                set: { if let image = $0 { viewModel.updateProfileImage(image) } }
            ))
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
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private var editForm: some View {
        VStack {
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
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ProfileField(title: "name", text: $viewModel.name)
                    
                    // Custom Pronouns Menu
                    VStack(alignment: .leading, spacing: 4) {
                        Text("pronouns:")
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                        Menu {
                            ForEach(pronounOptions, id: \.self) { option in
                                Button(action: {
                                    viewModel.pronouns = option
                                }) {
                                    Text(option)
                                        .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0))
                                }
                            }
                        } label: {
                            HStack {
                                Text(viewModel.pronouns)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0))
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0))
                            }
                        }
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
