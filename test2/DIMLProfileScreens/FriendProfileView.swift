import SwiftUI
import FirebaseFirestore

struct FriendProfileView: View {
    let user: User
    @Environment(\.dismiss) var dismiss
    private let profileImageSize: CGFloat = 120
    private let mainYellow = Color(red: 1.0, green: 0.75, blue: 0)
    
    @State private var fullUserData: User?
    @State private var isLoading = true
    @State private var friendEntries: [DIMLEntry] = []
    @State private var isLoadingEntries = true
    @State private var friendDailyCapsules: [FriendDailyCapsule] = []
    @State private var selectedFriendCapsule: FriendDailyCapsule?
    @State private var showFriendCapsuleDetail = false
    
    // Generate consistent color for user based on their ID
    private func getPlaceholderColor() -> Color {
        return Color.gray.opacity(0.3) // Consistent light grey for all users
    }
    
    var displayUser: User {
        return fullUserData ?? user
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Navigation Bar
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.black)
                        .imageScale(.large)
                }
                
                Spacer()
                
                Text(displayUser.name)
                    .font(.custom("Fredoka-Medium", size: 20))
                
                Spacer()
                
                // Empty view to balance the back button
                Color.clear
                    .frame(width: 24, height: 24)
            }
            .padding()
            .background(Color.white)
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            
            if isLoading {
                // Loading state
                VStack(spacing: 20) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading profile...")
                        .font(.custom("Fredoka-Regular", size: 16))
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Image Section
                        VStack(spacing: 16) {
                            AsyncImage(url: URL(string: displayUser.profileImageUrl ?? "")) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Circle()
                                    .fill(getPlaceholderColor())
                                    .overlay(
                                        Text(displayUser.name.prefix(1).uppercased())
                                            .font(.system(size: 40, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                    )
                            }
                            .frame(width: profileImageSize, height: profileImageSize)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                                    .shadow(color: .gray.opacity(0.3), radius: 8, x: 0, y: 4)
                            )
                            .padding(.top, 40)
                            
                            // Name and pronouns
                            VStack(spacing: 8) {
                                Text(displayUser.name)
                                    .font(.custom("Fredoka-Bold", size: 32))
                                    .multilineTextAlignment(.center)
                                
                                if let pronouns = displayUser.pronouns, !pronouns.isEmpty {
                                    Text("(\(pronouns))")
                                        .font(.custom("Fredoka-Regular", size: 18))
                                        .foregroundColor(.gray)
                                }
                                
                                // Username
                                if let username = displayUser.username, !username.isEmpty {
                                    Text("@\(username)")
                                        .font(.custom("Fredoka-Regular", size: 16))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        // Profile Information Cards
                        VStack(spacing: 16) {
                            // Location Card
                            if let location = displayUser.location, !location.isEmpty {
                                profileInfoCard(
                                    icon: "location.fill",
                                    iconColor: .red,
                                    title: "Location",
                                    value: location
                                )
                            }
                            
                            // School Card
                            if let school = displayUser.school, !school.isEmpty {
                                profileInfoCard(
                                    icon: "graduationcap.fill",
                                    iconColor: .blue,
                                    title: "School",
                                    value: school
                                )
                            }
                            
                            // Zodiac Sign Card
                            if let zodiacSign = displayUser.zodiacSign, !zodiacSign.isEmpty {
                                profileInfoCard(
                                    icon: "sparkles",
                                    iconColor: .purple,
                                    title: "Zodiac Sign",
                                    value: zodiacSign
                                )
                            }
                            
                            // Interests Card
                            if let interests = displayUser.interests, !interests.isEmpty {
                                profileInfoCard(
                                    icon: "heart.fill",
                                    iconColor: mainYellow,
                                    title: "Interests",
                                    value: interests
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        // Capsule Section - Show actual DIML entries
                        VStack(alignment: .leading, spacing: 16) {
                            Text("\(displayUser.name)'s Capsule")
                                .font(.custom("Fredoka-Bold", size: 24))
                                .padding(.horizontal, 24)
                            
                            if isLoadingEntries {
                                // Loading state for entries
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(height: 300)
                                    .overlay(
                                        VStack(spacing: 8) {
                                            ProgressView()
                                                .scaleEffect(1.2)
                                            Text("Loading \(displayUser.name)'s DIMLs...")
                                                .font(.custom("Fredoka-Regular", size: 16))
                                                .foregroundColor(.gray)
                                        }
                                    )
                                    .padding(.horizontal, 24)
                            } else if friendEntries.isEmpty {
                                // No entries state
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                                    .frame(height: 300)
                                    .overlay(
                                        VStack(spacing: 12) {
                                            Image(systemName: "photo.stack")
                                                .font(.system(size: 48))
                                                .foregroundColor(.gray.opacity(0.5))
                                            
                                            Text("\(displayUser.name)'s DIML Capsule")
                                                .font(.custom("Fredoka-Medium", size: 20))
                                                .foregroundColor(.black)
                                            
                                            Text("This user hasn't shared any DIMLs yet")
                                                .font(.custom("Fredoka-Regular", size: 16))
                                                .foregroundColor(.gray)
                                                .multilineTextAlignment(.center)
                                        }
                                    )
                                    .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
                                    .padding(.horizontal, 24)
                            } else {
                                // Show daily capsules with flickering preview
                                VStack(spacing: 8) {
                                    ForEach(friendDailyCapsules.prefix(3)) { capsule in
                                        FriendDailyCapsuleCard(
                                            capsule: capsule,
                                            isFirstCard: capsule.id == friendDailyCapsules.first?.id
                                        ) {
                                            selectedFriendCapsule = capsule
                                            showFriendCapsuleDetail = true
                                        }
                                    }
                                    
                                    if friendDailyCapsules.count > 3 {
                                        Button(action: {
                                            // Show all capsules view - could implement later
                                        }) {
                                            Text("View \(friendDailyCapsules.count - 3) more capsules...")
                                                .font(.custom("Fredoka-Regular", size: 14))
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                                
                                // Total entry count
                                if !friendEntries.isEmpty {
                                    Text("\(friendEntries.count) DIML\(friendEntries.count == 1 ? "" : "s") collected across \(friendDailyCapsules.count) day\(friendDailyCapsules.count == 1 ? "" : "s")")
                                        .font(.custom("Fredoka-Regular", size: 14))
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 24)
                                }
                            }
                        }
                        
                        Spacer(minLength: 80)
                    }
                }
            }
        }
        .background(Color(red: 1, green: 0.989, blue: 0.93).ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showFriendCapsuleDetail) {
            if let capsule = selectedFriendCapsule {
                FriendCapsuleDetailView(capsule: capsule, friendName: displayUser.name)
            }
        }
        .onAppear {
            loadFullUserData()
            loadFriendEntries()
        }
    }
    
    private func profileInfoCard(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 30)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Fredoka-Medium", size: 14))
                    .foregroundColor(.gray)
                
                Text(value)
                    .font(.custom("Fredoka-Regular", size: 16))
                    .foregroundColor(.black)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
    }
    
    private func loadFullUserData() {
        // If we already have full data, no need to fetch again
        if user.profileImageUrl != nil && user.pronouns != nil {
            fullUserData = user
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        
        db.collection("users").document(user.id).getDocument { document, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("❌ Error fetching full user profile: \(error.localizedDescription)")
                    self.fullUserData = user // Use whatever data we have
                    return
                }
                
                guard let document = document,
                      document.exists,
                      let data = document.data() else {
                    print("❌ No user document found for profile view")
                    self.fullUserData = user // Use whatever data we have
                    return
                }
                
                // Create enhanced User object with all available data
                self.fullUserData = User(
                    id: user.id,
                    name: data["name"] as? String ?? user.name,
                    username: data["username"] as? String ?? user.username,
                    email: data["email"] as? String ?? user.email,
                    role: user.role,
                    profileImageUrl: data["profileImageURL"] as? String,
                    pronouns: data["pronouns"] as? String,
                    zodiacSign: data["zodiacSign"] as? String,
                    location: data["location"] as? String,
                    school: data["school"] as? String,
                    interests: data["interests"] as? String
                )
                
                print("✅ Loaded full profile data for: \(self.fullUserData?.name ?? "Unknown")")
                if let imageURL = self.fullUserData?.profileImageUrl, !imageURL.isEmpty {
                    print("📸 Profile has image URL: \(imageURL)")
                } else {
                    print("📸 Profile has no image URL")
                }
            }
        }
    }
    
    private func loadFriendEntries() {
        let db = Firestore.firestore()
        
        // Find all groups where this user is a member
        db.collection("groups")
            .whereField("memberIds", arrayContains: user.id)
            .getDocuments { (snapshot, error) in
                if let error = error {
                    print("❌ Error fetching friend's groups: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isLoadingEntries = false
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("❌ No groups found for friend")
                    DispatchQueue.main.async {
                        self.isLoadingEntries = false
                    }
                    return
                }
                
                print("🔍 Found \(documents.count) groups for friend \(user.name)")
                
                // Collect all entries from all groups
                var allEntries: [DIMLEntry] = []
                let dispatchGroup = DispatchGroup()
                
                for groupDoc in documents {
                    dispatchGroup.enter()
                    let groupId = groupDoc.documentID
                    
                    // Fetch entries for this group
                    db.collection("groups").document(groupId).collection("entries")
                        .whereField("userId", isEqualTo: user.id) // Only entries by this friend
                        .getDocuments { (entriesSnapshot, entriesError) in
                            defer { dispatchGroup.leave() }
                            
                            if let entriesError = entriesError {
                                print("❌ Error fetching entries for group \(groupId): \(entriesError.localizedDescription)")
                                return
                            }
                            
                            guard let entriesDocuments = entriesSnapshot?.documents else {
                                print("❌ No entries found for group \(groupId)")
                                return
                            }
                            
                            print("🔍 Found \(entriesDocuments.count) entries in group \(groupId) for friend \(user.name)")
                            
                            for entryDoc in entriesDocuments {
                                let data = entryDoc.data()
                                
                                // Parse the entry
                                if let prompt = data["prompt"] as? String,
                                   let response = data["response"] as? String,
                                   let timestamp = data["timestamp"] as? Timestamp {
                                    
                                    let entry = DIMLEntry(
                                        id: entryDoc.documentID,
                                        userId: data["userId"] as? String ?? "",
                                        prompt: prompt,
                                        response: response,
                                        image: nil,
                                        imageURL: data["imageURL"] as? String,
                                        timestamp: timestamp.dateValue(),
                                        frameSize: FrameSize.medium,
                                        promptType: .text
                                    )
                                    
                                    allEntries.append(entry)
                                }
                            }
                        }
                }
                
                // When all groups have been processed
                dispatchGroup.notify(queue: .main) {
                    print("✅ Loaded \(allEntries.count) total entries for friend \(user.name)")
                    self.friendEntries = allEntries.sorted { $0.timestamp > $1.timestamp }
                    self.friendDailyCapsules = self.groupFriendEntriesByDate(self.friendEntries)
                    self.isLoadingEntries = false
                    
                    print("🗃️ FriendProfile: Created \(self.friendDailyCapsules.count) daily capsules for friend")
                }
            }
    }
    
    private func groupFriendEntriesByDate(_ entries: [DIMLEntry]) -> [FriendDailyCapsule] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.timestamp)
        }
        
        return grouped.map { date, entries in
            FriendDailyCapsule(date: date, entries: entries.sorted { $0.timestamp > $1.timestamp })
        }.sorted { $0.date > $1.date }
    }
}

// MARK: - Convenience initializer for SuggestedUser compatibility
extension FriendProfileView {
    init(suggestedUser: SuggestedUser) {
        self.init(user: User(
            id: UUID().uuidString, // This should ideally be passed from the suggested user
            name: suggestedUser.name,
            username: suggestedUser.username,
            role: .member
        ))
    }
}

struct FriendProfileView_Previews: PreviewProvider {
    static var previews: some View {
        FriendProfileView(user: User(
            id: "preview",
            name: "Sarah Chen",
            username: "sarahc",
            email: "sarah@example.com",
            role: .member,
            profileImageUrl: nil,
            pronouns: "she/her",
            zodiacSign: "Gemini",
            location: "San Francisco, CA",
            school: "UC Berkeley",
            interests: "Photography, hiking, coffee"
        ))
    }
}

// MARK: - Friend Capsule Entry View
struct FriendCapsuleEntryView: View {
    let entry: DIMLEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image or placeholder
            if let imageURL = entry.imageURL, !imageURL.isEmpty {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                        )
                }
                .frame(width: 140, height: 100)
                .cornerRadius(12)
                .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 140, height: 100)
                    .cornerRadius(12)
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: "text.quote")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                            Text("Text")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    )
            }
            
            // Prompt text (truncated)
            Text(entry.prompt)
                .font(.custom("Fredoka-Medium", size: 12))
                .foregroundColor(.black)
                .lineLimit(2)
                .frame(width: 140, alignment: .leading)
            
            // Response text (truncated)
            if !entry.response.isEmpty {
                Text(entry.response)
                    .font(.custom("Fredoka-Regular", size: 10))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .frame(width: 140, alignment: .leading)
            }
            
            // Timestamp
            Text(timeAgoString(from: entry.timestamp))
                .font(.custom("Fredoka-Regular", size: 9))
                .foregroundColor(.gray.opacity(0.8))
        }
        .padding(8)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Friend Daily Capsule Structure
struct FriendDailyCapsule: Identifiable {
    let id = UUID()
    let date: Date
    let entries: [DIMLEntry]
    
    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var previewEntry: DIMLEntry? {
        entries.first
    }
    
    var hasImages: Bool {
        entries.contains { $0.imageURL != nil }
    }
}

// MARK: - Friend Daily Capsule Card
struct FriendDailyCapsuleCard: View {
    let capsule: FriendDailyCapsule
    let isFirstCard: Bool
    let onTap: () -> Void
    
    @State private var currentEntryIndex = 0
    @State private var timer: Timer?
    
    private let flickerInterval: TimeInterval = 2.0
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .frame(height: isFirstCard ? 300 : 200)
                .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
            
            VStack(spacing: 0) {
                // Date header with entry count
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(capsule.displayDate)
                            .font(.custom("Fredoka-Medium", size: isFirstCard ? 16 : 14))
                            .foregroundColor(.gray)
                        
                        Text("\(capsule.entries.count) DIML\(capsule.entries.count == 1 ? "" : "s")")
                            .font(.custom("Fredoka-Regular", size: isFirstCard ? 12 : 10))
                            .foregroundColor(.gray.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // Flickering indicator if multiple entries
                    if capsule.entries.count > 1 {
                        HStack(spacing: 4) {
                            ForEach(0..<min(capsule.entries.count, 5), id: \.self) { index in
                                Circle()
                                    .fill(index == currentEntryIndex % min(capsule.entries.count, 5) ? Color.blue : Color.gray.opacity(0.3))
                                    .frame(width: 6, height: 6)
                            }
                            
                            if capsule.entries.count > 5 {
                                Text("+\(capsule.entries.count - 5)")
                                    .font(.custom("Fredoka-Regular", size: 10))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // Flickering content area
                if currentEntryIndex < capsule.entries.count {
                    let entry = capsule.entries[currentEntryIndex]
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Prompt text
                        Text(entry.prompt)
                            .font(.custom("Fredoka-Medium", size: isFirstCard ? 16 : 14))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(isFirstCard ? 3 : 2)
                            .padding(.horizontal, 16)
                        
                        // Content area - image or text response
                        if let imageURL = entry.imageURL {
                            AsyncImage(url: URL(string: imageURL)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: isFirstCard ? 180 : 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: isFirstCard ? 180 : 120)
                                    .overlay(
                                        ProgressView()
                                    )
                            }
                            .padding(.horizontal, 16)
                        } else if !entry.response.isEmpty {
                            // Text response
                            Text(entry.response)
                                .font(.custom("Fredoka-Regular", size: isFirstCard ? 16 : 14))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(isFirstCard ? 6 : 4)
                                .padding(12)
                                .background(Color(red: 1.0, green: 0.95, blue: 0.80))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal, 16)
                        }
                        
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                Spacer()
            }
        }
        .frame(height: isFirstCard ? 300 : 200)
        .onTapGesture {
            print("🔍 FriendDailyCapsuleCard: Tap detected on capsule for \(capsule.displayDate)")
            onTap()
        }
        .onAppear {
            startFlickering()
        }
        .onDisappear {
            stopFlickering()
        }
    }
    
    private func startFlickering() {
        guard capsule.entries.count > 1 else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: flickerInterval, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                currentEntryIndex = (currentEntryIndex + 1) % capsule.entries.count
            }
        }
    }
    
    private func stopFlickering() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Friend Capsule Detail View
struct FriendCapsuleDetailView: View {
    let capsule: FriendDailyCapsule
    let friendName: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Enhanced Header
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(capsule.displayDate)
                                    .font(.custom("Fredoka-Bold", size: 28))
                                    .foregroundColor(.black)
                                
                                Text("\(capsule.entries.count) DIML\(capsule.entries.count == 1 ? "" : "s") from \(friendName)")
                                    .font(.custom("Fredoka-Regular", size: 16))
                                    .foregroundColor(.gray)
                                
                                // Summary info
                                let imageCount = capsule.entries.filter { $0.imageURL != nil }.count
                                let textCount = capsule.entries.count - imageCount
                                
                                HStack(spacing: 16) {
                                    if imageCount > 0 {
                                        HStack(spacing: 4) {
                                            Image(systemName: "photo.fill")
                                                .foregroundColor(.blue)
                                            Text("\(imageCount)")
                                                .font(.custom("Fredoka-Regular", size: 14))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                    if textCount > 0 {
                                        HStack(spacing: 4) {
                                            Image(systemName: "text.alignleft")
                                                .foregroundColor(.green)
                                            Text("\(textCount)")
                                                .font(.custom("Fredoka-Regular", size: 14))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        
                        // Day's timeline
                        if capsule.entries.count > 1 {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Timeline")
                                    .font(.custom("Fredoka-Medium", size: 16))
                                    .foregroundColor(.black)
                                
                                let timeRange = getTimeRange(for: capsule.entries)
                                Text(timeRange)
                                    .font(.custom("Fredoka-Regular", size: 14))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // All entries for this day
                    ForEach(Array(capsule.entries.enumerated()), id: \.element.id) { index, entry in
                        VStack(spacing: 12) {
                            // Entry number indicator for multiple entries
                            if capsule.entries.count > 1 {
                                HStack {
                                    Text("Entry \(index + 1)")
                                        .font(.custom("Fredoka-Medium", size: 14))
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    
                                    Spacer()
                                    
                                    Text(formatDetailTime(entry.timestamp))
                                        .font(.custom("Fredoka-Regular", size: 14))
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 20)
                            }
                            
                            FriendEntryDetailCard(entry: entry, showTimestamp: capsule.entries.count == 1)
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color(red: 1, green: 0.989, blue: 0.93))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.custom("Fredoka-Medium", size: 16))
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private func getTimeRange(for entries: [DIMLEntry]) -> String {
        guard let earliest = entries.min(by: { $0.timestamp < $1.timestamp }),
              let latest = entries.max(by: { $0.timestamp < $1.timestamp }) else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        if Calendar.current.isDate(earliest.timestamp, equalTo: latest.timestamp, toGranularity: .minute) {
            return formatter.string(from: earliest.timestamp)
        } else {
            return "\(formatter.string(from: earliest.timestamp)) - \(formatter.string(from: latest.timestamp))"
        }
    }
    
    private func formatDetailTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Friend Entry Detail Card
struct FriendEntryDetailCard: View {
    let entry: DIMLEntry
    let showTimestamp: Bool
    
    init(entry: DIMLEntry, showTimestamp: Bool = true) {
        self.entry = entry
        self.showTimestamp = showTimestamp
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Timestamp (conditionally shown)
            if showTimestamp {
                Text(formatDetailTime(entry.timestamp))
                    .font(.custom("Fredoka-Regular", size: 14))
                    .foregroundColor(.gray)
            }
            
            // Prompt
            Text(entry.prompt)
                .font(.custom("Fredoka-Medium", size: 18))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Content
            if let imageURL = entry.imageURL {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 250)
                        .overlay(
                            ProgressView()
                        )
                }
            }
            
            if !entry.response.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Response")
                        .font(.custom("Fredoka-Medium", size: 14))
                        .foregroundColor(.gray)
                    
                    Text(entry.response)
                        .font(.custom("Fredoka-Regular", size: 16))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color(red: 1.0, green: 0.95, blue: 0.80))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            // Additional metadata
            VStack(alignment: .leading, spacing: 8) {
                if !entry.comments.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 12))
                        Text("\(entry.comments.count) comment\(entry.comments.count == 1 ? "" : "s")")
                            .font(.custom("Fredoka-Regular", size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                if !entry.userReactions.isEmpty {
                    HStack(spacing: 4) {
                        let reactionCounts = entry.getReactionCounts()
                        ForEach(Array(reactionCounts.keys.sorted()), id: \.self) { emoji in
                            Text("\(emoji) \(reactionCounts[emoji] ?? 0)")
                                .font(.custom("Fredoka-Regular", size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
    }
    
    private func formatDetailTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
} 