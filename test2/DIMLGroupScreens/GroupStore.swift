import SwiftUI

class GroupStore: ObservableObject {
    @Published private(set) var groups: [Group] = []
    private let userDefaults = UserDefaults.standard
    private let groupsKey = "savedGroups"
    
    init() {
        loadGroups()
    }
    
    private func loadGroups() {
        if let data = userDefaults.data(forKey: groupsKey),
           let decodedGroups = try? JSONDecoder().decode([Group].self, from: data) {
            self.groups = decodedGroups
        }
    }
    
    private func saveGroups() {
        if let encodedData = try? JSONEncoder().encode(groups) {
            userDefaults.set(encodedData, forKey: groupsKey)
            userDefaults.synchronize() // Force immediate write to disk
        }
    }
    
    func addGroup(_ group: Group) {
        groups.append(group)
        saveGroups()
    }
    
    func updateGroup(_ updatedGroup: Group) {
        if let index = groups.firstIndex(where: { $0.id == updatedGroup.id }) {
            groups[index] = updatedGroup
            saveGroups()
        }
    }
    
    func deleteGroup(_ group: Group) {
        groups.removeAll { $0.id == group.id }
        saveGroups()
    }
    
    func leaveGroup(_ group: Group) {
        deleteGroup(group)
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
        if let index = groups.firstIndex(where: { $0.id == groupId }) {
            var updatedGroup = groups[index]
            updatedGroup.members.removeAll { $0.id == memberId }
            groups[index] = updatedGroup
            saveGroups()
        }
    }
} 