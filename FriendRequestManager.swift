import Foundation
import FirebaseFirestore
import FirebaseAuth

enum FriendRequestStatus: String {
    case pending = "pending"
    case accepted = "accepted"
    case rejected = "rejected"
}

class FriendRequestManager: ObservableObject {
    static let shared = FriendRequestManager()
    private let db = Firestore.firestore()
    
    @Published var pendingRequests: [FriendRequest] = []
    @Published var sentRequests: [FriendRequest] = []
    
    private var requestsListener: ListenerRegistration?
    private var sentRequestsListener: ListenerRegistration?
    
    private init() {
        startListening()
    }
    
    deinit {
        requestsListener?.remove()
        sentRequestsListener?.remove()
    }
    
    func startListening() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Listen for incoming requests
        requestsListener = db.collection("users")
            .document(currentUserId)
            .collection("friendRequests")
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching requests: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self?.pendingRequests = documents.compactMap { document in
                    try? document.data(as: FriendRequest.self)
                }
            }
        
        // Listen for sent requests
        sentRequestsListener = db.collection("users")
            .document(currentUserId)
            .collection("sentRequests")
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching sent requests: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self?.sentRequests = documents.compactMap { document in
                    try? document.data(as: FriendRequest.self)
                }
            }
    }
    
    func sendFriendRequest(to targetUserId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FriendRequestManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        let request = FriendRequest(
            id: targetUserId,
            from: currentUserId,
            to: targetUserId,
            status: .pending,
            timestamp: Date()
        )
        
        // Add to target user's friendRequests
        try await db.collection("users")
            .document(targetUserId)
            .collection("friendRequests")
            .document(currentUserId)
            .setData(request.dictionary)
        
        // Add to current user's sentRequests
        try await db.collection("users")
            .document(currentUserId)
            .collection("sentRequests")
            .document(targetUserId)
            .setData(request.dictionary)
    }
    
    func acceptFriendRequest(from senderId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FriendRequestManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        // Update request status
        try await db.collection("users")
            .document(currentUserId)
            .collection("friendRequests")
            .document(senderId)
            .updateData(["status": FriendRequestStatus.accepted.rawValue])
        
        // Update sender's sent request status
        try await db.collection("users")
            .document(senderId)
            .collection("sentRequests")
            .document(currentUserId)
            .updateData(["status": FriendRequestStatus.accepted.rawValue])
        
        // Add to friends arrays
        try await db.collection("users").document(currentUserId)
            .updateData(["friends": FieldValue.arrayUnion([senderId])])
        
        try await db.collection("users").document(senderId)
            .updateData(["friends": FieldValue.arrayUnion([currentUserId])])
    }
    
    func rejectFriendRequest(from senderId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FriendRequestManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        // Update request status
        try await db.collection("users")
            .document(currentUserId)
            .collection("friendRequests")
            .document(senderId)
            .updateData(["status": FriendRequestStatus.rejected.rawValue])
        
        // Update sender's sent request status
        try await db.collection("users")
            .document(senderId)
            .collection("sentRequests")
            .document(currentUserId)
            .updateData(["status": FriendRequestStatus.rejected.rawValue])
    }
    
    func cancelFriendRequest(to targetUserId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FriendRequestManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        // Delete from target user's friendRequests
        try await db.collection("users")
            .document(targetUserId)
            .collection("friendRequests")
            .document(currentUserId)
            .delete()
        
        // Delete from current user's sentRequests
        try await db.collection("users")
            .document(currentUserId)
            .collection("sentRequests")
            .document(targetUserId)
            .delete()
    }
}

// MARK: - FriendRequest Model
struct FriendRequest: Codable, Identifiable {
    let id: String
    let from: String
    let to: String
    let status: FriendRequestStatus
    let timestamp: Date
    
    var dictionary: [String: Any] {
        return [
            "id": id,
            "from": from,
            "to": to,
            "status": status.rawValue,
            "timestamp": timestamp
        ]
    }
} 