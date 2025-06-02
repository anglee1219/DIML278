import SwiftUI

struct User: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var username: String?
    var role: MemberRole?
    
    init(id: String = UUID().uuidString, name: String, username: String? = nil, role: MemberRole? = nil) {
        self.id = id
        self.name = name
        self.username = username
        self.role = role
    }
}

enum MemberRole: String, Codable {
    case admin = "Admin"
    case influencer = "Current Influencer"
    case member = "Member"
}

struct Group: Identifiable, Codable {
    var id: String
    var name: String
    var members: [User]
    var currentInfluencerId: String
    var date: Date
    
    init(id: String = UUID().uuidString, name: String, members: [User] = [], currentInfluencerId: String? = nil, date: Date = Date()) {
        self.id = id
        self.name = name
        self.members = members
        self.currentInfluencerId = currentInfluencerId ?? UUID().uuidString
        self.date = date
    }
}

struct DIMLEntry: Identifiable {
    let id: String
    let userId: String
    let prompt: String
    let response: String
    let image: UIImage?
    var comments: [Comment]
    var reactions: [String: Int]
}

struct Comment: Identifiable {
    let id: String
    let userId: String
    let text: String
    let timestamp: Date
}

struct SuggestedUser: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let username: String
    let mutualFriends: Int
    let source: String
    
    static func == (lhs: SuggestedUser, rhs: SuggestedUser) -> Bool {
        lhs.username == rhs.username
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(username)
    }
}

let sampleSuggestions: [SuggestedUser] = [
    SuggestedUser(name: "Sarah Johnson", username: "@sarahj", mutualFriends: 3, source: "Contacts"),
    SuggestedUser(name: "Mike Smith", username: "@mikesmith", mutualFriends: 2, source: "Suggested"),
    SuggestedUser(name: "Emma Wilson", username: "@emmaw", mutualFriends: 4, source: "Contacts"),
    SuggestedUser(name: "Alex Brown", username: "@alexb", mutualFriends: 1, source: "Suggested"),
    SuggestedUser(name: "Lisa Chen", username: "@lisac", mutualFriends: 5, source: "Contacts")
]

let existingFriends: [User] = [
    User(id: UUID().uuidString, name: "Sarah Johnson", username: "sarahj"),
    User(id: UUID().uuidString, name: "Mike Chen", username: "mikechen"),
    User(id: UUID().uuidString, name: "Emma Davis", username: "emma.d"),
    User(id: UUID().uuidString, name: "Alex Kim", username: "alexk"),
    User(id: UUID().uuidString, name: "Rachel Torres", username: "rachelt")
]
