import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UserNotifications
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
    @ObservedObject var groupStore: GroupStore
    @ObservedObject var entryStore: EntryStore
    @StateObject private var friendsManager = FriendsManager.shared
    var group: Group
    @Binding var isPresented: Bool
    
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
    @State private var showClearEntriesAlert = false
    @State private var showLeaveGroupAlert = false

    
    private let promptScheduler = PromptScheduler.shared
    
    private var doneButtonColor: Color {
        return selectedFriends.isEmpty ? .gray : Color(red: 0.733, green: 0.424, blue: 0.141)
    }
    
    init(groupStore: GroupStore, entryStore: EntryStore, group: Group, isPresented: Binding<Bool>) {
        self.groupStore = groupStore
        self.entryStore = entryStore
        self.group = group
        self._isPresented = isPresented
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
                    self.isUpdatingSettings = false
                }
            }
        } else {
            isUpdatingSettings = false
        }
    }
    
    private func updateSettingsAndDismiss() {
        print("🔧 Starting settings update and dismiss process...")
        
        // Update the group with new settings
        var updatedGroup = group
        updatedGroup.promptFrequency = selectedFrequency
        updatedGroup.notificationsMuted = isMuted
        
        print("🔧 Updating group in GroupStore...")
        // Save to GroupStore
        groupStore.updateGroup(updatedGroup)
        
        // Update notification scheduling if current user is the influencer
        if Auth.auth().currentUser?.uid == group.currentInfluencerId && !isMuted {
            print("🔧 Scheduling prompts for influencer...")
            promptScheduler.schedulePrompts(
                for: selectedFrequency,
                influencerId: group.currentInfluencerId
            ) {
                DispatchQueue.main.async {
                    print("🔧 Prompts scheduled, dismissing...")
                    self.isPresented = false
                }
            }
        } else {
            print("🔧 No prompt scheduling needed, dismissing...")
            self.isPresented = false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .foregroundColor(.gray)

                Spacer()

                Text("Circle Settings")
                    .font(.custom("Markazi Text", size: 24))
                    .bold()

                Spacer()

                Button("Done") {
                    print("🔧 Done button clicked")
                    print("🔧 selectedFriends.isEmpty: \(selectedFriends.isEmpty)")
                    print("🔧 showAddConfirmation: \(showAddConfirmation)")
                    print("🔧 showRemoveAlert: \(showRemoveAlert)")
                    
                    if !selectedFriends.isEmpty {
                        print("🔧 Showing add confirmation alert")
                        showAddConfirmation = true
                    } else {
                        print("🔧 Calling updateSettingsAndDismiss()")
                        // Save settings before dismissing
                        updateSettingsAndDismiss()
                    }
                }
                .foregroundColor(doneButtonColor)
            }
            .padding(.horizontal)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Settings Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Prompt Frequency:")
                            .font(.custom("Markazi Text", size: 18))
                            .foregroundColor(.black)
                        
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
                            .foregroundColor(.black)
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
                        
                        // Clear Entries Section (for testing)
                        Text("Testing")
                            .font(.custom("Markazi Text", size: 18))
                            .foregroundColor(.black)
                            .padding(.top, 16)
                        
                        Text("Clear all uploads and entries for testing (\(entryStore.entries.count) entries)")
                            .font(.custom("Markazi Text", size: 14))
                            .foregroundColor(.gray)
                            .padding(.bottom, 4)
                        

                        
                        Button(action: {
                            showClearEntriesAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                Text("Clear All Entries")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(10)
                        }
                        
                        // Leave/Delete Group Section
                        Text("Circle Management")
                            .font(.custom("Markazi Text", size: 18))
                            .foregroundColor(.black)
                            .padding(.top, 16)
                        
                        Text("Leave this circle")
                            .font(.custom("Markazi Text", size: 14))
                            .foregroundColor(.gray)
                            .padding(.bottom, 4)
                        
                        // Info about auto-deletion
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.system(size: 14))
                            Text("Circles automatically delete when only 1 member remains")
                                .font(.custom("Markazi Text", size: 13))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(.bottom, 4)
                        
                        HStack {
                            Image(systemName: "hand.point.left")
                                .foregroundColor(.gray)
                                .font(.system(size: 14))
                            Text("💡 You can also long press on circles in the main list to leave")
                                .font(.custom("Markazi Text", size: 13))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(.bottom, 8)
                        
                        // Leave Group Button
                        Button(action: {
                            showLeaveGroupAlert = true
                        }) {
                            HStack {
                                Image(systemName: "person.badge.minus")
                                    .foregroundColor(.orange)
                                Text("Leave Circle")
                                    .foregroundColor(.orange)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.1))
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
                                .foregroundColor(.black)
                            
                            Text("(\(group.members.count))")
                                .font(.custom("Markazi Text", size: 16))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        
                        ForEach(group.members) { member in
                            HStack {
                                ProfilePictureView(userId: member.id, size: 50, groupMembers: group.members)
                                
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
                                .foregroundColor(.black)
                            
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
                        // Use the full friend data instead of creating a new User with minimal data
                        return User(
                            id: friend.id,
                            name: friend.name,
                            username: friend.username,
                            role: .member,
                            profileImageUrl: friend.profileImageUrl
                        )
                    }
                    return nil
                }
                
                // Send notifications to newly added members before updating the group
                sendMemberAddedNotifications(
                    groupName: group.name,
                    adderName: SharedProfileViewModel.shared.name,
                    addedMembers: newMembers,
                    groupId: group.id
                )
                
                // Add new members to the group
                var updatedGroup = group
                updatedGroup.members.append(contentsOf: newMembers)
                groupStore.updateGroup(updatedGroup)
                
                selectedFriends.removeAll()
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
                }
            }
        } message: {
            if let member = memberToRemove {
                Text("Are you sure you want to remove \(member.name) from the circle?")
            }
        }
        .alert("Clear All Entries", isPresented: $showClearEntriesAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                entryStore.clearAllEntries()
                print("🗑️ All entries cleared for testing")
            }
        } message: {
            Text("This will permanently delete all \(entryStore.entries.count) entries for this group. This action cannot be undone.")
        }
        .alert("Leave Circle", isPresented: $showLeaveGroupAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Leave", role: .destructive) {
                print("🔴 Leave Circle button tapped from GroupSettingsView")
                let success = groupStore.leaveGroup(group)
                if success {
                    print("✅ Successfully left group, dismissing settings and navigating back")
                    // Group was successfully left or deleted, dismiss settings and return to main view
                    isPresented = false
                    
                    // Also send reset navigation to ensure we go back to main tab
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ResetMainTabNavigation"),
                            object: nil
                        )
                    }
                } else {
                    print("❌ Failed to leave group")
                }
            }
        } message: {
            if group.members.count <= 1 {
                Text("You are the only member of '\(group.name)'. Leaving will delete the entire circle permanently and all chat history will be lost.")
            } else {
                Text("Are you sure you want to leave '\(group.name)'? You'll need to be re-invited to rejoin. Other members will see that you've left.")
            }
        }
        .sheet(isPresented: $showFriendProfile) {
            if let friend = selectedFriend {
                FriendProfileView(user: friend)
            }
        }

        .onAppear {
            friendsManager.setupListeners()
        }
    }
    
    // MARK: - Member Added Notifications
    
    private func sendMemberAddedNotifications(groupName: String, adderName: String, addedMembers: [User], groupId: String) {
        print("📱 👥 === SENDING MEMBER ADDED NOTIFICATIONS ===")
        print("📱 👥 Circle: \(groupName)")
        print("📱 👥 Adder: \(adderName)")
        print("📱 👥 Added members: \(addedMembers.count)")
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("📱 👥 ❌ No current user for member added notifications")
            return
        }
        
        print("📱 👥 Adder ID (should NOT get notification): \(currentUserId)")
        
        // Filter out the current user (adder) from notifications
        let membersToNotify = addedMembers.filter { $0.id != currentUserId }
        
        print("📱 👥 📋 Added members to notify:")
        for (index, member) in membersToNotify.enumerated() {
            print("📱 👥 📋 [\(index + 1)] \(member.name) (ID: \(member.id))")
        }
        
        guard !membersToNotify.isEmpty else {
            print("📱 👥 ℹ️ No added members to notify (might be adding self)")
            return
        }
        
        // FIXED: Only send FCM notifications to added members (no local notifications)
        // Local notifications appear on the current device (adder's phone) which is wrong!
        Task {
            print("📱 👥 🚀 Sending ONLY FCM notifications to \(membersToNotify.count) added members...")
            print("📱 👥 🚫 LOCAL notifications REMOVED - they were going to adder's device!")
            
            // Send FCM push notifications to added members' devices
            await sendMemberAddedFCMNotifications(
                groupName: groupName,
                adderName: adderName,
                addedMembers: membersToNotify,
                groupId: groupId
            )
            
            print("📱 👥 === MEMBER ADDED NOTIFICATIONS COMPLETE ===")
        }
    }
    
    private func sendMemberAddedFCMNotifications(groupName: String, adderName: String, addedMembers: [User], groupId: String) async {
        print("📱 👥 ☁️ === SENDING FCM NOTIFICATIONS FOR MEMBER ADDED ===")
        
        let db = Firestore.firestore()
        
        for member in addedMembers {
            print("📱 👥 📤 Sending FCM notification to: \(member.name) (ID: \(member.id))")
            
            do {
                // Get member's FCM token
                let userDoc = try await db.collection("users").document(member.id).getDocument()
                guard let userData = userDoc.data(),
                      let fcmToken = userData["fcmToken"] as? String else {
                    print("📱 👥 ⚠️ No FCM token found for user \(member.name)")
                    continue
                }
                
                // Send FCM push notification via Cloud Function
                await sendMemberAddedCloudFunctionNotification(
                    token: fcmToken,
                    groupName: groupName,
                    adderName: adderName,
                    targetUserId: member.id,
                    groupId: groupId
                )
                
            } catch {
                print("📱 👥 ❌ Error getting FCM token for \(member.name): \(error.localizedDescription)")
            }
        }
    }
    
    private func sendMemberAddedCloudFunctionNotification(token: String, groupName: String, adderName: String, targetUserId: String, groupId: String) async {
        print("📱 👥 ☁️ === MEMBER ADDED FCM NOTIFICATION DEBUG ===")
        print("📱 👥 ☁️ Token (last 8): \(String(token.suffix(8)))")
        print("📱 👥 ☁️ Group Name: \(groupName)")
        print("📱 👥 ☁️ Adder: \(adderName)")
        print("📱 👥 ☁️ Target User: \(targetUserId)")
        print("📱 👥 ☁️ Current User: \(Auth.auth().currentUser?.uid ?? "nil")")
        print("📱 👥 ☁️ Group ID: \(groupId)")
        
        // CRITICAL: Verify we're not sending to the adder
        if targetUserId == Auth.auth().currentUser?.uid {
            print("📱 👥 ☁️ ❌ ABORTING: Target user is the adder!")
            return
        }
        
        // Create notification request for Cloud Function
        let notificationRequest: [String: Any] = [
            "fcmToken": token,
            "title": "👥 Added to Circle!",
            "body": "\(adderName) added you to '\(groupName)'",
            "data": [
                "type": "member_added",
                "groupId": groupId,
                "groupName": groupName,
                "adderName": adderName,
                "targetUserId": targetUserId
            ],
            "timestamp": FieldValue.serverTimestamp(),
            "processed": false,
            "targetUserId": targetUserId,
            "notificationType": "member_added"
        ]
        
        print("📱 👥 ☁️ Member added notification request data:")
        for (key, value) in notificationRequest {
            if key != "timestamp" {
                print("📱 👥 ☁️   \(key): \(value)")
            }
        }
        
        do {
            let db = Firestore.firestore()
            let docRef = try await db.collection("notificationRequests").addDocument(data: notificationRequest)
            print("📱 👥 ✅ Member added notification queued via Cloud Function for \(targetUserId)")
            print("📱 👥 ✅ Document ID: \(docRef.documentID)")
            print("📱 👥 ✅ CRITICAL SUCCESS: Notification request successfully added to Firestore!")
        } catch {
            print("📱 👥 ❌ Error queuing member added notification: \(error.localizedDescription)")
            print("📱 👥 ❌ CRITICAL ERROR: \(error)")
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
                    // Profile image with ProfilePictureView
                    ProfilePictureView(userId: friend.id, size: 80, groupMembers: nil)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                        )
                    
                    // Selection overlay
                    if isSelected {
                        Circle()
                            .fill(Color.green.opacity(0.3))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 28))
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 32, height: 32)
                            )
                    } else {
                        // Plus icon overlay for unselected state
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 24))
                                    .background(
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 28, height: 28)
                                    )
                                    .offset(x: 8, y: 8)
                            }
                        }
                    }
                }

                VStack(spacing: 2) {
                    Text(friend.name)
                        .font(.custom("Markazi Text", size: 16))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    if let username = friend.username {
                        Text(username)
                            .font(.custom("Markazi Text", size: 14))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle()) // Prevent button styling
    }
}

struct GroupSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let mockGroup = Group(id: UUID().uuidString, name: "Sample Group", promptFrequency: .sixHours, notificationsMuted: false)
        return GroupSettingsView(groupStore: GroupStore(), entryStore: EntryStore(groupId: mockGroup.id), group: mockGroup, isPresented: .constant(true))
    }
}

#Preview {
    let mockGroup = Group(id: UUID().uuidString, name: "Sample Group", promptFrequency: .sixHours, notificationsMuted: false)
    GroupSettingsView(groupStore: GroupStore(), entryStore: EntryStore(groupId: mockGroup.id), group: mockGroup, isPresented: .constant(true))
}



//
//  GroupSettingsView.swift
//  test2
//
//  Created by Angela Lee on 5/31/25.
//

