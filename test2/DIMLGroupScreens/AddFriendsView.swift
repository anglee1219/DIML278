import SwiftUI

struct AddFriendsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var addedFriends: Set<String> = []
    @State private var yourFriends: [SuggestedUser] = []
    @State private var recentlyAdded: String? = nil
    @State private var selectedFriend: SuggestedUser? = nil
    @State private var showFriendProfile = false
    @State private var showRemoveAlert = false
    @State private var friendToRemove: SuggestedUser? = nil
    private let mainYellow = Color(red: 1.0, green: 0.75, blue: 0)
    
    // Load saved friends when view appears
    private func loadSavedFriends() {
        if let savedFriendUsernames = UserDefaults.standard.stringArray(forKey: "addedFriends") {
            addedFriends = Set(savedFriendUsernames)
            yourFriends = sampleSuggestions.filter { addedFriends.contains($0.username) }
        }
    }
    
    // Save friends to UserDefaults
    private func saveFriends() {
        UserDefaults.standard.set(Array(addedFriends), forKey: "addedFriends")
    }
    
    private func removeFriend(_ friend: SuggestedUser) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            addedFriends.remove(friend.username)
            yourFriends.removeAll { $0.username == friend.username }
            saveFriends()
        }
    }

    var filteredSuggestions: [SuggestedUser] {
        if searchText.isEmpty {
            return sampleSuggestions.filter { user in
                !addedFriends.contains(user.username) || recentlyAdded == user.username
            }
        }
        return sampleSuggestions.filter { user in
            (!addedFriends.contains(user.username) || recentlyAdded == user.username) &&
            (user.name.lowercased().contains(searchText.lowercased()) ||
             user.username.lowercased().contains(searchText.lowercased()))
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerBar
                searchBar
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Your Friends Section
                        if !yourFriends.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your Friends")
                                    .font(.custom("Markazi Text", size: 28))
                                    .bold()
                                    .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0))
                                    .padding(.horizontal)
                                
                                List {
                                    ForEach(yourFriends) { friend in
                                        FriendRowView(
                                            person: friend,
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
                                .frame(height: CGFloat(yourFriends.count * 84)) // Adjust this value based on your row height
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
                                .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0))
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
                                            person: person,
                                            isInYourFriends: false,
                                            recentlyAdded: recentlyAdded,
                                            mainYellow: mainYellow,
                                            onAdd: {
                                                // First animation - button changes
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    addedFriends.insert(person.username)
                                                    recentlyAdded = person.username
                                                }
                                                
                                                // Delay before moving to Your Friends section
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                        yourFriends.append(person)
                                                        recentlyAdded = nil
                                                        saveFriends()
                                                    }
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
                    FriendProfileView(user: friend)
                }
            }
            .alert("Remove Friend", isPresented: $showRemoveAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    if let friend = friendToRemove {
                        removeFriend(friend)
                    }
                }
            } message: {
                if let friend = friendToRemove {
                    Text("Are you sure you want to remove \(friend.name) from your friends?")
                }
            }
            .onAppear {
                loadSavedFriends()
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

                Text("     ") // Balance spacer
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
    let person: SuggestedUser
    let isInYourFriends: Bool
    let recentlyAdded: String?
    let mainYellow: Color
    var onTap: (() -> Void)?
    var onAdd: (() -> Void)?
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(Text(person.name.prefix(1)).font(.headline))

            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.custom("Fredoka-Regular", size: 16))

                Text(person.username)
                    .font(.caption)
                    .foregroundColor(.gray)

                Text(person.source)
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                if person.mutualFriends > 0 {
                    Text("\(person.mutualFriends) mutual friend\(person.mutualFriends > 1 ? "s" : "")")
                        .font(.caption2)
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
                        Text(recentlyAdded == person.username ? "Added" : "Add Friend")
                            .foregroundColor(recentlyAdded == person.username ? .black : .white)
                        Image(systemName: recentlyAdded == person.username ? "checkmark" : "person.badge.plus")
                            .foregroundColor(recentlyAdded == person.username ? .black : .white)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(recentlyAdded == person.username ? mainYellow : Color.blue)
                    )
                    .scaleEffect(recentlyAdded == person.username ? 0.95 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: recentlyAdded == person.username)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(recentlyAdded == person.username)
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
