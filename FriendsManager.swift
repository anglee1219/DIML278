import Foundation
import FirebaseFirestore
import FirebaseAuth

class FriendsManager: ObservableObject {
    static let shared = FriendsManager()
    private let db = Firestore.firestore()
    
    @Published var friends: [User] = []
    @Published var suggestedUsers: [User] = []
    
    private var friendsListener: ListenerRegistration?
    private var suggestedUsersListener: ListenerRegistration?
    
    private init() {
        startListening()
    }
    
    deinit {
        friendsListener?.remove()
        suggestedUsersListener?.remove()
    }
    
    func startListening() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Listen for friends list changes
        friendsListener = db.collection("users")
            .document(currentUserId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let document = snapshot else {
                    print("Error fetching friends: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let friendIds = document.data()?["friends"] as? [String] ?? []
                self?.loadFriendDetails(friendIds: friendIds)
            }
        
        // Listen for suggested users
        suggestedUsersListener = db.collection("users")
            .whereField("uid", isNotEqualTo: currentUserId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching suggested users: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let suggestedUsers = documents.compactMap { document -> User? in
                    guard let data = document.data() as [String: Any],
                          let uid = data["uid"] as? String,
                          let name = data["name"] as? String else {
                        return nil
                    }
                    
                    return User(
                        id: uid,
                        name: name,
                        username: data["username"] as? String,
                        role: .member
                    )
                }
                
                // Filter out users who are already friends
                DispatchQueue.main.async {
                    self?.suggestedUsers = suggestedUsers.filter { user in
                        !self!.friends.contains { $0.id == user.id }
                    }
                }
            }
    }
    
    private func loadFriendDetails(friendIds: [String]) {
        guard !friendIds.isEmpty else {
            DispatchQueue.main.async {
                self.friends = []
            }
            return
        }
        
        let group = DispatchGroup()
        var loadedFriends: [User] = []
        
        for friendId in friendIds {
            group.enter()
            
            db.collection("users").document(friendId).getDocument { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("Error loading friend details: \(error.localizedDescription)")
                    return
                }
                
                if let data = snapshot?.data(),
                   let name = data["name"] as? String {
                    let friend = User(
                        id: friendId,
                        name: name,
                        username: data["username"] as? String,
                        role: .member
                    )
                    loadedFriends.append(friend)
                }
            }
        }
        
        group.notify(queue: .main) {
            self.friends = loadedFriends.sorted { $0.name < $1.name }
        }
    }
    
    func removeFriend(_ friendId: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let batch = db.batch()
        
        // Remove from current user's friends array
        let currentUserRef = db.collection("users").document(currentUserId)
        batch.updateData([
            "friends": FieldValue.arrayRemove([friendId])
        ], forDocument: currentUserRef)
        
        // Remove from friend's friends array
        let friendRef = db.collection("users").document(friendId)
        batch.updateData([
            "friends": FieldValue.arrayRemove([currentUserId])
        ], forDocument: friendRef)
        
        // Commit the batch
        batch.commit { error in
            if let error = error {
                print("Error removing friend: \(error.localizedDescription)")
            }
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