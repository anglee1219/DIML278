import SwiftUI
import FirebaseAuth
import Foundation

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
    @StateObject private var friendsManager = FriendsManager.shared
    var group: Group
    
    @State private var selectedFrequency: PromptFrequency
    @State private var isMuted: Bool
    @State private var searchText = ""
    @State private var showRemoveAlert = false
    @State private var memberToRemove: User?
    @State private var showAddConfirmation = false
    @State private var selectedFriends: Set<String> = []
    @State private var showFriendProfile = false
    @State private var selectedFriend: User?
    @State private var isUpdatingSettings = false
    
    private let promptScheduler = PromptScheduler.shared
    
    init(groupStore: GroupStore, group: Group) {
        self.groupStore = groupStore
        self.group = group
        // Initialize state with current group settings
        self._selectedFrequency = State(initialValue: group.promptFrequency)
        self._isMuted = State(initialValue: group.notificationsMuted)
    }
    
    var filteredFriends: [User] {
        if searchText.isEmpty {
            return friendsManager.friends.filter { friend in
                !group.members.contains { $0.id == friend.id }
            }
        }
        return friendsManager.friends.filter { friend in
            !group.members.contains { $0.id == friend.id } &&
            (friend.name.lowercased().contains(searchText.lowercased()) ||
             (friend.username ?? "").lowercased().contains(searchText.lowercased()))
        }
    }
    
    private func updateGroupSettings() {
        isUpdatingSettings = true
        
        // Update the group with new settings
        var updatedGroup = group
        updatedGroup.promptFrequency = selectedFrequency
        updatedGroup.notificationsMuted = isMuted
        
        // Save to GroupStore
        groupStore.updateGroup(updatedGroup)
        
        // Update notification scheduling if current user is the influencer
        if Auth.auth().currentUser?.uid == group.currentInfluencerId && !isMuted {
            promptScheduler.schedulePrompts(
                for: selectedFrequency,
                influencerId: group.currentInfluencerId
            ) {
                DispatchQueue.main.async {
                    isUpdatingSettings = false
                }
            }
        } else {
            isUpdatingSettings = false
        }
    }

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
                        // Save settings before dismissing
                        updateGroupSettings()
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
                        
                        Text("Currently sending \(selectedFrequency.numberOfPrompts) prompt\(selectedFrequency.numberOfPrompts == 1 ? "" : "s") during the influencer's day")
                            .font(.custom("Markazi Text", size: 14))
                            .foregroundColor(.gray)
                            .padding(.bottom, 4)

                        Menu {
                            ForEach(PromptFrequency.allCases, id: \.self) { frequency in
                                Button(frequency.displayName) {
                                    selectedFrequency = frequency
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedFrequency.displayName)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(red: 1, green: 0.95, blue: 0.85))
                            .cornerRadius(10)
                        }

                        Text("Notifications")
                            .font(.custom("Markazi Text", size: 18))
                            .padding(.top, 16)
                        
                        Text(isMuted ? "Circle notifications are disabled" : "Circle notifications are enabled")
                            .font(.custom("Markazi Text", size: 14))
                            .foregroundColor(.gray)
                            .padding(.bottom, 4)

                        Menu {
                            Button("Enabled") { isMuted = false }
                            Button("Muted") { isMuted = true }
                        } label: {
                            HStack {
                                Text(isMuted ? "Muted" : "Enabled")
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(red: 1, green: 0.95, blue: 0.85))
                            .cornerRadius(10)
                        }
                        
                        if isUpdatingSettings {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Updating settings...")
                                    .font(.custom("Markazi Text", size: 14))
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 8)
                        }
                        
                        // Info about settings
                        if Auth.auth().currentUser?.uid == group.currentInfluencerId {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ℹ️ You're the current influencer")
                                    .font(.custom("Markazi Text", size: 14))
                                    .foregroundColor(.blue)
                                Text("Changes will affect how often you receive prompts during your influencer day")
                                    .font(.custom("Markazi Text", size: 12))
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 12)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current influencer: \(group.members.first(where: { $0.id == group.currentInfluencerId })?.name ?? "Unknown")")
                                    .font(.custom("Markazi Text", size: 14))
                                    .foregroundColor(.gray)
                                Text("Only the daily influencer receives prompt notifications")
                                    .font(.custom("Markazi Text", size: 12))
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 12)
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
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                    Text(member.username ?? "@user")
                                        .font(.custom("Markazi Text", size: 14))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                // Role badge
                                Text(member.role.stringValue)
                                    .font(.custom("Markazi Text", size: 14))
                                    .foregroundColor(member.role == .influencer ? .orange : .gray)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(member.role == .influencer ? 
                                                 Color.orange.opacity(0.2) : 
                                                 Color.gray.opacity(0.1))
                                    )
                                
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
        .background(Color(red: 1, green: 0.989, blue: 0.93).ignoresSafeArea())
        .alert("Add Members", isPresented: $showAddConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Add") {
                // Convert selected friends to Users and add them to the group
                let newMembers: [User] = selectedFriends.compactMap { friendId in
                    if let friend = friendsManager.friends.first(where: { $0.id == friendId }) {
                        let username = friend.username ?? "@\(friend.name.lowercased().replacingOccurrences(of: " ", with: ""))"
                        return User(
                            id: UUID().uuidString,
                            name: friend.name,
                            username: username,
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
        .sheet(isPresented: $showFriendProfile) {
            if let friend = selectedFriend {
                let username = friend.username ?? "@\(friend.name.lowercased().replacingOccurrences(of: " ", with: ""))"
                FriendProfileView(user: SuggestedUser(
                    name: friend.name,
                    username: username,
                    mutualFriends: 0,
                    source: "Friends"
                ))
            }
        }
        .onAppear {
            friendsManager.setupListeners()
        }
    }
}

struct FriendCell: View {
    let friend: User
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
                    if let username = friend.username {
                        Text(username)
                        .font(.custom("Markazi Text", size: 14))
                        .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}

struct GroupSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let mockGroup = Group(id: UUID().uuidString, name: "Sample Group", promptFrequency: .sixHours, notificationsMuted: false)
        return GroupSettingsView(groupStore: GroupStore(), group: mockGroup)
    }
}

#Preview {
    GroupSettingsView(groupStore: GroupStore(), group: Group(id: UUID().uuidString, name: "Sample Group", promptFrequency: .sixHours, notificationsMuted: false))
}

//
//  GroupSettingsView.swift
//  test2
//
//  Created by Angela Lee on 5/31/25.
//

