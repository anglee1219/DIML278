import Foundation

enum UserRole {
    case admin
    case member
    case influencer
}

struct User: Identifiable, Hashable {
    let id: String
    var name: String
    var username: String?
    var role: UserRole
    
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
} 