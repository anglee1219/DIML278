import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AddFriendsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var friendsManager = FriendsManager.shared
    @StateObject private var friendRequestManager = FriendRequestManager.shared
    @State private var searchText = ""
    @State private var selectedFriend: User? = nil
    @State private var showFriendProfile = false
    @State private var showRemoveAlert = false
    @State private var friendToRemove: User? = nil
    @State private var recentlyAdded: Set<String> = []
    @State private var showError = false
    @State private var errorMessage = ""
    private let mainYellow = Color(red: 1.0, green: 0.75, blue: 0)

    var filteredSuggestions: [User] {
        if searchText.isEmpty {
            return friendsManager.suggestedUsers
        }
        
        let searchTerm = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        return friendsManager.suggestedUsers.filter { user in
            // Search in name
            user.name.lowercased().contains(searchTerm) ||
            // Search in username
            (user.username?.lowercased().contains(searchTerm) ?? false) ||
            // Search in location
            (user.location?.lowercased().contains(searchTerm) ?? false) ||
            // Search in school
            (user.school?.lowercased().contains(searchTerm) ?? false) ||
            // Search in pronouns
            (user.pronouns?.lowercased().contains(searchTerm) ?? false) ||
            // Search in interests
            (user.interests?.lowercased().contains(searchTerm) ?? false)
        }
    }

    var filteredFriends: [User] {
        if searchText.isEmpty {
            return friendsManager.friends
        }
        
        let searchTerm = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        return friendsManager.friends.filter { user in
            // Search in name
            user.name.lowercased().contains(searchTerm) ||
            // Search in username
            (user.username?.lowercased().contains(searchTerm) ?? false) ||
            // Search in location
            (user.location?.lowercased().contains(searchTerm) ?? false) ||
            // Search in school
            (user.school?.lowercased().contains(searchTerm) ?? false) ||
            // Search in pronouns
            (user.pronouns?.lowercased().contains(searchTerm) ?? false) ||
            // Search in interests
            (user.interests?.lowercased().contains(searchTerm) ?? false)
        }
    }

    // Helper function to determine button state for each user
    private func getButtonState(for user: User) -> FriendButtonState {
        let friendIds = Set(friendsManager.friends.map { $0.id })
        let sentRequestIds = Set(friendRequestManager.sentRequests.map { $0.to })
        let pendingRequestIds = Set(friendRequestManager.pendingRequests.map { $0.from })
        
        if friendIds.contains(user.id) {
            return .alreadyFriends
        } else if sentRequestIds.contains(user.id) {
            return .requestSent
        } else if pendingRequestIds.contains(user.id) {
            return .canAccept
        } else if recentlyAdded.contains(user.id) {
            return .requestSent
        } else {
            return .canAdd
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerBar
                searchBar
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Pending Friend Requests Section
                        if !friendRequestManager.pendingRequests.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "person.badge.clock")
                                        .foregroundColor(.orange)
                                        .font(.title2)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Friend Requests")
                                            .font(.custom("Fredoka-Medium", size: 22))
                                            .foregroundColor(.orange)
                                        
                                        Text("\(friendRequestManager.pendingRequests.count) pending")
                                            .font(.custom("Fredoka-Regular", size: 14))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                
                                VStack(spacing: 1) {
                                    ForEach(friendRequestManager.pendingRequests) { request in
                                        PendingRequestRowView(
                                            request: request,
                                            mainYellow: mainYellow,
                                            onAccept: {
                                                Task {
                                                    do {
                                                        print("🔄 Accepting friend request from: \(request.from)")
                                                        try await friendRequestManager.acceptFriendRequest(from: request.from)
                                                        print("✅ Successfully accepted friend request from: \(request.from)")
                                                        
                                                        // Notify GroupListView of friend request activity
                                                        await MainActor.run {
                                                            NotificationCenter.default.post(
                                                                name: NSNotification.Name("FriendRequestAccepted"),
                                                                object: nil
                                                            )
                                                        }
                                                    } catch {
                                                        print("❌ Failed to accept friend request: \(error)")
                                                        await MainActor.run {
                                                            errorMessage = "Failed to accept friend request: \(error.localizedDescription)"
                                                            showError = true
                                                        }
                                                    }
                                                }
                                            },
                                            onReject: {
                                                Task {
                                                    do {
                                                        print("🔄 Rejecting friend request from: \(request.from)")
                                                        try await friendRequestManager.rejectFriendRequest(from: request.from)
                                                        print("✅ Successfully rejected friend request from: \(request.from)")
                                                        
                                                        // Notify GroupListView of friend request activity
                                                        await MainActor.run {
                                                            NotificationCenter.default.post(
                                                                name: NSNotification.Name("FriendRequestDeclined"),
                                                                object: nil
                                                            )
                                                        }
                                                    } catch {
                                                        print("❌ Failed to reject friend request: \(error)")
                                                        await MainActor.run {
                                                            errorMessage = "Failed to reject friend request: \(error.localizedDescription)"
                                                            showError = true
                                                        }
                                                    }
                                                }
                                            }
                                        )
                                        .background(Color.white)
                                        
                                        if request.id != friendRequestManager.pendingRequests.last?.id {
                                            Divider()
                                                .padding(.horizontal)
                                        }
                                    }
                                }
                                .background(Color.white)
                                .cornerRadius(20)
                                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                                .padding(.horizontal)
                            }
                        }
                        
                        // Your Friends Section
                        if !friendsManager.friends.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .foregroundColor(mainYellow)
                                        .font(.title2)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Your Friends")
                                            .font(.custom("Fredoka-Medium", size: 22))
                                            .foregroundColor(mainYellow)
                                        
                                        if searchText.isEmpty {
                                            Text("\(friendsManager.friends.count) friends")
                                                .font(.custom("Fredoka-Regular", size: 14))
                                                .foregroundColor(.gray)
                                        } else {
                                            Text("\(filteredFriends.count) of \(friendsManager.friends.count) friends match \"\(searchText)\"")
                                                .font(.custom("Fredoka-Regular", size: 14))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                
                                if filteredFriends.isEmpty && !searchText.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 30))
                                            .foregroundColor(.gray.opacity(0.6))
                                        
                                        Text("No friends match \"\(searchText)\"")
                                            .font(.custom("Fredoka-Medium", size: 16))
                                            .foregroundColor(.gray)
                                        
                                        Text("Try searching for a different name or username")
                                            .font(.custom("Fredoka-Regular", size: 14))
                                            .foregroundColor(.gray.opacity(0.8))
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 30)
                                    .background(Color.white)
                                    .cornerRadius(20)
                                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
                                    .padding(.horizontal)
                                } else {
                                    LazyVStack(spacing: 8) {
                                        ForEach(filteredFriends) { friend in
                                            FriendRowView(
                                                user: friend,
                                                buttonState: .alreadyFriends,
                                                recentlyAdded: recentlyAdded,
                                                mainYellow: mainYellow,
                                                onTap: {
                                                    selectedFriend = friend
                                                    showFriendProfile = true
                                                },
                                                onAction: nil
                                            )
                                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                                Button(role: .destructive) {
                                                    friendToRemove = friend
                                                    showRemoveAlert = true
                                                } label: {
                                                    Label("Remove", systemImage: "person.badge.minus")
                                                }
                                            }
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    friendToRemove = friend
                                                    showRemoveAlert = true
                                                } label: {
                                                    Label("Remove Friend", systemImage: "person.badge.minus")
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                
                                // Hint for removing friends
                                if !filteredFriends.isEmpty && searchText.isEmpty {
                                    HStack {
                                        Image(systemName: "hand.point.left")
                                            .font(.caption)
                                            .foregroundColor(.gray.opacity(0.8))
                                        Text("Swipe left or long press to remove friends")
                                            .font(.custom("Fredoka-Regular", size: 12))
                                            .foregroundColor(.gray.opacity(0.8))
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 4)
                                }
                            }
                        }
                        
                        // Find Friends Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(mainYellow)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Discover People")
                                        .font(.custom("Fredoka-Medium", size: 22))
                                        .foregroundColor(mainYellow)
                                    
                                    if searchText.isEmpty {
                                        Text("Find new friends to connect with (\(friendsManager.suggestedUsers.count) available)")
                                            .font(.custom("Fredoka-Regular", size: 14))
                                            .foregroundColor(.gray)
                                    } else {
                                        Text("\(filteredSuggestions.count) result\(filteredSuggestions.count == 1 ? "" : "s") for \"\(searchText)\"")
                                            .font(.custom("Fredoka-Regular", size: 14))
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                Spacer()
                                
                                // Debug refresh button
                                Button(action: {
                                    print("🔄 Manual refresh button tapped")
                                    friendsManager.forceReloadAll()
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(mainYellow)
                                        .font(.title3)
                                }
                            }
                            .padding(.horizontal)
                            
                            if filteredSuggestions.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: searchText.isEmpty ? "person.crop.circle.badge.plus" : "magnifyingglass")
                                        .font(.system(size: 30))
                                        .foregroundColor(.gray.opacity(0.6))
                                    
                                    if searchText.isEmpty {
                                        Text("No new people to discover")
                                            .font(.custom("Fredoka-Medium", size: 16))
                                            .foregroundColor(.gray)
                                        
                                        VStack(spacing: 4) {
                                            Text("Total users in database: \(friendsManager.suggestedUsers.count)")
                                                .font(.custom("Fredoka-Regular", size: 12))
                                                .foregroundColor(.gray.opacity(0.8))
                                            
                                            Text("Your friends: \(friendsManager.friends.count)")
                                                .font(.custom("Fredoka-Regular", size: 12))
                                                .foregroundColor(.gray.opacity(0.8))
                                            
                                            Text("Try the refresh button above to reload")
                                                .font(.custom("Fredoka-Regular", size: 12))
                                                .foregroundColor(mainYellow)
                                                .padding(.top, 8)
                                        }
                                    } else {
                                        Text("No people match \"\(searchText)\"")
                                            .font(.custom("Fredoka-Medium", size: 16))
                                            .foregroundColor(.gray)
                                        
                                        Text("Try a different search term")
                                            .font(.custom("Fredoka-Regular", size: 14))
                                            .foregroundColor(.gray.opacity(0.8))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 30)
                                .background(Color.white)
                                .cornerRadius(20)
                                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
                                .padding(.horizontal)
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(filteredSuggestions) { person in
                                        FriendRowView(
                                            user: person,
                                            buttonState: getButtonState(for: person),
                                            recentlyAdded: recentlyAdded,
                                            mainYellow: mainYellow,
                                            onTap: nil,
                                            onAction: {
                                                handleFriendAction(for: person)
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.top, 16)
                }
            }
            .refreshable {
                print("🔄 Pull-to-refresh triggered - reloading all friend data...")
                friendsManager.refreshSuggestedUsers()
            }
            .background(Color(red: 1, green: 0.989, blue: 0.93).ignoresSafeArea())
            .sheet(isPresented: $showFriendProfile) {
                if let friend = selectedFriend {
                    FriendProfileView(user: friend)
                }
            }
            .alert("Remove Friend", isPresented: $showRemoveAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    if let friend = friendToRemove {
                        friendsManager.removeFriend(friend.id)
                    }
                }
            } message: {
                if let friend = friendToRemove {
                    Text("Are you sure you want to remove \(friend.name) from your friends?")
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                print("🔍 AddFriendsView appeared - refreshing friend data...")
                // Force refresh friends and suggested users when view appears
                friendsManager.refreshSuggestedUsers()
            }
        }
    }
    
    private func handleFriendAction(for user: User) {
        let buttonState = getButtonState(for: user)
        
        switch buttonState {
        case .canAdd:
            // Send friend request
            Task {
                do {
                    recentlyAdded.insert(user.id)
                    try await friendRequestManager.sendFriendRequest(to: user.id)
                } catch {
                    await MainActor.run {
                        recentlyAdded.remove(user.id)
                        errorMessage = "Failed to send friend request: \(error.localizedDescription)"
                        showError = true
                    }
                }
            }
        case .requestSent:
            // Cancel friend request
            Task {
                do {
                    try await friendRequestManager.cancelFriendRequest(to: user.id)
                    _ = await MainActor.run {
                        recentlyAdded.remove(user.id)
                    }
                } catch {
                    _ = await MainActor.run {
                        errorMessage = "Failed to cancel friend request: \(error.localizedDescription)"
                        showError = true
                    }
                }
            }
        case .canAccept:
            // This should be handled in the pending requests section
            break
        case .alreadyFriends:
            // Already friends, no action needed
            break
        }
    }

    // MARK: - Header
    private var headerBar: some View {
        ZStack {
            Rectangle()
                .fill(Color.white)
                .frame(height: 50)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

            HStack {
                Button("Back") {
                    dismiss()
                }
                .foregroundColor(.orange)

                Spacer()

                Text("Add Friends")
                    .font(.custom("Fredoka-Regular", size: 20))
                    .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))

                Spacer()

                Text("     ")
                    .foregroundColor(.clear)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search by name, username, school, location...", text: $searchText)
                .foregroundColor(.black)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    // Dismiss keyboard when clearing search
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(red: 0.95, green: 0.95, blue: 0.9))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - Friend Button States
enum FriendButtonState {
    case canAdd
    case requestSent
    case canAccept
    case alreadyFriends
}

// MARK: - Pending Request Row View
struct PendingRequestRowView: View {
    let request: FriendRequest
    let mainYellow: Color
    let onAccept: () -> Void
    let onReject: () -> Void
    
    @State private var senderName: String = "Loading..."
    @State private var senderUsername: String = ""
    @State private var senderLocation: String = ""
    @State private var senderSchool: String = ""
    @State private var senderPronouns: String = ""
    @State private var senderProfileImageUrl: String = ""
    @State private var isLoading = true
    
    private let db = Firestore.firestore()
    
    // Generate consistent color for user based on their ID
    private func getPlaceholderColor() -> Color {
        return Color.gray.opacity(0.3) // Consistent light grey for all users
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Profile Picture
            AsyncImage(url: URL(string: senderProfileImageUrl)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Circle()
                        .fill(getPlaceholderColor())
                        .overlay(
                            Text(senderName.prefix(1).uppercased())
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        )
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .shadow(color: .gray.opacity(0.3), radius: 2, x: 0, y: 1)
            )

            VStack(alignment: .leading, spacing: 4) {
                if isLoading {
                    Text("Loading...")
                        .font(.custom("Fredoka-Regular", size: 16))
                        .foregroundColor(.gray)
                } else {
                    // Name and pronouns
                    HStack(spacing: 6) {
                        Text(senderName)
                            .font(.custom("Fredoka-Medium", size: 16))
                            .foregroundColor(.black)
                        
                        if !senderPronouns.isEmpty {
                            Text("(\(senderPronouns))")
                                .font(.custom("Fredoka-Regular", size: 12))
                                .foregroundColor(.black.opacity(0.6))
                        }
                    }
                    
                    // Username
                    if !senderUsername.isEmpty {
                        Text("@\(senderUsername)")
                            .font(.custom("Fredoka-Regular", size: 14))
                            .foregroundColor(.blue)
                    }
                    
                    // Location and school info
                    VStack(alignment: .leading, spacing: 2) {
                        if !senderLocation.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                    .foregroundColor(.black.opacity(0.6))
                                Text(senderLocation)
                                    .font(.custom("Fredoka-Regular", size: 12))
                                    .foregroundColor(.black.opacity(0.7))
                            }
                        }
                        
                        if !senderSchool.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "graduationcap.fill")
                                    .font(.caption)
                                    .foregroundColor(.black.opacity(0.6))
                                Text(senderSchool)
                                    .font(.custom("Fredoka-Regular", size: 12))
                                    .foregroundColor(.black.opacity(0.7))
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)

            Spacer()
            
            HStack(spacing: 8) {
                Button(action: onReject) {
                    Text("Decline")
                        .foregroundColor(.red)
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red, lineWidth: 1.5)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onAccept) {
                    Text("Accept")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal)
        .onAppear {
            fetchSenderInfo()
        }
    }
    
    private func fetchSenderInfo() {
        guard !request.from.isEmpty else {
            senderName = "Unknown User"
            isLoading = false
            return
        }
        
        db.collection("users").document(request.from).getDocument { document, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error fetching sender info: \(error.localizedDescription)")
                    self.senderName = "Unknown User"
                    self.isLoading = false
                    return
                }
                
                guard let document = document, 
                      document.exists,
                      let data = document.data() else {
                    print("❌ No user document found for ID: \(request.from)")
                    self.senderName = "Unknown User"
                    self.isLoading = false
                    return
                }
                
                self.senderName = data["name"] as? String ?? data["username"] as? String ?? "Unknown User"
                self.senderUsername = data["username"] as? String ?? ""
                self.senderPronouns = data["pronouns"] as? String ?? ""
                self.senderLocation = data["location"] as? String ?? ""
                self.senderSchool = data["school"] as? String ?? ""
                self.senderProfileImageUrl = data["profileImageURL"] as? String ?? ""
                self.isLoading = false
                
                print("✅ Fetched complete sender info: \(self.senderName)")
                if !self.senderProfileImageUrl.isEmpty {
                    print("📸 Profile image URL: \(self.senderProfileImageUrl)")
                } else {
                    print("📸 No profile image URL found")
                }
            }
        }
    }
}

// MARK: - Updated Friend Row View
struct FriendRowView: View {
    let user: User
    let buttonState: FriendButtonState
    let recentlyAdded: Set<String>
    let mainYellow: Color
    var onTap: (() -> Void)?
    var onAction: (() -> Void)?
    
    @State private var fullUserData: User?
    @State private var isLoadingDetails = false
    
    // Generate consistent color for user based on their ID
    private func getPlaceholderColor() -> Color {
        return Color.gray.opacity(0.3) // Consistent light grey for all users
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Profile Picture
            AsyncImage(url: URL(string: displayUser.profileImageUrl ?? "")) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Circle()
                    .fill(getPlaceholderColor())
                    .overlay(
                        Text(displayUser.name.prefix(1).uppercased())
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    )
            }
            .frame(width: 55, height: 55)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .shadow(color: .gray.opacity(0.3), radius: 2, x: 0, y: 1)
            )

            VStack(alignment: .leading, spacing: 4) {
                // Name and pronouns
                HStack(spacing: 6) {
                    Text(displayUser.name)
                        .font(.custom("Fredoka-Medium", size: 16))
                        .foregroundColor(.black)
                    
                    if let pronouns = displayUser.pronouns, !pronouns.isEmpty {
                        Text("(\(pronouns))")
                            .font(.custom("Fredoka-Regular", size: 12))
                            .foregroundColor(.black.opacity(0.6))
                    }
                }

                // Username
                if let username = displayUser.username, !username.isEmpty {
                    Text("@\(username)")
                        .font(.custom("Fredoka-Regular", size: 14))
                        .foregroundColor(.blue)
                }
                
                // Location and school info
                VStack(alignment: .leading, spacing: 2) {
                    if let location = displayUser.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundColor(.black.opacity(0.6))
                            Text(location)
                                .font(.custom("Fredoka-Regular", size: 12))
                                .foregroundColor(.black.opacity(0.7))
                        }
                    }
                    
                    if let school = displayUser.school, !school.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "graduationcap.fill")
                                .font(.caption)
                                .foregroundColor(.black.opacity(0.6))
                            Text(school)
                                .font(.custom("Fredoka-Regular", size: 12))
                                .foregroundColor(.black.opacity(0.7))
                        }
                    }
                }
            }
            .padding(.vertical, 4)

            Spacer()

            if buttonState != .alreadyFriends {
                Button(action: {
                    onAction?()
                }) {
                    HStack(spacing: 6) {
                        switch buttonState {
                        case .canAdd:
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(.white)
                            Text("Add")
                                .foregroundColor(.white)
                        case .requestSent:
                            Image(systemName: "clock")
                                .foregroundColor(.black)
                            Text("Pending")
                                .foregroundColor(.black)
                        case .canAccept:
                            Image(systemName: "checkmark")
                                .foregroundColor(.white)
                            Text("Accept")
                                .foregroundColor(.white)
                        case .alreadyFriends:
                            EmptyView()
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(getButtonGradient())
                    )
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // For existing friends, show a subtle "Friends" indicator
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.green)
                    Text("Friends")
                        .foregroundColor(.green)
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.green.opacity(0.1))
                )
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .background(Color.white.opacity(0.7))
        .cornerRadius(16)
        .contentShape(Rectangle())
        .onTapGesture {
            if buttonState == .alreadyFriends {
                onTap?()
            }
        }
        .onAppear {
            loadFullUserDetails()
        }
    }
    
    private var displayUser: User {
        return fullUserData ?? user
    }
    
    private func loadFullUserDetails() {
        // If we already have full data or are loading, skip
        guard fullUserData == nil && !isLoadingDetails else { return }
        
        isLoadingDetails = true
        let db = Firestore.firestore()
        
        db.collection("users").document(user.id).getDocument { document, error in
            DispatchQueue.main.async {
                self.isLoadingDetails = false
                
                if let error = error {
                    print("❌ Error fetching full user details: \(error.localizedDescription)")
                    return
                }
                
                guard let document = document,
                      document.exists,
                      let data = document.data() else {
                    print("❌ No detailed user document found for ID: \(user.id)")
                    return
                }
                
                let profileImageURL = data["profileImageURL"] as? String
                
                // Create enhanced User object with all available data
                self.fullUserData = User(
                    id: user.id,
                    name: data["name"] as? String ?? user.name,
                    username: data["username"] as? String ?? user.username,
                    email: data["email"] as? String,
                    role: user.role,
                    profileImageUrl: profileImageURL,
                    pronouns: data["pronouns"] as? String,
                    zodiacSign: data["zodiacSign"] as? String,
                    location: data["location"] as? String,
                    school: data["school"] as? String,
                    interests: data["interests"] as? String
                )
                
                print("✅ Loaded full user details for: \(self.fullUserData?.name ?? "Unknown")")
                if let imageURL = profileImageURL, !imageURL.isEmpty {
                    print("📸 User \(self.fullUserData?.name ?? "Unknown") has profile image URL: \(imageURL)")
                } else {
                    print("📸 User \(self.fullUserData?.name ?? "Unknown") has no profile image URL")
                }
            }
        }
    }
    
    private func getButtonGradient() -> LinearGradient {
        switch buttonState {
        case .canAdd:
            return LinearGradient(
                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .requestSent:
            return LinearGradient(
                gradient: Gradient(colors: [mainYellow, mainYellow.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .canAccept:
            return LinearGradient(
                gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .alreadyFriends:
            return LinearGradient(
                gradient: Gradient(colors: [Color.clear]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Preview
struct AddFriendsView_Previews: PreviewProvider {
    static var previews: some View {
        AddFriendsView()
    }
}
