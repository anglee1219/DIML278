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
        setupAuthListener()
    }
    
    deinit {
        friendsListener?.remove()
    }
    
    private func setupAuthListener() {
        // Listen for auth state changes to reset data when user changes
        _ = Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            if user != nil {
                self?.setupListeners()
            } else {
                self?.clearAllData()
            }
        }
    }
    
    func clearAllData() {
        print("🧹 FriendsManager: Clearing all data")
        friendsListener?.remove()
        listenersRegistered = false
        
        DispatchQueue.main.async {
            self.friends.removeAll()
            self.suggestedUsers.removeAll()
            self.pendingRequests.removeAll()
        }
    }
    
    func setupListeners() {
        guard let currentUserId = Auth.auth().currentUser?.uid, !listenersRegistered else { 
            if Auth.auth().currentUser?.uid == nil {
                clearAllData()
            }
            return 
        }
        
        print("🔄 FriendsManager: Setting up listeners for user: \(currentUserId)")
        
        // Clear existing data first
        DispatchQueue.main.async {
            self.friends.removeAll()
            self.suggestedUsers.removeAll()
            self.pendingRequests.removeAll()
        }
        
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
                        
                        // IMPORTANT: Fetch suggested users AFTER friends are loaded
                        // This prevents the race condition where friends appear in discovery
                        self.fetchSuggestedUsers(currentUserId: currentUserId)
                    }
                }
            }
        
        listenersRegistered = true
    }
    
    private func fetchSuggestedUsers(currentUserId: String) {
        // Fetch suggested users (users who are not friends) AFTER friends list is loaded
        db.collection("users")
            .limit(to: 20)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self,
                      let snapshot = snapshot else {
                    print("Error fetching suggested users: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                // NOW we have the current friends list loaded, so we can properly filter
                let currentFriendIds = Set(self.friends.map { $0.id })
                print("🔍 Current friend IDs for filtering: \(currentFriendIds)")
                
                let users = snapshot.documents.compactMap { document -> User? in
                    let data = document.data()
                    let userId = document.documentID
                    
                    // Skip current user and existing friends
                    let shouldSkip = userId == currentUserId || currentFriendIds.contains(userId)
                    if shouldSkip {
                        print("🔍 Skipping user \(userId): current user or already friend")
                        return nil
                    }
                    
                    return User(
                        id: userId,
                        name: data["name"] as? String ?? data["username"] as? String ?? "",
                        username: data["username"] as? String,
                        email: data["email"] as? String,
                        role: .member,
                        profileImageUrl: data["profileImageURL"] as? String, // Use consistent field name with capital URL
                        pronouns: data["pronouns"] as? String,
                        zodiacSign: data["zodiacSign"] as? String,
                        location: data["location"] as? String,
                        school: data["school"] as? String,
                        interests: data["interests"] as? String
                    )
                }
                
                print("🔍 Found \(users.count) suggested users after filtering")
                
                DispatchQueue.main.async {
                    self.suggestedUsers = users
                }
            }
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
                        email: data["email"] as? String,
                        role: .member,
                        profileImageUrl: data["profileImageURL"] as? String, // Use consistent field name with capital URL
                        pronouns: data["pronouns"] as? String,
                        zodiacSign: data["zodiacSign"] as? String,
                        location: data["location"] as? String,
                        school: data["school"] as? String,
                        interests: data["interests"] as? String
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
                "toUserId": userId,
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
        guard let currentUserId = Auth.auth().currentUser?.uid else { 
            print("❌ FriendsManager: Cannot remove friend - no authenticated user")
            return 
        }
        
        print("👋 FriendsManager: Removing friend \(friendId) for user \(currentUserId)")
        
        // First, get current user's friend list
        db.collection("users").document(currentUserId).getDocument { [weak self] document, error in
            guard let self = self,
                  let document = document,
                  let data = document.data() else {
                print("❌ Error fetching user data for friend removal: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            var currentFriends = data["friends"] as? [String] ?? []
            
            // Remove the friend from the array
            currentFriends.removeAll { $0 == friendId }
            
            // Update current user's friends array in Firestore
            self.db.collection("users").document(currentUserId).updateData([
                "friends": currentFriends
            ]) { error in
                if let error = error {
                    print("❌ Error updating current user's friends: \(error.localizedDescription)")
                } else {
                    print("✅ Successfully removed friend from current user's list")
                }
            }
        }
        
        // Also remove current user from the friend's friends list
        db.collection("users").document(friendId).getDocument { [weak self] document, error in
            guard let self = self,
                  let document = document,
                  let data = document.data() else {
                print("❌ Error fetching friend's data for mutual removal: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            var friendsFriends = data["friends"] as? [String] ?? []
            
            // Remove current user from friend's array
            friendsFriends.removeAll { $0 == currentUserId }
            
            // Update friend's friends array in Firestore
            self.db.collection("users").document(friendId).updateData([
                "friends": friendsFriends
            ]) { error in
                if let error = error {
                    print("❌ Error updating friend's friends list: \(error.localizedDescription)")
                } else {
                    print("✅ Successfully removed current user from friend's list")
                }
            }
        }
        
        // Update local state immediately for better UX
        DispatchQueue.main.async {
            self.friends.removeAll { $0.id == friendId }
            print("🔄 Local friends list updated, now has \(self.friends.count) friends")
        }
    }
} 