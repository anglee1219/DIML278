import Foundation
import UIKit
import FirebaseFirestore

public enum UserRole: Int, Codable {
    case admin = 0
    case influencer = 1
    case member = 2
    
    public var stringValue: String {
        switch self {
        case .admin: return "Admin"
        case .influencer: return "Current Influencer"
        case .member: return "Member"
        }
    }
}

public class User: Identifiable, Codable {
    public var id: String
    public var name: String
    public var username: String?
    public var role: UserRole = .member
    public var profileImageUrl: String?
    public var pronouns: String?
    public var birthday: Date?
    public var bio: String?
    
    public init(id: String = UUID().uuidString, 
                name: String, 
                username: String? = nil, 
                role: UserRole = .member,
                profileImageUrl: String? = nil, 
                pronouns: String? = nil, 
                birthday: Date? = nil, 
                bio: String? = nil) {
        self.id = id
        self.name = name
        self.username = username
        self.role = role
        self.profileImageUrl = profileImageUrl
        self.pronouns = pronouns
        self.birthday = birthday
        self.bio = bio
    }
    
    public static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
}

extension User: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Group: Identifiable, Codable {
    var id: String
    var name: String
    var members: [User]
    var currentInfluencerId: String
    var date: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case members
        case currentInfluencerId
        case date
    }
    
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
