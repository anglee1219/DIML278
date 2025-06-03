import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI
@_exported import struct test2.User

// MARK: - FriendsManager
class FriendsManager: ObservableObject {
    static let shared = FriendsManager()
    
    @Published var friends: [User] = []
    @Published var suggestedUsers: [User] = []
    @Published var pendingRequests: [User] = []
    
    private let db = Firestore.firestore()
    private var listenersRegistered = false
    
    private init() {
        setupListeners()
    }
    
    func setupListeners() {
        guard let currentUserId = Auth.auth().currentUser?.uid, !listenersRegistered else { return }
        
        // Listen for friends
        db.collection("users").document(currentUserId).collection("friends")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let snapshot = snapshot else { return }
                
                let friendIds = snapshot.documents.map { $0.documentID }
                self.fetchUserDetails(for: friendIds) { users in
                    DispatchQueue.main.async {
                        self.friends = users
                    }
                }
            }
        
        // Fetch suggested users (users who are not friends)
        db.collection("users")
            .whereField("id", isNotEqualTo: currentUserId)
            .limit(to: 20)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let snapshot = snapshot else { return }
                
                let users = snapshot.documents.compactMap { document -> User? in
                    try? document.data(as: User.self)
                }
                
                DispatchQueue.main.async {
                    self.suggestedUsers = users.filter { user in
                        !self.friends.contains(where: { $0.id == user.id })
                    }
                }
            }
        
        listenersRegistered = true
    }
    
    private func fetchUserDetails(for userIds: [String], completion: @escaping ([User]) -> Void) {
        guard !userIds.isEmpty else {
            completion([])
            return
        }
        
        let group = DispatchGroup()
        var users: [User] = []
        
        for userId in userIds {
            group.enter()
            db.collection("users").document(userId).getDocument { document, error in
                defer { group.leave() }
                if let document = document, let user = try? document.data(as: User.self) {
                    users.append(user)
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(users)
        }
    }
    
    func sendFriendRequest(to userId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let requestData: [String: Any] = [
            "status": "pending",
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        db.collection("users").document(userId)
            .collection("friendRequests").document(currentUserId)
            .setData(requestData)
    }
    
    func removeFriend(_ friendId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Remove from current user's friends
        db.collection("users").document(currentUserId)
            .collection("friends").document(friendId).delete()
        
        // Remove from friend's friends list
        db.collection("users").document(friendId)
            .collection("friends").document(currentUserId).delete()
        
        // Update local state
        DispatchQueue.main.async {
            self.friends.removeAll { $0.id == friendId }
        }
    }
}

// MARK: - User Model
struct User: Identifiable, Hashable {
    let id: String
    let name: String
    let username: String?
    var role: Role
    
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum Role: String {
    case admin
    case member
    case influencer
} 