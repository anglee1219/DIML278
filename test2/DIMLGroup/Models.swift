import Foundation
import UIKit
import FirebaseFirestore
import SwiftUI
import AVFoundation
import FirebaseStorage
import FirebaseAuth
import Firebase

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

struct Group: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var members: [User]
    var currentInfluencerId: String
    var date: Date
    var promptFrequency: PromptFrequency
    var notificationsMuted: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case members
        case memberIds
        case currentInfluencerId
        case date
        case promptFrequency
        case notificationsMuted
    }
    
    init(id: String = UUID().uuidString, name: String, members: [User] = [], currentInfluencerId: String? = nil, date: Date = Date(), promptFrequency: PromptFrequency = .sixHours, notificationsMuted: Bool = false) {
        self.id = id
        self.name = name
        self.members = members
        self.currentInfluencerId = currentInfluencerId ?? UUID().uuidString
        self.date = date
        self.promptFrequency = promptFrequency
        self.notificationsMuted = notificationsMuted
    }
    
    // Custom decoder to handle Firestore data and backwards compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        currentInfluencerId = try container.decode(String.self, forKey: .currentInfluencerId)
        
        // Handle date - could be Date or Firestore Timestamp
        if let timestamp = try? container.decode(Date.self, forKey: .date) {
            date = timestamp
        } else {
            // Fallback to current date if decoding fails
            date = Date()
        }
        
        // Handle members - could be array of User objects or memberIds
        if let membersArray = try? container.decode([User].self, forKey: .members) {
            members = membersArray
        } else {
            // If we can't decode members directly, create empty array
            // The Firestore listener will handle fetching member details
            members = []
        }
        
        // Backwards compatibility - use default values if fields don't exist
        promptFrequency = try container.decodeIfPresent(PromptFrequency.self, forKey: .promptFrequency) ?? .sixHours
        notificationsMuted = try container.decodeIfPresent(Bool.self, forKey: .notificationsMuted) ?? false
    }
    
    // Custom encoder for proper Firestore format
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(members, forKey: .members)
        try container.encode(currentInfluencerId, forKey: .currentInfluencerId)
        try container.encode(date, forKey: .date)
        try container.encode(promptFrequency, forKey: .promptFrequency)
        try container.encode(notificationsMuted, forKey: .notificationsMuted)
    }
    
    // Equatable conformance
    static func == (lhs: Group, rhs: Group) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.members == rhs.members &&
               lhs.currentInfluencerId == rhs.currentInfluencerId &&
               lhs.date == rhs.date &&
               lhs.promptFrequency == rhs.promptFrequency &&
               lhs.notificationsMuted == rhs.notificationsMuted
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

struct UserReaction: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let emoji: String
    let timestamp: Date
    
    init(id: String = UUID().uuidString, userId: String, emoji: String, timestamp: Date = Date()) {
        self.id = id
        self.userId = userId
        self.emoji = emoji
        self.timestamp = timestamp
    }
    
    static func == (lhs: UserReaction, rhs: UserReaction) -> Bool {
        return lhs.id == rhs.id &&
               lhs.userId == rhs.userId &&
               lhs.emoji == rhs.emoji &&
               lhs.timestamp == rhs.timestamp
    }
}

struct DIMLEntry: Identifiable, Equatable {
    let id: String
    let userId: String
    let prompt: String
    let response: String
    let image: UIImage?
    let imageURL: String?
    let timestamp: Date
    var comments: [Comment]
    var reactions: [String: Int] // Legacy - keeping for backwards compatibility
    var userReactions: [UserReaction] // New - individual user reactions
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
         userReactions: [UserReaction] = [],
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
        self.userReactions = userReactions
        self.frameSize = frameSize ?? FrameSize.random
    }
    
    // Helper methods for new reaction system
    func getUserReaction(for userId: String) -> UserReaction? {
        return userReactions.first { $0.userId == userId }
    }
    
    func getReactionCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        for reaction in userReactions {
            counts[reaction.emoji, default: 0] += 1
        }
        return counts
    }
    
    func getUsersWhoReacted() -> [String] {
        return Array(Set(userReactions.map { $0.userId }))
    }
    
    // Equatable conformance
    static func == (lhs: DIMLEntry, rhs: DIMLEntry) -> Bool {
        return lhs.id == rhs.id &&
               lhs.userId == rhs.userId &&
               lhs.prompt == rhs.prompt &&
               lhs.response == rhs.response &&
               lhs.imageURL == rhs.imageURL &&
               lhs.timestamp == rhs.timestamp &&
               lhs.comments == rhs.comments &&
               lhs.reactions == rhs.reactions &&
               lhs.userReactions == rhs.userReactions &&
               lhs.frameSize == rhs.frameSize
        // Note: We don't compare UIImage since it's not Equatable
    }
}

struct Comment: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let text: String
    let timestamp: Date
    let imageData: Data? // For storing photo comments
    let imageURL: String? // For Firebase Storage URLs
    
    init(id: String = UUID().uuidString, userId: String, text: String, timestamp: Date = Date(), imageData: Data? = nil, imageURL: String? = nil) {
        self.id = id
        self.userId = userId
        self.text = text
        self.timestamp = timestamp
        self.imageData = imageData
        self.imageURL = imageURL
    }
    
    // Equatable conformance
    static func == (lhs: Comment, rhs: Comment) -> Bool {
        return lhs.id == rhs.id &&
               lhs.userId == rhs.userId &&
               lhs.text == rhs.text &&
               lhs.timestamp == rhs.timestamp &&
               lhs.imageData == rhs.imageData &&
               lhs.imageURL == rhs.imageURL
    }
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
