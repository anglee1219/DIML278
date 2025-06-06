import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct DailyCapsule: Identifiable {
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

struct MyCapsuleView: View {
    @State private var userEntries: [DIMLEntry] = []
    @State private var dailyCapsules: [DailyCapsule] = []
    @State private var currentIndex = 0
    @State private var timer: Timer?
    @State private var isLoading = true
    @State private var selectedCapsule: DailyCapsule?
    @State private var showCapsuleDetail = false
    @State private var isRefreshing = false
    @StateObject private var tutorialManager = TutorialManager()
    
    // Tutorial state
    @State private var showCapsuleTutorial = false
    
    private let slideInterval: TimeInterval = 2.5 // Faster flickering for preview
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if isLoading && !isRefreshing {
                    // Loading state (only show if not refreshing)
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 300)
                        .overlay(
                            VStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Loading your DIML memories...")
                                    .font(.custom("Fredoka-Regular", size: 16))
                                    .foregroundColor(.gray)
                            }
                        )
                } else if dailyCapsules.isEmpty {
                    // Empty state
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .frame(height: 300)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "photo.stack")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                Text("Your DIML Capsule")
                                    .font(.custom("Fredoka-Medium", size: 20))
                                    .foregroundColor(.black)
                                
                                Text("Start sharing prompts to fill\nyour memory capsule!")
                                    .font(.custom("Fredoka-Regular", size: 16))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
                } else {
                    // Daily capsules with flickering preview
                    VStack(spacing: 8) {
                        ForEach(dailyCapsules.prefix(3)) { capsule in
                            DailyCapsuleCard(
                                capsule: capsule,
                                isFirstCard: capsule.id == dailyCapsules.first?.id
                            ) {
                                selectedCapsule = capsule
                                showCapsuleDetail = true
                            }
                        }
                        
                        if dailyCapsules.count > 3 {
                            Button(action: {
                                // Show all capsules view
                            }) {
                                Text("View \(dailyCapsules.count - 3) more capsules...")
                                    .font(.custom("Fredoka-Regular", size: 14))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                // Total entry count
                if !userEntries.isEmpty {
                    Text("\(userEntries.count) DIML\(userEntries.count == 1 ? "" : "s") collected across \(dailyCapsules.count) day\(dailyCapsules.count == 1 ? "" : "s")")
                        .font(.custom("Fredoka-Regular", size: 14))
                        .foregroundColor(.gray)
                }
                
                // Refresh hint when empty
                if dailyCapsules.isEmpty && !isLoading {
                    Text("Pull down to refresh")
                        .font(.custom("Fredoka-Regular", size: 12))
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(.top, 8)
                }
            }
            .padding(.vertical, 8)
        }
        .refreshable {
            await refreshCapsuleData()
        }
        .onAppear {
            if userEntries.isEmpty {
                fetchUserEntries()
            }
        }
        .sheet(isPresented: $showCapsuleDetail) {
            if let capsule = selectedCapsule {
                CapsuleDetailView(capsule: capsule)
            } else {
                Text("No capsule data available")
                    .font(.custom("Fredoka-Regular", size: 16))
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        .onChange(of: showCapsuleDetail) { isShowing in
            print("🔍 MyCapsule: Sheet presentation changed to: \(isShowing)")
            if isShowing {
                print("🔍 MyCapsule: Selected capsule: \(selectedCapsule?.displayDate ?? "none")")
                print("🔍 MyCapsule: Capsule entries count: \(selectedCapsule?.entries.count ?? 0)")
            }
        }
    }
    
    // New async refresh function for pull-to-refresh
    @MainActor
    private func refreshCapsuleData() async {
        isRefreshing = true
        print("🔄 MyCapsule: Pull-to-refresh triggered")
        
        await withCheckedContinuation { continuation in
            fetchUserEntries(completion: {
                continuation.resume()
            })
        }
        
        isRefreshing = false
        print("🔄 MyCapsule: Pull-to-refresh completed")
    }
    
    private func fetchUserEntries(completion: (() -> Void)? = nil) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            isLoading = false
            completion?()
            return
        }
        
        print("🗃️ MyCapsule: Fetching entries for user: \(currentUserId)")
        
        let db = Firestore.firestore()
        
        // Query all groups where the user is a member
        db.collection("groups")
            .whereField("memberIds", arrayContains: currentUserId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("🗃️ MyCapsule: Error fetching groups: \(error)")
                    DispatchQueue.main.async {
                        isLoading = false
                        completion?()
                    }
                    return
                }
                
                var allEntries: [DIMLEntry] = []
                let group = DispatchGroup()
                
                for document in snapshot?.documents ?? [] {
                    group.enter()
                    
                    // Get entries for this group from the correct path: groups/{groupId}/entries
                    let groupId = document.documentID
                    print("🗃️ MyCapsule: Checking group \(groupId) for user entries")
                    
                    db.collection("groups")
                        .document(groupId)
                        .collection("entries")
                        .whereField("userId", isEqualTo: currentUserId)
                        .getDocuments { entrySnapshot, entryError in
                            defer { group.leave() }
                            
                            if let entryError = entryError {
                                print("🗃️ MyCapsule: Error fetching entries for group \(groupId): \(entryError)")
                                return
                            }
                            
                            let entriesCount = entrySnapshot?.documents.count ?? 0
                            print("🗃️ MyCapsule: Found \(entriesCount) entries in group \(groupId)")
                            
                            // Parse each entry manually like EntryStore does
                            for entryDoc in entrySnapshot?.documents ?? [] {
                                let data = entryDoc.data()
                                
                                guard let userId = data["userId"] as? String,
                                      let prompt = data["prompt"] as? String,
                                      let response = data["response"] as? String else {
                                    print("🗃️ MyCapsule: Invalid entry data for document \(entryDoc.documentID)")
                                    continue
                                }
                                
                                // Handle timestamp like EntryStore does
                                let timestamp: Date
                                if let firestoreTimestamp = data["timestamp"] as? Timestamp {
                                    timestamp = firestoreTimestamp.dateValue()
                                } else {
                                    timestamp = Date()
                                }
                                
                                // Handle comments like EntryStore does
                                let comments: [Comment]
                                if let commentsData = data["comments"] as? [[String: Any]] {
                                    comments = commentsData.compactMap { commentData -> Comment? in
                                        guard let id = commentData["id"] as? String,
                                              let userId = commentData["userId"] as? String,
                                              let text = commentData["text"] as? String else {
                                            return nil
                                        }
                                        
                                        let commentTimestamp: Date
                                        if let firestoreTimestamp = commentData["timestamp"] as? Timestamp {
                                            commentTimestamp = firestoreTimestamp.dateValue()
                                        } else {
                                            commentTimestamp = Date()
                                        }
                                        
                                        // Handle image data
                                        var imageData: Data?
                                        if let base64String = commentData["imageData"] as? String,
                                           let data = Data(base64Encoded: base64String) {
                                            imageData = data
                                        }
                                        
                                        return Comment(
                                            id: id,
                                            userId: userId,
                                            text: text,
                                            timestamp: commentTimestamp,
                                            imageData: imageData,
                                            imageURL: commentData["imageURL"] as? String
                                        )
                                    }
                                } else {
                                    comments = []
                                }
                                
                                // Handle legacy reactions
                                let reactions = data["reactions"] as? [String: Int] ?? [:]
                                
                                // Handle new user reactions like EntryStore does
                                let userReactions: [UserReaction]
                                if let userReactionsData = data["userReactions"] as? [[String: Any]] {
                                    userReactions = userReactionsData.compactMap { reactionData -> UserReaction? in
                                        guard let id = reactionData["id"] as? String,
                                              let userId = reactionData["userId"] as? String,
                                              let emoji = reactionData["emoji"] as? String else {
                                            return nil
                                        }
                                        
                                        let reactionTimestamp: Date
                                        if let firestoreTimestamp = reactionData["timestamp"] as? Timestamp {
                                            reactionTimestamp = firestoreTimestamp.dateValue()
                                        } else {
                                            reactionTimestamp = Date()
                                        }
                                        
                                        return UserReaction(
                                            id: id,
                                            userId: userId,
                                            emoji: emoji,
                                            timestamp: reactionTimestamp
                                        )
                                    }
                                } else {
                                    userReactions = []
                                }
                                
                                // Handle frame size
                                let frameSize: FrameSize
                                if let frameSizeString = data["frameSize"] as? String {
                                    frameSize = FrameSize(rawValue: frameSizeString) ?? .medium
                                } else {
                                    frameSize = .medium
                                }
                                
                                // Create the entry
                                let entry = DIMLEntry(
                                    id: entryDoc.documentID,
                                    userId: userId,
                                    prompt: prompt,
                                    response: response,
                                    image: nil,
                                    imageURL: data["imageURL"] as? String,
                                    timestamp: timestamp,
                                    comments: comments,
                                    reactions: reactions,
                                    userReactions: userReactions,
                                    frameSize: frameSize
                                )
                                
                                allEntries.append(entry)
                                print("🗃️ MyCapsule: Successfully parsed entry: \(entry.prompt.prefix(50))...")
                            }
                        }
                }
                
                group.notify(queue: .main) {
                    // Sort entries by timestamp (newest first)
                    self.userEntries = allEntries.sorted { $0.timestamp > $1.timestamp }
                    self.dailyCapsules = self.groupEntriesByDate(self.userEntries)
                    self.isLoading = false
                    
                    print("🗃️ MyCapsule: Final result - \(self.userEntries.count) total entries")
                    print("🗃️ MyCapsule: Created \(self.dailyCapsules.count) daily capsules")
                    
                    // Debug info
                    for capsule in self.dailyCapsules.prefix(3) {
                        print("📅 Capsule for \(capsule.displayDate): \(capsule.entries.count) entries")
                        for entry in capsule.entries.prefix(2) {
                            print("   📝 Entry: \(entry.prompt.prefix(30))... (imageURL: \(entry.imageURL != nil ? "✅" : "❌"))")
                        }
                    }
                    
                    completion?()
                }
            }
    }
    
    private func groupEntriesByDate(_ entries: [DIMLEntry]) -> [DailyCapsule] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.timestamp)
        }
        
        return grouped.map { date, entries in
            DailyCapsule(date: date, entries: entries.sorted { $0.timestamp > $1.timestamp })
        }.sorted { $0.date > $1.date }
    }
}

struct DailyCapsuleCard: View {
    let capsule: DailyCapsule
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
            print("🔍 DailyCapsuleCard: Tap detected on capsule for \(capsule.displayDate)")
            print("🔍 DailyCapsuleCard: Capsule has \(capsule.entries.count) entries")
            onTap()
        }
        .onAppear {
            print("🔍 DailyCapsuleCard: Card appeared for \(capsule.displayDate) with \(capsule.entries.count) entries")
            startFlickering()
        }
        .onDisappear {
            print("🔍 DailyCapsuleCard: Card disappeared for \(capsule.displayDate)")
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

struct CapsuleDetailView: View {
    let capsule: DailyCapsule
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
                                
                                Text("\(capsule.entries.count) DIML\(capsule.entries.count == 1 ? "" : "s") from this day")
                                    .font(.custom("Fredoka-Regular", size: 16))
                                    .foregroundColor(.gray)
                                
                                // Summary info - break down complex expression
                                let imageCount = capsule.entries.filter { $0.imageURL != nil }.count
                                let textCount = capsule.entries.count - imageCount
                                
                                HStack(spacing: 16) {
                                    if imageCount > 0 {
                                        let imageCountView = HStack(spacing: 4) {
                                            Image(systemName: "photo.fill")
                                                .foregroundColor(.blue)
                                            Text("\(imageCount)")
                                                .font(.custom("Fredoka-Regular", size: 14))
                                                .foregroundColor(.gray)
                                        }
                                        imageCountView
                                    }
                                    
                                    if textCount > 0 {
                                        let textCountView = HStack(spacing: 4) {
                                            Image(systemName: "text.alignleft")
                                                .foregroundColor(.green)
                                            Text("\(textCount)")
                                                .font(.custom("Fredoka-Regular", size: 14))
                                                .foregroundColor(.gray)
                                        }
                                        textCountView
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
                            
                            EntryDetailCard(entry: entry, showTimestamp: capsule.entries.count == 1)
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
        .onAppear {
            print("🔍 CapsuleDetailView: Appeared with \(capsule.entries.count) entries for \(capsule.displayDate)")
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

struct EntryDetailCard: View {
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

// Preview
struct MyCapsuleView_Previews: PreviewProvider {
    static var previews: some View {
        MyCapsuleView()
            .padding()
            .background(Color(red: 1, green: 0.989, blue: 0.93))
    }
} 