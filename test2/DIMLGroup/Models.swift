import SwiftUI

struct User: Identifiable, Hashable {
    var id: String
    var name: String
}

struct Group: Identifiable {
    var id: String
    var name: String
    var members: [User]
    var currentInfluencerId: String
    var date: Date
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

struct SuggestedUser: Identifiable {
    let id = UUID()
    let name: String
    let username: String
    let mutualFriends: Int
    let source: String
}

let sampleSuggestions: [SuggestedUser] = [
    SuggestedUser(name: "Chase Anderson", username: "chaseyanderson12", mutualFriends: 3, source: "3 mutual friends"),
    SuggestedUser(name: "Julia Xu", username: "julia_15", mutualFriends: 5, source: "5+ mutual friends"),
    SuggestedUser(name: "Josh Wren", username: "joshua.wren", mutualFriends: 0, source: "from your contacts")
]
