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
    public var email: String?
    public var role: UserRole = .member
    public var profileImageUrl: String?
    public var pronouns: String?
    public var zodiacSign: String?
    public var location: String?
    public var school: String?
    public var interests: String?
    public var createdAt: Date?
    public var lastUpdated: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case username
        case email
        case role
        case profileImageUrl
        case pronouns
        case zodiacSign
        case location
        case school
        case interests
        case createdAt
        case lastUpdated
    }
    
    public init(id: String = UUID().uuidString, 
                name: String, 
                username: String? = nil,
                email: String? = nil,
                role: UserRole = .member,
                profileImageUrl: String? = nil,
                pronouns: String? = nil,
                zodiacSign: String? = nil,
                location: String? = nil,
                school: String? = nil,
                interests: String? = nil,
                createdAt: Date? = nil,
                lastUpdated: Date? = nil) {
        self.id = id
        self.name = name
        self.username = username
        self.email = email
        self.role = role
        self.profileImageUrl = profileImageUrl
        self.pronouns = pronouns
        self.zodiacSign = zodiacSign
        self.location = location
        self.school = school
        self.interests = interests
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        role = try container.decodeIfPresent(UserRole.self, forKey: .role) ?? .member
        profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        pronouns = try container.decodeIfPresent(String.self, forKey: .pronouns)
        zodiacSign = try container.decodeIfPresent(String.self, forKey: .zodiacSign)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        school = try container.decodeIfPresent(String.self, forKey: .school)
        interests = try container.decodeIfPresent(String.self, forKey: .interests)
        
        if let timestamp = try container.decodeIfPresent(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        }
        if let timestamp = try container.decodeIfPresent(Timestamp.self, forKey: .lastUpdated) {
            lastUpdated = timestamp.dateValue()
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(username, forKey: .username)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encode(role, forKey: .role)
        try container.encodeIfPresent(profileImageUrl, forKey: .profileImageUrl)
        try container.encodeIfPresent(pronouns, forKey: .pronouns)
        try container.encodeIfPresent(zodiacSign, forKey: .zodiacSign)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(school, forKey: .school)
        try container.encodeIfPresent(interests, forKey: .interests)
        
        if let createdAt = createdAt {
            try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
        }
        if let lastUpdated = lastUpdated {
            try container.encode(Timestamp(date: lastUpdated), forKey: .lastUpdated)
        }
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

// Frame Size for dynamic post layouts
enum FrameSize: String, CaseIterable, Codable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case extraLarge = "extraLarge"
    
    var height: CGFloat {
        switch self {
        case .small:
            return 200
        case .medium:
            return 280
        case .large:
            return 320
        case .extraLarge:
            return 360
        }
    }
    
    var displayName: String {
        switch self {
        case .small:
            return "Small"
        case .medium:
            return "Medium"
        case .large:
            return "Large"
        case .extraLarge:
            return "Extra Large"
        }
    }
    
    // Get a random frame size
    static var random: FrameSize {
        return FrameSize.allCases.randomElement() ?? .medium
    }
}

struct DIMLEntry: Identifiable {
    let id: String
    let userId: String
    let prompt: String
    let response: String
    let image: UIImage?
    let imageURL: String?
    let timestamp: Date
    var comments: [Comment]
    var reactions: [String: Int]
    let frameSize: FrameSize
    
    init(id: String = UUID().uuidString, 
         userId: String, 
         prompt: String, 
         response: String, 
         image: UIImage? = nil, 
         imageURL: String? = nil,
         timestamp: Date = Date(),
         comments: [Comment] = [], 
         reactions: [String: Int] = [:], 
         frameSize: FrameSize? = nil) {
        self.id = id
        self.userId = userId
        self.prompt = prompt
        self.response = response
        self.image = image
        self.imageURL = imageURL
        self.timestamp = timestamp
        self.comments = comments
        self.reactions = reactions
        self.frameSize = frameSize ?? FrameSize.random
    }
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
