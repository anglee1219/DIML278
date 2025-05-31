import SwiftUI
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

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // MARK: - Header Bar
                ZStack {
                    Rectangle()
                        .fill(Color.white)
                        .frame(height: 50)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.blue)

                        Spacer()

                        Text("Your Circle")
                            .font(.custom("Fredoka-Regular", size: 20))
                            .fontWeight(.medium)

                        Spacer()

                        Button("Create") {
                            let influencerId = newMembers.randomElement()?.id ?? UUID().uuidString
                            let newGroup = Group(
                                id: UUID().uuidString,
                                name: groupName,
                                members: newMembers,
                                currentInfluencerId: influencerId,
                                date: Date()
                            )
                            onGroupCreated(newGroup)
                            dismiss()
                        }
                        .disabled(groupName.isEmpty || newMembers.isEmpty)
                        .foregroundColor(groupName.isEmpty || newMembers.isEmpty ? .gray : .blue)
                    }
                    .padding(.horizontal)
                }

                // MARK: - Group Name Input
                TextField("Name Your Circle", text: $groupName)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    .padding(.horizontal)

                // MARK: - Add Friends Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add Friends")
                        .font(.custom("Markazi Text", size: 24))
                        .foregroundColor(Color(red: 1.0, green: 0.815, blue: 0.0))
                        .padding(.horizontal)

                    // Search Field (UI only)
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Search Friends...")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)

                    // Placeholder if no friends added
                    if newMembers.isEmpty {
                        VStack(spacing: 8) {
                            Text("Get Started")
                                .font(.title)
                                .bold()
                                .foregroundColor(.gray)
                            Text("by Adding Friends!")
                                .font(.title3)
                                .foregroundColor(.gray)
                            Text("Scroll down for People You May Know.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    } else {
                        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 20) {
                            ForEach(newMembers, id: \.id) { member in
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(width: 70, height: 70)
                                        .overlay(Text(member.name.prefix(1)).font(.title2))
                                    Text(member.name).font(.caption)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // MARK: - People You May Know
                VStack(alignment: .leading, spacing: 12) {
                    Text("People You May Know")
                        .font(.custom("Markazi Text", size: 20))
                        .foregroundColor(.orange)
                        .padding(.horizontal)

                    ForEach(sampleSuggestions) { person in
                        HStack {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 45, height: 45)

                            VStack(alignment: .leading) {
                                Text(person.name).font(.headline)
                                Text("\(person.username) • \(person.mutualFriends) mutual friends")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            Button(action: {
                                let newUser = User(id: UUID().uuidString, name: person.name)
                                if !newMembers.contains(where: { $0.name == newUser.name }) {
                                    newMembers.append(newUser)
                                }
                            }) {
                                HStack {
                                    Text("Add Friend")
                                    Image(systemName: "person.badge.plus")
                                }
                                .padding(8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(red: 1, green: 1, blue: 1))
        .ignoresSafeArea()
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
