import SwiftUI
import FirebaseAuth

struct AddFriendsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var friendsManager = FriendsManager.shared
    @State private var searchText = ""
    @State private var selectedFriend: User? = nil
    @State private var showFriendProfile = false
    @State private var showRemoveAlert = false
    @State private var friendToRemove: User? = nil
    @State private var recentlyAdded: Set<String> = []
    private let mainYellow = Color(red: 1.0, green: 0.75, blue: 0)

    var filteredSuggestions: [User] {
        if searchText.isEmpty {
            return friendsManager.suggestedUsers
        }
        return friendsManager.suggestedUsers.filter { user in
            user.name.lowercased().contains(searchText.lowercased()) ||
            (user.username?.lowercased().contains(searchText.lowercased()) ?? false)
        }
    }

    // Helper function to convert User to SuggestedUser
    private func convertToSuggestedUser(_ user: User) -> SuggestedUser {
        return SuggestedUser(
            name: user.name,
            username: user.username ?? "@unknown",
            mutualFriends: 0, // We could implement mutual friends count later
            source: "Friends"
        )
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerBar
                searchBar
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Your Friends Section
                        if !friendsManager.friends.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your Friends")
                                    .font(.custom("Markazi Text", size: 28))
                                    .bold()
                                    .foregroundColor(mainYellow)
                                    .padding(.horizontal)
                                
                                List {
                                    ForEach(friendsManager.friends) { friend in
                                        FriendRowView(
                                            user: friend,
                                            isInYourFriends: true,
                                            recentlyAdded: recentlyAdded,
                                            mainYellow: mainYellow,
                                            onTap: {
                                                selectedFriend = friend
                                                showFriendProfile = true
                                            }
                                        )
                                        .listRowInsets(EdgeInsets())
                                        .listRowBackground(Color.white)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                friendToRemove = friend
                                                showRemoveAlert = true
                                            } label: {
                                                Label("Remove", systemImage: "person.badge.minus")
                                            }
                                        }
                                    }
                                }
                                .listStyle(PlainListStyle())
                                .frame(height: CGFloat(friendsManager.friends.count * 84))
                                .background(Color.white)
                                .cornerRadius(20)
                                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Find Friends Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Find Friends")
                                .font(.custom("Markazi Text", size: 28))
                                .bold()
                                .foregroundColor(mainYellow)
                                .padding(.horizontal)
                            
                            if filteredSuggestions.isEmpty {
                                Text("No matches found")
                                    .foregroundColor(.gray)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(filteredSuggestions) { person in
                                        FriendRowView(
                                            user: person,
                                            isInYourFriends: false,
                                            recentlyAdded: recentlyAdded,
                                            mainYellow: mainYellow,
                                            onAdd: {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    recentlyAdded.insert(person.id)
                                                    friendsManager.sendFriendRequest(to: person.id)
                                                }
                                            }
                                        )
                                        
                                        if person.id != filteredSuggestions.last?.id {
                                            Divider()
                                                .padding(.horizontal)
                                        }
                                    }
                                }
                                .background(Color.white)
                                .cornerRadius(20)
                                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.top, 16)
                }
            }
            .background(Color(red: 1, green: 0.989, blue: 0.93).ignoresSafeArea())
            .sheet(isPresented: $showFriendProfile) {
                if let friend = selectedFriend {
                    FriendProfileView(user: convertToSuggestedUser(friend))
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
            TextField("Search friends…", text: $searchText)
                .foregroundColor(.black)
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
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

struct FriendRowView: View {
    let user: User
    let isInYourFriends: Bool
    let recentlyAdded: Set<String>
    let mainYellow: Color
    var onTap: (() -> Void)?
    var onAdd: (() -> Void)?
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(Text(user.name.prefix(1)).font(.headline))

            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.custom("Fredoka-Regular", size: 16))

                if let username = user.username {
                    Text(username)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 4)

            Spacer()

            if !isInYourFriends {
                Button(action: {
                    onAdd?()
                }) {
                    HStack(spacing: 4) {
                        Text(recentlyAdded.contains(user.id) ? "Request Sent" : "Add Friend")
                            .foregroundColor(recentlyAdded.contains(user.id) ? .black : .white)
                        Image(systemName: recentlyAdded.contains(user.id) ? "checkmark" : "person.badge.plus")
                            .foregroundColor(recentlyAdded.contains(user.id) ? .black : .white)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(recentlyAdded.contains(user.id) ? mainYellow : Color.blue)
                    )
                    .scaleEffect(recentlyAdded.contains(user.id) ? 0.95 : 1.0)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(recentlyAdded.contains(user.id))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .contentShape(Rectangle())
        .onTapGesture {
            if isInYourFriends {
                onTap?()
            }
        }
    }
}

// MARK: - Preview
struct AddFriendsView_Previews: PreviewProvider {
    static var previews: some View {
        AddFriendsView()
    }
}
