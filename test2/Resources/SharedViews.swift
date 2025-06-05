import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import AVFoundation

// MARK: - Reaction Button Component
struct ReactionButton: View {
    let entryId: String
    @ObservedObject var entryStore: EntryStore
    @State private var showReactionMenu = false
    @State private var showImagePicker = false
    @State private var showComments = false
    @State private var showWhoReacted = false
    @State private var selectedImage: UIImage?
    @State private var showCameraPermissionAlert = false
    
    private var entry: DIMLEntry? {
        entryStore.entries.first { $0.id == entryId }
    }
    
    // All available reactions
    private let reactions = ["❤️", "😂", "👏", "🔥", "😍", "🤩", "💯", "✨"]
    
    var body: some View {
        ZStack {
            // Reaction menu overlay
            if showReactionMenu {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showReactionMenu = false
                        }
                    }
                
                VStack(spacing: 12) {
                    // Picture reaction button at the top
                    Button(action: {
                        checkCameraPermissionAndShow()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                            Text("Picture reaction")
                                .foregroundColor(.white)
                                .font(.custom("Fredoka-Medium", size: 14))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.purple, Color.blue]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(25)
                        .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    
                    // Comments button
                    Button(action: {
                        showComments = true
                        withAnimation(.easeOut(duration: 0.2)) {
                            showReactionMenu = false
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "message.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                            Text("Comments (\(entry?.comments.count ?? 0))")
                                .foregroundColor(.white)
                                .font(.custom("Fredoka-Medium", size: 14))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.cyan]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(25)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    
                    // Emoji reactions grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(reactions, id: \.self) { emoji in
                            Button(action: {
                                // Prevent reacting to own posts
                                if isOwnPost() {
                                    return
                                }
                                
                                // Add haptic feedback first
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                
                                // Add the reaction
                                entryStore.addReaction(to: entryId, reaction: emoji)
                                
                                // Dismiss the menu with a slight delay to ensure the reaction is processed
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        showReactionMenu = false
                                    }
                                }
                            }) {
                                VStack(spacing: 4) {
                                    Text(emoji)
                                        .font(.system(size: 24))
                                    Text("\(getReactionCount(for: emoji))")
                                        .font(.custom("Fredoka-Regular", size: 10))
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 50, height: 50)
                                .background(getCurrentUserReaction() == emoji ? Color.blue.opacity(0.2) : Color.white)
                                .cornerRadius(25)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                .overlay(
                                    // Highlight border if this is the current user's reaction
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(getCurrentUserReaction() == emoji ? Color.blue : Color.clear, lineWidth: 2)
                                )
                                .opacity(isOwnPost() ? 0.5 : 1.0) // Dim for own posts
                            }
                            .disabled(isOwnPost()) // Disable for own posts
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                .padding(.horizontal, 40)
                .transition(.scale.combined(with: .opacity))
            }
            
            // Profile pictures and reaction button layout
            HStack(spacing: 8) {
                // Show profile pictures of people who reacted
                if getTotalReactionCount() > 0 {
                    Button(action: {
                        showWhoReacted = true
                    }) {
                        HStack(spacing: -8) {
                            ForEach(getReactionUsers().prefix(3), id: \.self) { userId in
                                ProfilePictureView(userId: userId, size: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                            }
                            
                            // Show count if more than 3 people reacted
                            if getReactionUsers().count > 3 {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Text("+\(getReactionUsers().count - 3)")
                                            .font(.custom("Fredoka-Bold", size: 10))
                                            .foregroundColor(.black)
                                    )
                            }
                        }
                    }
                }
                
                // Main reaction button
                Button(action: {
                    // Don't show menu for own posts
                    if isOwnPost() {
                        return
                    }
                    
                    // Single tap - show menu
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showReactionMenu = true
                    }
                    
                    // Add haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.orange, Color.red]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .shadow(color: .orange.opacity(0.4), radius: 6, x: 0, y: 3)
                        
                        // Show most recent reaction or default icon
                        if let mostRecentReaction = getMostRecentReaction() {
                            Text(mostRecentReaction)
                                .font(.system(size: 18))
                        } else {
                            Image(systemName: "face.smiling")
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .medium))
                        }
                        
                        // Reaction count badge
                        if getTotalReactionCount() > 0 {
                            Text("\(getTotalReactionCount())")
                                .font(.custom("Fredoka-Bold", size: 10))
                                .foregroundColor(.white)
                                .frame(width: 18, height: 18)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 15, y: -15)
                        }
                    }
                }
                .onLongPressGesture(minimumDuration: 0.3) {
                    // Long press - also show menu with extra haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                    impactFeedback.impactOccurred()
                    
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showReactionMenu = true
                    }
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ReactionImagePicker(image: $selectedImage)
        }
        .sheet(isPresented: $showComments) {
            VStack {
                HStack {
                    Text("Comments")
                        .font(.custom("Fredoka-SemiBold", size: 20))
                        .foregroundColor(.primary)
                    Spacer()
                    Button("Done") {
                        showComments = false
                    }
                    .font(.custom("Fredoka-Medium", size: 16))
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
                .padding(.top)
                
                EntryInteractionView(entryId: entryId, entryStore: entryStore)
            }
            .apply { view in
                if #available(iOS 16.0, *) {
                    view.presentationDetents([.medium, .large])
                } else {
                    view
                }
            }
        }
        .sheet(isPresented: $showWhoReacted) {
            VStack {
                HStack {
                    Text("Reactions")
                        .font(.custom("Fredoka-SemiBold", size: 20))
                        .foregroundColor(.primary)
                    Spacer()
                    Button("Done") {
                        showWhoReacted = false
                    }
                    .font(.custom("Fredoka-Medium", size: 16))
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
                .padding(.top)
                
                WhoReactedView(entry: entry)
            }
        }
        .onChange(of: selectedImage) { image in
            if let image = image {
                handlePictureReaction(image)
                selectedImage = nil
            }
        }
        .alert("Camera Access Required", isPresented: $showCameraPermissionAlert) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable camera access in Settings to take picture reactions.")
        }
    }
    
    private func getMostRecentReaction() -> String? {
        guard let entry = entry, !entry.userReactions.isEmpty else { return nil }
        // Return the most recent reaction emoji
        return entry.userReactions.max(by: { $0.timestamp < $1.timestamp })?.emoji
    }
    
    private func getTotalReactionCount() -> Int {
        guard let entry = entry else { return 0 }
        return entry.userReactions.count
    }
    
    private func getReactionUsers() -> [String] {
        guard let entry = entry else { return [] }
        return entry.getUsersWhoReacted()
    }
    
    private func handlePictureReaction(_ image: UIImage) {
        // Convert image to comment instead of just adding camera emoji reaction
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ No current user for picture comment")
            return
        }
        
        // Convert UIImage to Data for storage
        let imageData = image.jpegData(compressionQuality: 0.8)
        
        // Create a new comment with the image
        let pictureComment = Comment(
            id: UUID().uuidString,
            userId: currentUserId,
            text: "📸 Shared a photo",
            timestamp: Date(),
            imageData: imageData,
            imageURL: nil
        )
        
        // Add the comment to the entry
        entryStore.addComment(to: entryId, comment: pictureComment)
        
        // Add success haptic feedback
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)
        
        print("📸 Picture comment added for entry: \(entryId)")
        
        // Show the comments section so user can see their photo comment
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showComments = true
        }
    }
    
    private func getReactionCount(for reaction: String) -> Int {
        guard let entry = entry else { return 0 }
        return entry.userReactions.filter { $0.emoji == reaction }.count
    }
    
    private func getCurrentUserReaction() -> String? {
        guard let entry = entry,
              let currentUserId = Auth.auth().currentUser?.uid else { return nil }
        return entry.getUserReaction(for: currentUserId)?.emoji
    }
    
    private func isOwnPost() -> Bool {
        guard let entry = entry,
              let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return entry.userId == currentUserId
    }
    
    private func checkCameraPermissionAndShow() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Permission already granted
            showImagePicker = true
            withAnimation(.easeOut(duration: 0.2)) {
                showReactionMenu = false
            }
        case .notDetermined:
            // Request permission
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showImagePicker = true
                        withAnimation(.easeOut(duration: 0.2)) {
                            showReactionMenu = false
                        }
                    } else {
                        showCameraPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            // Permission denied
            showCameraPermissionAlert = true
        @unknown default:
            showCameraPermissionAlert = true
        }
    }
}

// MARK: - Who Reacted View
struct WhoReactedView: View {
    let entry: DIMLEntry?
    
    var body: some View {
        VStack(spacing: 0) {
            if let entry = entry, !entry.userReactions.isEmpty {
                List {
                    ForEach(entry.userReactions.sorted(by: { $0.timestamp > $1.timestamp }), id: \.id) { reaction in
                        HStack(spacing: 12) {
                            ProfilePictureView(userId: reaction.userId, size: 40)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(getUserName(for: reaction.userId))
                                    .font(.custom("Fredoka-Medium", size: 16))
                                    .foregroundColor(.primary)
                                Text("@\(getUserUsername(for: reaction.userId))")
                                    .font(.custom("Fredoka-Regular", size: 14))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            VStack(spacing: 4) {
                                Text(reaction.emoji)
                                    .font(.system(size: 24))
                                Text(reaction.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(PlainListStyle())
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No reactions yet")
                        .font(.custom("Fredoka-Medium", size: 18))
                        .foregroundColor(.gray)
                    Text("Be the first to react!")
                        .font(.custom("Fredoka-Regular", size: 14))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func getUserName(for userId: String) -> String {
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        let currentUserName = SharedProfileViewModel.shared.name
        
        let mockUsers: [String: String] = [
            currentUserId: currentUserName,
            "user_0": "Emma",
            "user_1": "Liam", 
            "user_2": "Olivia",
            "user_3": "Noah",
            "user_4": "Ava",
            "user_5": "Sophia"
        ]
        return mockUsers[userId] ?? "User"
    }
    
    private func getUserUsername(for userId: String) -> String {
        let name = getUserName(for: userId)
        return name.lowercased().replacingOccurrences(of: " ", with: "")
    }
}

// MARK: - Profile Picture View
struct ProfilePictureView: View {
    let userId: String
    let size: CGFloat
    @State private var profileImage: UIImage?
    @State private var userName: String?
    
    var body: some View {
        SwiftUI.Group {
            if let profileImage = profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // Show a more realistic profile picture placeholder
                ZStack {
                    Circle()
                        .fill(getPlaceholderColor(for: userId))
                        .frame(width: size, height: size)
                    
                    // Use SF Symbols for more realistic profile pictures
                    Image(systemName: getProfileIcon(for: userId))
                        .font(.system(size: size * 0.5, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            loadUserProfile()
        }
    }
    
    private func loadUserProfile() {
        userName = getUserName(for: userId)
        loadMockProfilePicture()
    }
    
    private func loadMockProfilePicture() {
        // Create a more realistic mock profile picture
        let mockProfilePictures = getMockProfilePictures()
        
        if let mockImage = mockProfilePictures[userId] {
            self.profileImage = mockImage
        } else {
            // For unknown users, create a generated profile picture
            self.profileImage = generateProfilePicture(for: userId)
        }
    }
    
    private func getMockProfilePictures() -> [String: UIImage] {
        var mockImages: [String: UIImage] = [:]
        
        // For the current user, try to create a personalized image
        if let currentUserId = Auth.auth().currentUser?.uid {
            mockImages[currentUserId] = generateProfilePicture(for: currentUserId, isCurrentUser: true)
        }
        
        // For mock users, create distinct profile pictures
        let mockUserIds = ["user_0", "user_1", "user_2", "user_3", "user_4", "user_5"]
        for (index, userId) in mockUserIds.enumerated() {
            mockImages[userId] = generateProfilePicture(for: userId, index: index)
        }
        
        return mockImages
    }
    
    private func generateProfilePicture(for userId: String, isCurrentUser: Bool = false, index: Int = 0) -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // Create gradient background
            let colors = getGradientColors(for: userId, index: index)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: [colors.0.cgColor, colors.1.cgColor] as CFArray, locations: [0.0, 1.0])!
            
            cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size.width, y: size.height), options: [])
            
            // Add user initials
            let initials = getInitials(for: userId)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 40, weight: .semibold),
                .foregroundColor: UIColor.white
            ]
            
            let attributedString = NSAttributedString(string: initials, attributes: attributes)
            let textSize = attributedString.size()
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            attributedString.draw(in: textRect)
            
            // Add a subtle border
            cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.3).cgColor)
            cgContext.setLineWidth(2)
            cgContext.strokeEllipse(in: CGRect(origin: .zero, size: size))
        }
    }
    
    private func getGradientColors(for userId: String, index: Int) -> (UIColor, UIColor) {
        let gradients: [(UIColor, UIColor)] = [
            (UIColor.systemBlue, UIColor.systemCyan),
            (UIColor.systemPurple, UIColor.systemPink),
            (UIColor.systemOrange, UIColor.systemRed),
            (UIColor.systemGreen, UIColor.systemTeal),
            (UIColor.systemIndigo, UIColor.systemBlue),
            (UIColor.systemPink, UIColor.systemPurple),
            (UIColor.systemRed, UIColor.systemOrange),
            (UIColor.systemTeal, UIColor.systemGreen)
        ]
        
        let colorIndex = abs(userId.hashValue + index) % gradients.count
        return gradients[colorIndex]
    }
    
    private func getUserName(for userId: String) -> String {
        // Mock user names - in a real implementation, fetch from Firestore
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        let currentUserName = SharedProfileViewModel.shared.name
        
        let mockUsers: [String: String] = [
            currentUserId: currentUserName,
            "user_0": "Emma",
            "user_1": "Liam", 
            "user_2": "Olivia",
            "user_3": "Noah",
            "user_4": "Ava",
            "user_5": "Sophia"
        ]
        return mockUsers[userId] ?? "User"
    }
    
    private func getPlaceholderColor(for userId: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .cyan, .red, .indigo]
        let index = abs(userId.hashValue) % colors.count
        return colors[index]
    }
    
    private func getProfileIcon(for userId: String) -> String {
        let icons = ["person.fill", "person.crop.circle.fill", "face.smiling.fill", "person.circle.fill"]
        let index = abs(userId.hashValue) % icons.count
        return icons[index]
    }
    
    private func getInitials(for userId: String) -> String {
        let name = getUserName(for: userId)
        let components = name.components(separatedBy: " ")
        let initials = components.compactMap { $0.first }.map { String($0) }.joined()
        return String(initials.prefix(2)).uppercased()
    }
}

// MARK: - Image Picker Helper for Reactions
struct ReactionImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera // Use camera instead of photo library
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ReactionImagePicker
        
        init(_ parent: ReactionImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // Use edited image if available, otherwise use original
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Image Adjustment View
struct ImageAdjustmentView: View {
    let image: UIImage
    let onConfirm: (UIImage) -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background circle to show bounds
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                
                // Image with gestures
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                },
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale *= delta
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                }
                        )
                    )
                    .clipShape(Circle())
                    .onChange(of: scale) { _ in
                        // Ensure minimum zoom level
                        if scale < 1.0 {
                            scale = 1.0
                        }
                    }
                
                // Confirm button overlay
                VStack {
                    Spacer()
                    Button("Set Photo") {
                        let size = CGSize(width: geometry.size.width, height: geometry.size.width)
                        createAdjustedImage(size: size) { adjustedImage in
                            if let adjustedImage = adjustedImage {
                                onConfirm(adjustedImage)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 20)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.bottom)
                }
            }
        }
    }
    
    private func createAdjustedImage(size: CGSize, completion: @escaping (UIImage?) -> Void) {
        let renderer = UIGraphicsImageRenderer(size: size)
        let adjustedImage = renderer.image { context in
            // Create circular clipping path
            let circlePath = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
            circlePath.addClip()
            
            // Calculate the scaled image size while maintaining aspect ratio
            let imageAspect = image.size.width / image.size.height
            let viewAspect = size.width / size.height
            
            var drawSize = size
            if imageAspect > viewAspect {
                drawSize.width = size.height * imageAspect
            } else {
                drawSize.height = size.width / imageAspect
            }
            
            // Apply scale
            drawSize.width *= scale
            drawSize.height *= scale
            
            // Center the image and apply offset
            let drawPoint = CGPoint(
                x: (size.width - drawSize.width) * 0.5 + offset.width,
                y: (size.height - drawSize.height) * 0.5 + offset.height
            )
            
            // Draw the image
            image.draw(in: CGRect(origin: drawPoint, size: drawSize))
        }
        completion(adjustedImage)
    }
}

// MARK: - View Extensions
extension View {
    @ViewBuilder
    func apply<Content: View>(@ViewBuilder transform: (Self) -> Content) -> Content {
        transform(self)
    }
} 