import Foundation
import FirebaseFirestore
import FirebaseAuth

class FriendsManager: ObservableObject {
    static let shared = FriendsManager()
    private let db = Firestore.firestore()
    
    @Published var friends: [User] = []
    @Published var friendRequests: [User] = []
    @Published var suggestedUsers: [User] = []
    
    init() {
        loadFriends()
        loadFriendRequests()
        loadSuggestedUsers()
    }
    
    func loadFriends() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Listen to friends subcollection in real-time
        db.collection("users").document(currentUserId)
            .collection("friends")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching friends: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                // Get friend IDs and fetch their full user data
                let friendIds = documents.map { $0.documentID }
                self?.fetchUsersData(userIds: friendIds) { users in
                    DispatchQueue.main.async {
                        self?.friends = users
                    }
                }
            }
    }
    
    func loadFriendRequests() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Listen to friend requests subcollection
        db.collection("users").document(currentUserId)
            .collection("friendRequests")
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching friend requests: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let requestIds = documents.map { $0.documentID }
                self?.fetchUsersData(userIds: requestIds) { users in
                    DispatchQueue.main.async {
                        self?.friendRequests = users
                    }
                }
            }
    }
    
    func loadSuggestedUsers() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Get all users except current user
        db.collection("users")
            .limit(to: 20)
            .getDocuments { [weak self] snapshot, error in
                guard let documents = snapshot?.documents,
                      let self = self else {
                    print("Error fetching suggested users: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let users = documents.compactMap { document -> User? in
                    // Skip current user
                    if document.documentID == currentUserId {
                        return nil
                    }
                    
                    let data = document.data()
                    return User(
                        id: document.documentID,
                        name: data["name"] as? String ?? "",
                        username: data["username"] as? String ?? "",
                        role: .member
                    )
                }
                
                // Filter out existing friends
                DispatchQueue.main.async {
                    self.suggestedUsers = users.filter { user in
                        !self.friends.contains(where: { $0.id == user.id })
                    }
                }
            }
    }
    
    private func fetchUsersData(userIds: [String], completion: @escaping ([User]) -> Void) {
        guard !userIds.isEmpty else {
            completion([])
            return
        }
        
        let group = DispatchGroup()
        var users: [User] = []
        
        for userId in userIds {
            group.enter()
            
            db.collection("users").document(userId).getDocument { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("Error fetching user data: \(error.localizedDescription)")
                    return
                }
                
                if let data = snapshot?.data() {
                    let user = User(
                        id: userId,
                        name: data["name"] as? String ?? "",
                        username: data["username"] as? String ?? "",
                        role: .member
                    )
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
        
        // Add friend request to recipient's friendRequests subcollection
        db.collection("users").document(userId)
            .collection("friendRequests").document(currentUserId)
            .setData([
                "status": "pending",
                "timestamp": FieldValue.serverTimestamp()
            ]) { error in
                if let error = error {
                    print("Error sending friend request: \(error.localizedDescription)")
                }
            }
    }
    
    func acceptFriendRequest(from userId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let batch = db.batch()
        
        // Add to current user's friends subcollection
        let currentUserFriendRef = db.collection("users").document(currentUserId)
            .collection("friends").document(userId)
        batch.setData([
            "timestamp": FieldValue.serverTimestamp(),
            "status": "accepted"
        ], forDocument: currentUserFriendRef)
        
        // Add to sender's friends subcollection
        let senderFriendRef = db.collection("users").document(userId)
            .collection("friends").document(currentUserId)
        batch.setData([
            "timestamp": FieldValue.serverTimestamp(),
            "status": "accepted"
        ], forDocument: senderFriendRef)
        
        // Delete the friend request
        let requestRef = db.collection("users").document(currentUserId)
            .collection("friendRequests").document(userId)
        batch.deleteDocument(requestRef)
        
        // Commit the batch
        batch.commit { error in
            if let error = error {
                print("Error accepting friend request: \(error.localizedDescription)")
            }
        }
    }
    
    func removeFriend(_ userId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let batch = db.batch()
        
        // Remove from current user's friends subcollection
        let currentUserFriendRef = db.collection("users").document(currentUserId)
            .collection("friends").document(userId)
        batch.deleteDocument(currentUserFriendRef)
        
        // Remove from other user's friends subcollection
        let otherUserFriendRef = db.collection("users").document(userId)
            .collection("friends").document(currentUserId)
        batch.deleteDocument(otherUserFriendRef)
        
        // Commit the batch
        batch.commit { error in
            if let error = error {
                print("Error removing friend: \(error.localizedDescription)")
            }
        }
    }
} 