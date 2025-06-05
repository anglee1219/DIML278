import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Foundation

class GroupStore: ObservableObject {
    @Published private(set) var groups: [Group] = []
    private let userDefaults = UserDefaults.standard
    private let db = Firestore.firestore()
    private var currentUserId: String?
    private var groupsListener: ListenerRegistration?
    
    init() {
        setupAuthListener()
        loadGroups()
    }
    
    deinit {
        groupsListener?.remove()
    }
    
    private func setupAuthListener() {
        // Listen for auth state changes to reset data when user changes
        _ = Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            let newUserId = user?.uid
            
            if self?.currentUserId != newUserId {
                print("🧹 GroupStore: User changed from \(self?.currentUserId ?? "nil") to \(newUserId ?? "nil")")
                self?.currentUserId = newUserId
                
                if newUserId != nil {
                    self?.loadGroups()
                } else {
                    self?.clearAllData()
                }
            }
        }
    }
    
    private func clearAllData() {
        print("🧹 GroupStore: Clearing all group data")
        groupsListener?.remove()
        DispatchQueue.main.async {
            self.groups.removeAll()
        }
    }
    
    private var groupsKey: String {
        guard let userId = currentUserId ?? Auth.auth().currentUser?.uid else {
            return "savedGroups_anonymous" // Fallback, but this shouldn't be used
        }
        return "savedGroups_\(userId)"
    }
    
    private func loadGroups() {
        guard let userId = Auth.auth().currentUser?.uid else {
            clearAllData()
            return
        }
        
        currentUserId = userId
        print("🔄 GroupStore: Loading groups for user: \(userId)")
        
        // Remove existing listener
        groupsListener?.remove()
        
        // Set up Firestore listener for groups where this user is a member
        groupsListener = db.collection("groups")
            .whereField("memberIds", arrayContains: userId)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ GroupStore: Error fetching groups from Firestore: \(error.localizedDescription)")
                    // Fallback to local storage if Firestore fails
                    self.loadGroupsFromLocal()
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("❌ GroupStore: No snapshot received")
                    return
                }
                
                let source = snapshot.metadata.isFromCache ? "cache" : "server"
                print("🔄 GroupStore: Received \(snapshot.documents.count) groups from \(source) for user: \(userId)")
                
                guard !snapshot.documents.isEmpty else {
                    print("📭 GroupStore: No groups found in Firestore where user \(userId) is a member")
                    DispatchQueue.main.async {
                        self.groups = []
                    }
                    return
                }
                
                let groups = snapshot.documents.compactMap { document -> Group? in
                    let data = document.data()
                    
                    // Manually decode the group from Firestore data
                    let id = document.documentID
                    let name = data["name"] as? String ?? ""
                    let currentInfluencerId = data["currentInfluencerId"] as? String ?? ""
                    let promptFrequencyRaw = data["promptFrequency"] as? String ?? "sixHours"
                    let promptFrequency = PromptFrequency(rawValue: promptFrequencyRaw) ?? .sixHours
                    let notificationsMuted = data["notificationsMuted"] as? Bool ?? false
                    
                    // Handle date conversion from Firestore Timestamp
                    let date: Date
                    if let timestamp = data["date"] as? Timestamp {
                        date = timestamp.dateValue()
                    } else {
                        date = Date()
                    }
                    
                    // Handle members - decode from the members array
                    let members: [User]
                    if let membersData = data["members"] as? [[String: Any]] {
                        members = membersData.compactMap { memberData -> User? in
                            guard let userId = memberData["id"] as? String,
                                  let userName = memberData["name"] as? String else {
                                return nil
                            }
                            
                            let roleValue = memberData["role"] as? Int ?? 2 // Default to member (2)
                            let role = UserRole(rawValue: roleValue) ?? .member
                            
                            return User(
                                id: userId,
                                name: userName,
                                username: memberData["username"] as? String,
                                email: memberData["email"] as? String,
                                role: role,
                                profileImageUrl: memberData["profileImageUrl"] as? String,
                                pronouns: memberData["pronouns"] as? String,
                                zodiacSign: memberData["zodiacSign"] as? String,
                                location: memberData["location"] as? String,
                                school: memberData["school"] as? String,
                                interests: memberData["interests"] as? String
                            )
                        }
                    } else {
                        members = []
                    }
                    
                    return Group(
                        id: id,
                        name: name,
                        members: members,
                        currentInfluencerId: currentInfluencerId,
                        date: date,
                        promptFrequency: promptFrequency,
                        notificationsMuted: notificationsMuted
                    )
                }
                
                print("✅ GroupStore: Loaded \(groups.count) groups from Firestore for user: \(userId)")
                DispatchQueue.main.async {
                    self.groups = groups.sorted { $0.date > $1.date } // Sort by newest first
                    
                    // Also save to local storage as backup
                    self.saveGroupsToLocal()
                }
            }
    }
    
    // Fallback method to load from local storage
    private func loadGroupsFromLocal() {
        guard Auth.auth().currentUser?.uid != nil else {
            clearAllData()
            return
        }
        
        let key = groupsKey
        print("🔄 GroupStore: Loading groups from local storage")
        
        if let data = userDefaults.data(forKey: key),
           let decodedGroups = try? JSONDecoder().decode([Group].self, from: data) {
            DispatchQueue.main.async {
                self.groups = decodedGroups
            }
            print("✅ GroupStore: Loaded \(decodedGroups.count) groups from local storage")
        } else {
            print("📭 GroupStore: No saved groups found in local storage")
            DispatchQueue.main.async {
                self.groups = []
            }
        }
    }
    
    // Save to local storage as backup
    private func saveGroupsToLocal() {
        guard Auth.auth().currentUser?.uid != nil else {
            print("❌ GroupStore: Cannot save groups - no authenticated user")
            return
        }
        
        let key = groupsKey
        
        if let encodedData = try? JSONEncoder().encode(groups) {
            userDefaults.set(encodedData, forKey: key)
            userDefaults.synchronize()
        }
    }
    
    // Legacy method - keeping for compatibility but now saves to Firestore
    private func saveGroups() {
        saveGroupsToLocal()
    }
    
    func addGroup(_ group: Group) {
        print("➕ GroupStore: Adding group '\(group.name)' to Firestore")
        
        // Create group data for Firestore
        let groupData: [String: Any] = [
            "name": group.name,
            "date": Timestamp(date: group.date),
            "currentInfluencerId": group.currentInfluencerId,
            "promptFrequency": group.promptFrequency.rawValue,
            "notificationsMuted": group.notificationsMuted,
            "memberIds": group.members.map { $0.id }, // Array of member IDs for querying
            "members": group.members.map { member in
                [
                    "id": member.id,
                    "name": member.name,
                    "username": member.username ?? "",
                    "role": member.role.rawValue,
                    "email": member.email ?? "",
                    "profileImageUrl": member.profileImageUrl ?? "",
                    "pronouns": member.pronouns ?? "",
                    "zodiacSign": member.zodiacSign ?? "",
                    "location": member.location ?? "",
                    "school": member.school ?? "",
                    "interests": member.interests ?? ""
                ]
            }
        ]
        
        // Save to Firestore
        let groupRef = db.collection("groups").document(group.id)
        groupRef.setData(groupData) { [weak self] error in
            if let error = error {
                print("❌ GroupStore: Error saving group to Firestore: \(error.localizedDescription)")
                // Fallback to local storage if Firestore fails
                DispatchQueue.main.async {
                    self?.groups.insert(group, at: 0)
                    self?.saveGroupsToLocal()
                }
            } else {
                print("✅ GroupStore: Successfully saved group '\(group.name)' to Firestore")
                // The listener will automatically update the local groups array
            }
        }
    }
    
    func updateGroup(_ updatedGroup: Group) {
        print("🔄 GroupStore: Updating group '\(updatedGroup.name)' in Firestore")
        
        // Create updated group data
        let groupData: [String: Any] = [
            "name": updatedGroup.name,
            "date": Timestamp(date: updatedGroup.date),
            "currentInfluencerId": updatedGroup.currentInfluencerId,
            "promptFrequency": updatedGroup.promptFrequency.rawValue,
            "notificationsMuted": updatedGroup.notificationsMuted,
            "memberIds": updatedGroup.members.map { $0.id },
            "members": updatedGroup.members.map { member in
                [
                    "id": member.id,
                    "name": member.name,
                    "username": member.username ?? "",
                    "role": member.role.rawValue,
                    "email": member.email ?? "",
                    "profileImageUrl": member.profileImageUrl ?? "",
                    "pronouns": member.pronouns ?? "",
                    "zodiacSign": member.zodiacSign ?? "",
                    "location": member.location ?? "",
                    "school": member.school ?? "",
                    "interests": member.interests ?? ""
                ]
            }
        ]
        
        // Update in Firestore
        db.collection("groups").document(updatedGroup.id).setData(groupData) { [weak self] error in
            if let error = error {
                print("❌ GroupStore: Error updating group in Firestore: \(error.localizedDescription)")
                // Fallback to local update
                if let index = self?.groups.firstIndex(where: { $0.id == updatedGroup.id }) {
                    DispatchQueue.main.async {
                        self?.groups[index] = updatedGroup
                        self?.saveGroupsToLocal()
                    }
                }
            } else {
                print("✅ GroupStore: Successfully updated group '\(updatedGroup.name)' in Firestore")
                // The listener will automatically update the local groups array
            }
        }
    }
    
    func deleteGroup(_ group: Group) {
        print("🗑️ GroupStore: Deleting group '\(group.name)' from Firestore")
        
        // Delete from Firestore
        db.collection("groups").document(group.id).delete { [weak self] error in
            if let error = error {
                print("❌ GroupStore: Error deleting group from Firestore: \(error.localizedDescription)")
                // Fallback to local deletion
                DispatchQueue.main.async {
                    self?.groups.removeAll { $0.id == group.id }
                    self?.saveGroupsToLocal()
                }
            } else {
                print("✅ GroupStore: Successfully deleted group '\(group.name)' from Firestore")
                // The listener will automatically update the local groups array
            }
        }
    }
    
    func leaveGroup(_ group: Group) -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ GroupStore: Cannot leave group - no authenticated user")
            return false
        }
        
        print("👋 GroupStore: User \(currentUserId) attempting to leave group '\(group.name)'")
        
        // Check if current user is in the group
        guard group.members.contains(where: { $0.id == currentUserId }) else {
            print("❌ GroupStore: User is not a member of this group")
            return false
        }
        
        // If this is the only member, delete the entire group
        if group.members.count <= 1 {
            print("🗑️ GroupStore: Only one member left, deleting entire group")
            deleteGroup(group)
            return true
        }
        
        // Remove current user from the group
        var updatedGroup = group
        updatedGroup.members.removeAll { $0.id == currentUserId }
        
        // If the leaving user was the influencer, select a new random influencer
        if group.currentInfluencerId == currentUserId {
            if let newInfluencer = updatedGroup.members.randomElement() {
                updatedGroup.currentInfluencerId = newInfluencer.id
                // Update the new influencer's role
                if let index = updatedGroup.members.firstIndex(where: { $0.id == newInfluencer.id }) {
                    updatedGroup.members[index].role = .influencer
                }
                print("👑 GroupStore: New influencer selected: \(newInfluencer.name)")
            }
        }
        
        // Update the group in Firestore with the removed member
        print("🔄 GroupStore: Updating group in Firestore after member left")
        updateGroup(updatedGroup)
        
        print("✅ GroupStore: Successfully left group '\(group.name)'")
        return true
    }
    
    func getGroup(withId id: String) -> Group? {
        return groups.first { $0.id == id }
    }
    
    func addMembersToGroup(groupId: String, newMembers: [User]) {
        if let index = groups.firstIndex(where: { $0.id == groupId }) {
            var updatedGroup = groups[index]
            updatedGroup.members.append(contentsOf: newMembers)
            groups[index] = updatedGroup
            saveGroups()
        }
    }
    
    func removeMemberFromGroup(groupId: String, memberId: String) {
        guard let index = groups.firstIndex(where: { $0.id == groupId }) else {
            print("❌ GroupStore: Group not found")
            return
        }
        
        var updatedGroup = groups[index]
        _ = updatedGroup.members.count // Use the count for logging purposes
        
        print("👤 GroupStore: Removing member \(memberId) from group '\(updatedGroup.name)'")
        
        // Remove the member
        updatedGroup.members.removeAll { $0.id == memberId }
        
        // If this was the last member, delete the group
        if updatedGroup.members.isEmpty {
            print("🗑️ GroupStore: No members left, deleting group")
            deleteGroup(updatedGroup)
            return
        }
        
        // If only one member left, delete the group
        if updatedGroup.members.count == 1 {
            print("🗑️ GroupStore: Only one member left after removal, deleting group")
            deleteGroup(updatedGroup)
            return
        }
        
        // If the removed member was the influencer, select a new random influencer
        if updatedGroup.currentInfluencerId == memberId {
            if let newInfluencer = updatedGroup.members.randomElement() {
                updatedGroup.currentInfluencerId = newInfluencer.id
                // Update the new influencer's role
                if let memberIndex = updatedGroup.members.firstIndex(where: { $0.id == newInfluencer.id }) {
                    updatedGroup.members[memberIndex].role = .influencer
                }
                print("👑 GroupStore: New influencer selected after member removal: \(newInfluencer.name)")
            }
        }
        
        groups[index] = updatedGroup
        saveGroups()
        print("✅ GroupStore: Successfully removed member from group")
    }
} 