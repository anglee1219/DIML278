import SwiftUI
import FirebaseFirestore
import FirebaseAuth

@objc public class FriendsManager: NSObject, ObservableObject {
    @objc public static let shared = FriendsManager()
    private let db = Firestore.firestore()
    
    @Published public var friends: [User] = []
    @Published public var suggestedUsers: [User] = []
    @Published public var friendRequests: [User] = []
    
    private override init() {
        super.init()
        loadFriends()
        loadSuggestedUsers()
        loadFriendRequests()
    }
    
    // MARK: - Friend List Management
    
    private func loadFriends() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users")
            .document(currentUserId)
            .collection("friends")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else {
                    print("Error fetching friends: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self.friends = documents.compactMap { document in
                    let data = document.data()
                    return User(
                        id: document.documentID,
                        name: data["name"] as? String ?? "",
                        username: data["username"] as? String,
                        role: .member
                    )
                }
            }
    }
    
    private func loadSuggestedUsers() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users")
            .whereField("id", isNotEqualTo: currentUserId)
            .limit(to: 20)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else {
                    print("Error fetching suggested users: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let currentFriendIds = Set(self.friends.map { $0.id })
                self.suggestedUsers = documents.compactMap { document in
                    let data = document.data()
                    let userId = document.documentID
                    
                    // Filter out users who are already friends
                    guard !currentFriendIds.contains(userId) else { return nil }
                    
                    return User(
                        id: userId,
                        name: data["name"] as? String ?? "",
                        username: data["username"] as? String,
                        role: .member
                    )
                }
            }
    }
    
    private func loadFriendRequests() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users")
            .document(currentUserId)
            .collection("friendRequests")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else {
                    print("Error fetching friend requests: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self.friendRequests = documents.compactMap { document in
                    let data = document.data()
                    return User(
                        id: document.documentID,
                        name: data["name"] as? String ?? "",
                        username: data["username"] as? String,
                        role: .member
                    )
                }
            }
    }
    
    // MARK: - Friend Request Management
    
    public func sendFriendRequest(to userId: String) {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        let friendRequestData: [String: Any] = [
            "senderId": currentUser.uid,
            "senderName": currentUser.displayName ?? "",
            "status": "pending",
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        db.collection("users")
            .document(userId)
            .collection("friendRequests")
            .document(currentUser.uid)
            .setData(friendRequestData) { error in
                if let error = error {
                    print("Error sending friend request: \(error.localizedDescription)")
                }
            }
    }
    
    public func acceptFriendRequest(from user: User) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Add to current user's friends
        let currentUserFriendData: [String: Any] = [
            "name": user.name,
            "username": user.username ?? "",
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        // Add current user to the other user's friends
        guard let currentUserName = Auth.auth().currentUser?.displayName else { return }
        let otherUserFriendData: [String: Any] = [
            "name": currentUserName,
            "username": "", // Add username if available
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        let batch = db.batch()
        
        // Add to current user's friends
        let currentUserFriendRef = db.collection("users")
            .document(currentUserId)
            .collection("friends")
            .document(user.id)
        batch.setData(currentUserFriendData, at: currentUserFriendRef)
        
        // Add to other user's friends
        let otherUserFriendRef = db.collection("users")
            .document(user.id)
            .collection("friends")
            .document(currentUserId)
        batch.setData(otherUserFriendData, at: otherUserFriendRef)
        
        // Remove the friend request
        let requestRef = db.collection("users")
            .document(currentUserId)
            .collection("friendRequests")
            .document(user.id)
        batch.deleteDocument(requestRef)
        
        batch.commit { error in
            if let error = error {
                print("Error accepting friend request: \(error.localizedDescription)")
            }
        }
    }
    
    public func rejectFriendRequest(from user: User) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users")
            .document(currentUserId)
            .collection("friendRequests")
            .document(user.id)
            .delete { error in
                if let error = error {
                    print("Error rejecting friend request: \(error.localizedDescription)")
                }
            }
    }
    
    public func removeFriend(_ friendId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let batch = db.batch()
        
        // Remove from current user's friends
        let currentUserFriendRef = db.collection("users")
            .document(currentUserId)
            .collection("friends")
            .document(friendId)
        batch.deleteDocument(currentUserFriendRef)
        
        // Remove from other user's friends
        let otherUserFriendRef = db.collection("users")
            .document(friendId)
            .collection("friends")
            .document(currentUserId)
        batch.deleteDocument(otherUserFriendRef)
        
        batch.commit { error in
            if let error = error {
                print("Error removing friend: \(error.localizedDescription)")
            }
        }
    }
} 