import SwiftUI
import FirebaseAuth
import Foundation
/* Initial Create Circle Screen
struct CreateGroupView: View {
    var onGroupCreated: (Group) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var groupName = ""
    @State private var newMembers: [User] = []
    @State private var memberName = ""
    @State private var memberPhone = ""
     var body: some View {
     NavigationView {
     Form {
     Section(header: Text("Group Name")) {
     TextField("Enter group name", text: $groupName)
     }
     
     Section(header: Text("Add Members")) {
     VStack {
     TextField("Name", text: $memberName)
     TextField("Phone", text: $memberPhone)
     .keyboardType(.phonePad)
     Button("Add Member") {
     let newUser = User(id: UUID().uuidString, name: memberName)
     newMembers.append(newUser)
     memberName = ""
     memberPhone = ""
     }
     }
     
     ForEach(newMembers, id: \.id) { member in
     Text(member.name)
     }
     }
     }
     .navigationTitle("Create Group")
     .navigationBarItems(leading: Button("Cancel") {
     dismiss()
     }, trailing: Button("Create") {
     let influencerId = newMembers.randomElement()?.id ?? UUID().uuidString
     let newGroup = Group(id: UUID().uuidString, name: groupName, members: newMembers, currentInfluencerId: influencerId, date: Date())
     onGroupCreated(newGroup)
     dismiss()
     }.disabled(groupName.isEmpty || newMembers.isEmpty))
     }
     }
     }
     struct CreateGroupView_Previews: PreviewProvider {
     static var previews: some View {
     CreateGroupView(onGroupCreated: { group in
     print("Mock group created: \(group.name)")
     })
     }
     }
     
 */

// updated test- with some styling, not completed 5/30/25



struct CreateGroupView: View {
    var onGroupCreated: (Group) -> Void
    @Environment(\.dismiss) var dismiss
    @StateObject private var friendsManager = FriendsManager.shared

    @State private var groupName = ""
    @State private var newMembers: [User] = []
    @State private var searchText = ""
    @State private var currentPage = 0
    private let friendsPerPage = 6
    private let gridSpacing: CGFloat = 15
    private let profileSize: CGFloat = 100
    
    private let backgroundColor = Color(red: 1, green: 0.988, blue: 0.929)
    private let yellowColor = Color(red: 1.0, green: 0.815, blue: 0.0)
    
    // Use real friends from FriendsManager
    private var myFriends: [User] {
        return friendsManager.friends
    }
    
    // Filtered friends based on search text
    private var filteredFriends: [User] {
        if searchText.isEmpty {
            return myFriends
        }
        return myFriends.filter { friend in
            friend.name.lowercased().contains(searchText.lowercased()) ||
            (friend.username?.lowercased().contains(searchText.lowercased()) ?? false) ||
            (friend.location?.lowercased().contains(searchText.lowercased()) ?? false) ||
            (friend.school?.lowercased().contains(searchText.lowercased()) ?? false)
        }
    }

    private var numberOfPages: Int {
        (filteredFriends.count + friendsPerPage - 1) / friendsPerPage
    }
    
    private func friendsForPage(_ page: Int) -> ArraySlice<User> {
        let startIndex = page * friendsPerPage
        let endIndex = min(startIndex + friendsPerPage, filteredFriends.count)
        return filteredFriends[startIndex..<endIndex]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Group Icon
                Image("DIML_Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .padding(.top, 20)
                
                // MARK: - Header Bar
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Button("Create") {
                        let currentUser = User(
                            id: Auth.auth().currentUser?.uid ?? UUID().uuidString,
                            name: SharedProfileViewModel.shared.name,
                            username: "@\(SharedProfileViewModel.shared.name.lowercased().replacingOccurrences(of: " ", with: ""))",
                            role: .member  // Start everyone as a member
                        )
                        
                        // Create array with all members including current user
                        var groupMembers = newMembers.map { member in
                            let updatedMember = member
                            updatedMember.role = .member
                            return updatedMember
                        }
                        groupMembers.append(currentUser)
                        
                        // Randomly select an influencer from ALL members
                        let randomIndex = Int.random(in: 0..<groupMembers.count)
                        let influencerId = groupMembers[randomIndex].id
                        
                        // Update the selected member to be the influencer
                        groupMembers[randomIndex].role = .influencer
                        
                        // Make the current user an admin
                        if let adminIndex = groupMembers.firstIndex(where: { $0.id == currentUser.id }) {
                            groupMembers[adminIndex].role = .admin
                        }
                        
                        let newGroup = Group(
                            id: UUID().uuidString,
                            name: groupName,
                            members: groupMembers,
                            currentInfluencerId: influencerId,
                            date: Date(),
                            promptFrequency: .sixHours,
                            notificationsMuted: false
                        )
                        onGroupCreated(newGroup)
                        dismiss()
                    }
                    .foregroundColor(.gray)
                    .opacity(groupName.isEmpty || newMembers.isEmpty ? 0.5 : 1)
                    .disabled(groupName.isEmpty || newMembers.isEmpty)
                }
                .padding(.horizontal)

                // MARK: - Group Name Input
                TextField("Name Your Circle", text: $groupName)
                    .font(.custom("Markazi Text", size: 20))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 10)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                            .offset(y: 15)
                    )
                    .padding(.horizontal, 40)

                // MARK: - Add Friends Section
                VStack(alignment: .leading, spacing: 20) {
                    Text("Add Friends")
                        .font(.custom("Markazi Text", size: 28))
                        .foregroundColor(yellowColor)
                        .padding(.horizontal)

                    // Search Field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search Friends...", text: $searchText)
                            .font(.custom("Markazi Text", size: 18))
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(8)
                    .padding(.horizontal)

                    // Friends Grid
                    VStack(alignment: .leading) {
                        if filteredFriends.isEmpty {
                            // Empty state for no friends
                            VStack(spacing: 16) {
                                Image(systemName: searchText.isEmpty ? "person.2.circle" : "magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray.opacity(0.6))
                                
                                Text(searchText.isEmpty ? "No friends yet" : "No friends match your search")
                                    .font(.custom("Markazi Text", size: 20))
                                    .foregroundColor(.gray)
                                
                                Text(searchText.isEmpty ? "Add friends to start creating circles with them" : "Try a different search term")
                                    .font(.custom("Markazi Text", size: 16))
                                    .foregroundColor(.gray.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                if searchText.isEmpty {
                                    Text("💡 Add friends from the main Add Friends screen first")
                                        .font(.custom("Markazi Text", size: 14))
                                        .foregroundColor(yellowColor)
                                        .padding(.top, 8)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                            .background(Color.white.opacity(0.3))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        } else {
                            GeometryReader { geometry in
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 0) {
                                        ForEach(0..<numberOfPages, id: \.self) { page in
                                            VStack {
                                                LazyHGrid(
                                                    rows: [
                                                        GridItem(.fixed(140), spacing: gridSpacing),
                                                        GridItem(.fixed(140), spacing: gridSpacing)
                                                    ],
                                                    spacing: gridSpacing
                                                ) {
                                                    ForEach(Array(friendsForPage(page)), id: \.id) { friend in
                                                        VStack {
                                                            ZStack(alignment: .topTrailing) {
                                                                // Profile Picture
                                                                AsyncImage(url: URL(string: friend.profileImageUrl ?? "")) { image in
                                                                    image
                                                                        .resizable()
                                                                        .scaledToFill()
                                                                } placeholder: {
                                                                    Circle()
                                                                        .fill(Color.gray.opacity(0.3))
                                                                        .overlay(
                                                                            Text(friend.name.prefix(1).uppercased())
                                                                                .font(.system(size: 30, weight: .semibold, design: .rounded))
                                                                                .foregroundColor(.white)
                                                                        )
                                                                }
                                                                .frame(width: profileSize, height: profileSize)
                                                                .clipShape(Circle())
                                                                .overlay(
                                                                    Circle()
                                                                        .stroke(Color.white, lineWidth: 3)
                                                                        .shadow(color: .black.opacity(0.1), radius: 2)
                                                                )
                                                                
                                                                // Plus button
                                                                Button(action: {
                                                                    if !newMembers.contains(where: { $0.id == friend.id }) {
                                                                        withAnimation {
                                                                            newMembers.append(friend)
                                                                        }
                                                                    } else {
                                                                        if let index = newMembers.firstIndex(where: { $0.id == friend.id }) {
                                                                            newMembers.remove(at: index)
                                                                        }
                                                                    }
                                                                }) {
                                                                    Image(systemName: newMembers.contains(where: { $0.id == friend.id }) ? "checkmark.circle.fill" : "plus.circle.fill")
                                                                        .foregroundColor(newMembers.contains(where: { $0.id == friend.id }) ? .green : .blue)
                                                                        .font(.system(size: 24))
                                                                        .background(Color.white)
                                                                        .clipShape(Circle())
                                                                }
                                                                .offset(x: 5, y: -5)
                                                            }
                                                            
                                                            Text(friend.name)
                                                                .font(.custom("Markazi Text", size: 16))
                                                                .foregroundColor(.black)
                                                                .lineLimit(1)
                                                        }
                                                        .frame(width: profileSize)
                                                    }
                                                }
                                            }
                                            .frame(width: geometry.size.width)
                                        }
                                    }
                                }
                                .content.offset(x: CGFloat(currentPage) * -geometry.size.width)
                                .frame(width: geometry.size.width, alignment: .leading)
                                .gesture(
                                    DragGesture()
                                        .onEnded { value in
                                            let threshold: CGFloat = 50
                                            if value.translation.width < -threshold && currentPage < numberOfPages - 1 {
                                                withAnimation {
                                                    currentPage += 1
                                                }
                                            } else if value.translation.width > threshold && currentPage > 0 {
                                                withAnimation {
                                                    currentPage -= 1
                                                }
                                            }
                                        }
                                )
                            }
                            .frame(height: 300)
                            
                            // Page Indicator
                            if numberOfPages > 1 {
                                HStack(spacing: 8) {
                                    ForEach(0..<numberOfPages, id: \.self) { page in
                                        Circle()
                                            .fill(page == currentPage ? yellowColor : Color.gray.opacity(0.3))
                                            .frame(width: 8, height: 8)
                                    }
                                }
                                .padding(.top, 10)
                                .padding(.horizontal)
                            }
                        }
                    }
                }

                Spacer(minLength: 50)
            }
        }
        .background(backgroundColor.ignoresSafeArea())
        .onAppear {
            // Load friends data when view appears
            friendsManager.setupListeners()
        }
    }
}

// MARK: - Preview
struct CreateGroupView_Previews: PreviewProvider {
    static var previews: some View {
        CreateGroupView { group in
            print("Group created: \(group.name)")
        }
    }
}
