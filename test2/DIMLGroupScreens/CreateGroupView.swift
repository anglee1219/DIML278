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

    @State private var groupName = ""
    @State private var newMembers: [User] = []
    @State private var myFriends: [User] = existingFriends
    @State private var searchText = ""
    @State private var currentPage = 0
    @State private var recentlyAdded: String? = nil
    private let friendsPerPage = 6
    private let gridSpacing: CGFloat = 15
    private let profileSize: CGFloat = 100
    
    private let backgroundColor = Color(red: 1, green: 0.988, blue: 0.929)
    private let yellowColor = Color(red: 1.0, green: 0.815, blue: 0.0)
    
    // Filtered friends based on search text
    private var filteredFriends: [User] {
        if searchText.isEmpty {
            return myFriends
        }
        return myFriends.filter { friend in
            friend.name.lowercased().contains(searchText.lowercased()) ||
            (friend.username?.lowercased().contains(searchText.lowercased()) ?? false)
        }
    }
    
    private var filteredSuggestions: [SuggestedUser] {
        if searchText.isEmpty {
            return sampleSuggestions.filter { suggestion in
                !myFriends.contains(where: { $0.name == suggestion.name })
            }
        }
        return sampleSuggestions.filter { person in
            !myFriends.contains(where: { $0.name == person.name }) &&
            (person.name.lowercased().contains(searchText.lowercased()) ||
             person.username.lowercased().contains(searchText.lowercased()))
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
                                                            Circle()
                                                                .fill(Color.white)
                                                                .frame(width: profileSize, height: profileSize)
                                                                .shadow(color: .black.opacity(0.1), radius: 2)
                                                            
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

                // MARK: - People You May Know
                VStack(alignment: .leading, spacing: 15) {
                    Text("People You May Know")
                        .font(.custom("Markazi Text", size: 28))
                        .foregroundColor(yellowColor)
                        .padding(.horizontal)

                    ForEach(filteredSuggestions) { person in
                        HStack(spacing: 15) {
                            // Profile Image
                            Circle()
                                .fill(Color.white)
                                .frame(width: 50, height: 50)
                                .shadow(color: .black.opacity(0.1), radius: 2)
                            
                            // Name and Username
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.name)
                                    .font(.custom("Markazi Text", size: 18))
                                Text(person.username)
                                    .font(.custom("Markazi Text", size: 14))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            // Add Friend Button with Animation
                            Button(action: {
                                let newFriend = User(id: UUID().uuidString, name: person.name, username: person.username)
                                // First animation - button changes
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    recentlyAdded = person.name
                                }
                                
                                // Delay before adding to myFriends
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        myFriends.append(newFriend)
                                        recentlyAdded = nil
                                    }
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text(recentlyAdded == person.name ? "Added" : "Add Friend")
                                        .foregroundColor(recentlyAdded == person.name ? .black : .white)
                                    Image(systemName: recentlyAdded == person.name ? "checkmark" : "person.badge.plus")
                                        .foregroundColor(recentlyAdded == person.name ? .black : .white)
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(recentlyAdded == person.name ? yellowColor : Color.blue)
                                )
                                .scaleEffect(recentlyAdded == person.name ? 0.95 : 1.0)
                            }
                            .disabled(recentlyAdded == person.name || myFriends.contains(where: { $0.name == person.name }))
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 20)
                
                Spacer(minLength: 50)
            }
        }
        .background(backgroundColor.ignoresSafeArea())
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
