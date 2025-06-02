import SwiftUI

struct Friend: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let username: String
    var isSelected: Bool = false
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Friend, rhs: Friend) -> Bool {
        lhs.id == rhs.id
    }
}

struct GroupSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var groupStore: GroupStore
    var group: Group
    
    @State private var selectedFrequency = "Every 5 hours"
    @State private var isMuted = true
    @State private var searchText = ""
    @State private var showRemoveAlert = false
    @State private var memberToRemove: User?
    @State private var showAddConfirmation = false
    @State private var selectedFriends: Set<UUID> = []
    @State private var friends: [Friend] = [
        Friend(name: "Steph Mulkens", username: "@steph"),
        Friend(name: "Nick Lowe", username: "@nick"),
        Friend(name: "Nicole Reinhardt", username: "@nicole"),
        Friend(name: "Tanya Benson", username: "@tanya"),
        Friend(name: "Alex Kim", username: "@alex"),
        Friend(name: "Sarah Chen", username: "@sarah")
    ]
    
    let frequencies = ["Every 1 hour", "Every 3 hours", "Every 5 hours", "Every 8 hours"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.gray)

                Spacer()

                Text("Circle Settings")
                    .font(.custom("Markazi Text", size: 24))
                    .bold()

                Spacer()

                Button("Done") {
                    if !selectedFriends.isEmpty {
                        showAddConfirmation = true
                    } else {
                        dismiss()
                    }
                }
                .foregroundColor(selectedFriends.isEmpty ? .gray : Color(red: 0.733, green: 0.424, blue: 0.141))
            }
            .padding(.horizontal)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Settings Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Prompt Frequency:")
                            .font(.custom("Markazi Text", size: 18))

                        Menu {
                            ForEach(frequencies, id: \.self) { freq in
                                Button(freq) {
                                    selectedFrequency = freq
                                }
                            }
                        } label: {
                            Text(selectedFrequency)
                                .padding(.horizontal)
                                .padding(.vertical, 6)
                                .background(Color(red: 1, green: 0.95, blue: 0.85))
                                .cornerRadius(10)
                        }

                        Text("Mute Notifications")
                            .font(.custom("Markazi Text", size: 18))
                            .padding(.top, 16)

                        Menu {
                            Button("Muted") { isMuted = true }
                            Button("Unmuted") { isMuted = false }
                        } label: {
                            Text(isMuted ? "Muted" : "Unmuted")
                                .padding(.horizontal)
                                .padding(.vertical, 6)
                                .background(Color(red: 1, green: 0.95, blue: 0.85))
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                    
                    // Members Section
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Circle Members")
                                .font(.custom("Markazi Text", size: 20))
                                .bold()
                            
                            Text("(\(group.members.count))")
                                .font(.custom("Markazi Text", size: 16))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        
                        ForEach(group.members) { member in
                            HStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 50, height: 50)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.name)
                                        .font(.custom("Markazi Text", size: 16))
                                    Text(member.username ?? "@user")
                                        .font(.custom("Markazi Text", size: 14))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                // Role badge
                                if let role = member.role {
                                    Text(role.rawValue)
                                        .font(.custom("Markazi Text", size: 14))
                                        .foregroundColor(role == .influencer ? .orange : .gray)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(role == .influencer ? 
                                                     Color.orange.opacity(0.2) : 
                                                     Color.gray.opacity(0.1))
                                        )
                                }
                                
                                if member.role != .admin {
                                    Button(action: {
                                        memberToRemove = member
                                        showRemoveAlert = true
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red.opacity(0.7))
                                            .font(.system(size: 20))
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                    }

                    Divider()

                    // Add Members Section
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Add Members")
                                .font(.custom("Markazi Text", size: 20))
                                .bold()
                            
                            if !selectedFriends.isEmpty {
                                Text("(\(selectedFriends.count) selected)")
                                    .font(.custom("Markazi Text", size: 16))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        TextField("Search friends by name or username...", text: $searchText)
                            .padding(10)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                            .autocapitalization(.none)
                            
                        if !selectedFriends.isEmpty {
                            Button(action: {
                                showAddConfirmation = true
                            }) {
                                Text("Add Selected Members")
                                    .font(.custom("Markazi Text", size: 16))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(red: 0.733, green: 0.424, blue: 0.141))
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Friends Grid
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 2), spacing: 20) {
                        ForEach(filteredFriends) { friend in
                            FriendCell(
                                friend: friend,
                                isSelected: selectedFriends.contains(friend.id),
                                onTap: {
                                    if selectedFriends.contains(friend.id) {
                                        selectedFriends.remove(friend.id)
                                    } else {
                                        selectedFriends.insert(friend.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .padding(.top, 20)
        .background(Color(red: 1, green: 0.988, blue: 0.929))
        .alert("Add Members", isPresented: $showAddConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Add") {
                // Convert selected friends to Users and add them to the group
                let newMembers: [User] = selectedFriends.compactMap { friendId in
                    if let friend = friends.first(where: { $0.id == friendId }) {
                        return User(
                            id: UUID().uuidString,
                            name: friend.name,
                            username: friend.username,
                            role: .member
                        )
                    }
                    return nil
                }
                
                // Add new members to the group
                var updatedGroup = group
                updatedGroup.members.append(contentsOf: newMembers)
                groupStore.updateGroup(updatedGroup)
                
                selectedFriends.removeAll()
                dismiss()
            }
        } message: {
            Text("Add \(selectedFriends.count) member\(selectedFriends.count == 1 ? "" : "s") to the circle?")
        }
        .alert("Remove Member", isPresented: $showRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                if let member = memberToRemove {
                    // Remove from persistent storage
                    var updatedGroup = group
                    updatedGroup.members.removeAll { $0.id == member.id }
                    groupStore.updateGroup(updatedGroup)
                    dismiss()
                }
            }
        } message: {
            if let member = memberToRemove {
                Text("Are you sure you want to remove \(member.name) from the circle?")
            }
        }
    }
    
    var filteredFriends: [Friend] {
        if searchText.isEmpty {
            return friends
        }
        return friends.filter { friend in
            friend.name.lowercased().contains(searchText.lowercased()) ||
            friend.username.lowercased().contains(searchText.lowercased())
        }
    }
}

struct FriendCell: View {
    let friend: Friend
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.green.opacity(0.3))
                            .frame(width: 80, height: 80)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 24))
                    } else {
                        Image(systemName: "plus")
                            .foregroundColor(.black)
                    }
                }

                VStack(spacing: 2) {
                    Text(friend.name)
                        .font(.custom("Markazi Text", size: 16))
                        .foregroundColor(.black)
                    Text(friend.username)
                        .font(.custom("Markazi Text", size: 14))
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

#Preview {
    GroupSettingsView(groupStore: GroupStore(), group: Group(id: UUID().uuidString, name: "Sample Group"))
}
//
//  GroupSettingsView.swift
//  test2
//
//  Created by Angela Lee on 5/31/25.
//

