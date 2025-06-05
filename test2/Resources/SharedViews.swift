import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import AVFoundation
import FirebaseStorage

// MARK: - Reaction Button Component
struct ReactionButton: View {
    let entryId: String
    @ObservedObject var entryStore: EntryStore
    let groupMembers: [User]?
    
    @State private var showReactionMenu = false
    @State private var showImagePicker = false
    @State private var showComments = false
    @State private var showWhoReacted = false
    @State private var selectedImage: UIImage?
    @State private var showCameraPermissionAlert = false
    
    init(entryId: String, entryStore: EntryStore, groupMembers: [User]? = nil) {
        self.entryId = entryId
        self.entryStore = entryStore
        self.groupMembers = groupMembers
    }
    
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
                                // Prevent reacting to own posts with emojis
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
                                ProfilePictureView(userId: userId, size: 32, groupMembers: groupMembers)
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
                    // Allow viewing comments for own posts, but prevent emoji reactions
                    if isOwnPost() {
                        // For own posts, just show comments directly
                        showComments = true
                        return
                    }
                    
                    // Single tap - show menu for others' posts
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
                                    gradient: Gradient(colors: isOwnPost() ? [Color.blue, Color.cyan] : [Color.orange, Color.red]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .shadow(color: isOwnPost() ? .blue.opacity(0.4) : .orange.opacity(0.4), radius: 6, x: 0, y: 3)
                        
                        // Show comment icon for own posts, reaction icon for others
                        if isOwnPost() {
                            Image(systemName: "message.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .medium))
                        } else {
                            // Show most recent reaction or default icon
                            if let mostRecentReaction = getMostRecentReaction() {
                                Text(mostRecentReaction)
                                    .font(.system(size: 18))
                            } else {
                                Image(systemName: "face.smiling")
                                    .foregroundColor(.white)
                                    .font(.system(size: 18, weight: .medium))
                            }
                        }
                        
                        // Reaction count badge (or comment count for own posts)
                        if isOwnPost() && (entry?.comments.count ?? 0) > 0 {
                            Text("\(entry?.comments.count ?? 0)")
                                .font(.custom("Fredoka-Bold", size: 10))
                                .foregroundColor(.white)
                                .frame(width: 18, height: 18)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .offset(x: 15, y: -15)
                        } else if !isOwnPost() && getTotalReactionCount() > 0 {
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
                    // Long press behavior
                    if isOwnPost() {
                        // For own posts, also just show comments
                        showComments = true
                    } else {
                        // For others' posts, show reaction menu with extra haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                        impactFeedback.impactOccurred()
                        
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showReactionMenu = true
                        }
                    }
                }
            }
            
            // Custom overlay for reactions instead of sheet to avoid navigation conflicts
            if showWhoReacted {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showWhoReacted = false
                        }
                    }
                    .overlay(
                        VStack(spacing: 0) {
                            // Header
                            HStack {
                                Text("Reactions")
                                    .font(.custom("Fredoka-SemiBold", size: 20))
                                    .foregroundColor(.primary)
                                Spacer()
                                Button("Done") {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        showWhoReacted = false
                                    }
                                }
                                .font(.custom("Fredoka-Medium", size: 16))
                                .foregroundColor(.blue)
                            }
                            .padding(.horizontal)
                            .padding(.top)
                            .padding(.bottom, 8)
                            
                            // Content
                            WhoReactedView(entry: entry, groupMembers: groupMembers)
                        }
                        .background(Color.white)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 100)
                        .transition(.scale.combined(with: .opacity))
                    )
            }
            
            // Custom overlay for comments instead of sheet to avoid navigation conflicts
            if showComments {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showComments = false
                        }
                    }
                    .overlay(
                        VStack(spacing: 0) {
                            // Header - Fixed at top
                            HStack {
                                Text("Comments")
                                    .font(.custom("Fredoka-SemiBold", size: 20))
                                    .foregroundColor(.primary)
                                Spacer()
                                Button("Done") {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        showComments = false
                                    }
                                }
                                .font(.custom("Fredoka-Medium", size: 16))
                                .foregroundColor(.blue)
                            }
                            .padding(.horizontal)
                            .padding(.top)
                            .padding(.bottom, 8)
                            .background(Color.white) // Ensure header has white background
                            
                            // Scrollable Content
                            ScrollView {
                                EntryInteractionView(entryId: entryId, entryStore: entryStore)
                                    .padding(.bottom, 20) // Add bottom padding for better UX
                            }
                            .frame(maxHeight: .infinity) // Allow scroll view to expand
                        }
                        .background(Color.white)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 50)
                        .transition(.scale.combined(with: .opacity))
                    )
                    .zIndex(1000) // High z-index to ensure it appears on top
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ReactionImagePicker(image: $selectedImage)
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
        guard let entry = entry else { 
            print("🐛 ReactionButton: No entry found")
            return 0 
        }
        let count = entry.userReactions.count
        print("🐛 ReactionButton: Total reaction count for entry \(entry.id): \(count)")
        if count > 0 {
            print("🐛 ReactionButton: Reactions are:")
            for reaction in entry.userReactions {
                print("🐛    - \(reaction.emoji) by \(reaction.userId)")
            }
        }
        return count
    }
    
    private func getReactionUsers() -> [String] {
        guard let entry = entry else { return [] }
        return Array(Set(entry.userReactions.map { $0.userId }))
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
    let groupMembers: [User]?
    
    init(entry: DIMLEntry?, groupMembers: [User]? = nil) {
        self.entry = entry
        self.groupMembers = groupMembers
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let entry = entry, !entry.userReactions.isEmpty {
                List {
                    ForEach(entry.userReactions.sorted(by: { $0.timestamp > $1.timestamp }), id: \.id) { reaction in
                        HStack(spacing: 12) {
                            ProfilePictureView(userId: reaction.userId, size: 40, groupMembers: groupMembers)
                            
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
        
        // First, check if this is the current user
        if userId == currentUserId {
            return currentUserName
        }
        
        // Then, check group members for real user data
        if let groupMembers = groupMembers,
           let member = groupMembers.first(where: { $0.id == userId }) {
            return member.name
        }
        
        // Fallback to mock users for compatibility
        let mockUsers: [String: String] = [
            "user_0": "Emma",
            "user_1": "Liam", 
            "user_2": "Olivia",
            "user_3": "Noah",
            "user_4": "Ava",
            "user_5": "Sophia"
        ]
        
        return mockUsers[userId] ?? "Unknown User"
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
    let groupMembers: [User]?
    
    init(userId: String, size: CGFloat, groupMembers: [User]? = nil) {
        self.userId = userId
        self.size = size
        self.groupMembers = groupMembers
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(getPlaceholderColor(for: userId))
                .frame(width: size, height: size)
            
            if let profileImage = profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(getInitials())
                    .font(.custom("Fredoka-Medium", size: size * 0.4))
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            loadUserData()
        }
    }
    
    private func loadUserData() {
        // Get user name using the same logic as WhoReactedView
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        let currentUserName = SharedProfileViewModel.shared.name
        
        if userId == currentUserId {
            userName = currentUserName
        } else if let groupMembers = groupMembers,
                  let member = groupMembers.first(where: { $0.id == userId }) {
            userName = member.name
        } else {
            // Fallback to mock users
            let mockUsers: [String: String] = [
                "user_0": "Emma",
                "user_1": "Liam", 
                "user_2": "Olivia",
                "user_3": "Noah",
                "user_4": "Ava",
                "user_5": "Sophia"
            ]
            userName = mockUsers[userId] ?? "Unknown User"
        }
        
        // Try to load profile image
        loadProfileImage()
    }
    
    private func loadProfileImage() {
        Task {
            do {
                let storage = Storage.storage()
                let storageRef = storage.reference()
                let imagePath = "profile_images/\(userId).jpg"
                let imageRef = storageRef.child(imagePath)
                
                // Download image data from Firebase Storage
                let imageData = try await imageRef.data(maxSize: 10 * 1024 * 1024) // 10MB max
                
                await MainActor.run {
                    self.profileImage = UIImage(data: imageData)
                }
            } catch {
                print("Failed to load profile image for user \(userId): \(error)")
            }
        }
    }
    
    private func getInitials() -> String {
        guard let name = userName else { return "?" }
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else {
            return String(name.prefix(1)).uppercased()
        }
    }
    
    private func getPlaceholderColor(for userId: String) -> Color {
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .pink, .red, .teal, .indigo
        ]
        let hash = abs(userId.hashValue)
        return colors[hash % colors.count]
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