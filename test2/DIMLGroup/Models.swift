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
