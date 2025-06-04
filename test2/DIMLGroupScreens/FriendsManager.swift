import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

// MARK: - FriendsManager
class FriendsManager: ObservableObject {
    static let shared = FriendsManager()
    
    @Published var friends: [User] = []
    @Published var suggestedUsers: [User] = []
    @Published var pendingRequests: [User] = []
    
    private let db = Firestore.firestore()
    private var listenersRegistered = false
    private var friendsListener: ListenerRegistration?
    
    private init() {
        setupListeners()
    }
    
    deinit {
        friendsListener?.remove()
    }
    
    func setupListeners() {
        guard let currentUserId = Auth.auth().currentUser?.uid, !listenersRegistered else { return }
        
        // Remove existing listener if any
        friendsListener?.remove()
        
        // Listen for friends list changes
        friendsListener = db.collection("users").document(currentUserId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let document = snapshot,
                      let data = document.data() else {
                    print("Error fetching friends: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                // Get friends array from user document
                let friendIds = data["friends"] as? [String] ?? []
                
                // Fetch details for each friend
                self.fetchUserDetails(for: friendIds) { users in
                    DispatchQueue.main.async {
                        self.friends = users
                    }
                }
            }
        
        // Fetch suggested users (users who are not friends)
        db.collection("users")
            .limit(to: 20)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self,
                      let snapshot = snapshot else {
                    print("Error fetching suggested users: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let currentFriendIds = Set(self.friends.map { $0.id })
                let users = snapshot.documents.compactMap { document -> User? in
                    let data = document.data()
                    let userId = document.documentID
                    
                    // Skip current user and existing friends
                    guard userId != currentUserId && !currentFriendIds.contains(userId) else { return nil }
                    
                    return User(
                        id: userId,
                        name: data["name"] as? String ?? data["username"] as? String ?? "",
                        username: data["username"] as? String,
                        role: .member
                    )
                }
                
                DispatchQueue.main.async {
                    self.suggestedUsers = users
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
                if let document = document,
                   let data = document.data() {
                    let user = User(
                        id: userId,
                        name: data["name"] as? String ?? data["username"] as? String ?? "",
                        username: data["username"] as? String,
                        role: .member
                    )
                    users.append(user)
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(users.sorted { $0.name < $1.name })
        }
    }
    
    func sendFriendRequest(to userId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Get current user's profile data
        db.collection("users").document(currentUserId).getDocument { [weak self] document, error in
            guard let data = document?.data() else { return }
            
            let requestData: [String: Any] = [
                "status": "pending",
                "timestamp": FieldValue.serverTimestamp(),
                "fromUserId": currentUserId,
                "fromUserName": data["name"] as? String ?? data["username"] as? String ?? "",
                "fromUserUsername": data["username"] as? String ?? ""
            ]
            
            // Add to target user's friend requests
            self?.db.collection("users").document(userId)
                .collection("friendRequests").document(currentUserId)
                .setData(requestData)
            
            // Add to current user's sent requests
            self?.db.collection("users").document(currentUserId)
                .collection("sentRequests").document(userId)
                .setData(requestData)
        }
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