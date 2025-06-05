import SwiftUI
import Foundation
import FirebaseFirestore
import FirebaseAuth

public enum FriendRequestStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case rejected = "rejected"
}

public class FriendRequestManager: ObservableObject {
    public static let shared = FriendRequestManager()
    private let db = Firestore.firestore()
    
    @Published public var pendingRequests: [FriendRequest] = []
    @Published public var sentRequests: [FriendRequest] = []
    
    private var requestsListener: ListenerRegistration?
    private var sentRequestsListener: ListenerRegistration?
    
    private init() {
        setupAuthListener()
    }
    
    deinit {
        requestsListener?.remove()
        sentRequestsListener?.remove()
    }
    
    private func setupAuthListener() {
        // Listen for auth state changes to reset data when user changes
        _ = Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            if user != nil {
                self?.startListening()
            } else {
                self?.clearAllData()
            }
        }
    }
    
    public func clearAllData() {
        print("🧹 FriendRequestManager: Clearing all data")
        requestsListener?.remove()
        sentRequestsListener?.remove()
        
        DispatchQueue.main.async {
            self.pendingRequests.removeAll()
            self.sentRequests.removeAll()
        }
    }
    
    public func startListening() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { 
            clearAllData()
            return 
        }
        
        print("🔄 FriendRequestManager: Starting listeners for user: \(currentUserId)")
        
        // Clear existing data first
        DispatchQueue.main.async {
            self.pendingRequests.removeAll()
            self.sentRequests.removeAll()
        }
        
        // Remove existing listeners
        requestsListener?.remove()
        sentRequestsListener?.remove()
        
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
                
                self?.pendingRequests = documents.compactMap { document -> FriendRequest? in
                    let data = document.data()
                    print("🔍 Raw request data: \(data)")
                    print("🔍 Document ID: \(document.documentID)")
                    print("🔍 fromUserId: \(data["fromUserId"] as? String ?? "nil")")
                    print("🔍 from: \(data["from"] as? String ?? "nil")")
                    
                    let fromId = data["fromUserId"] as? String ?? data["from"] as? String ?? ""
                    let toId = data["toUserId"] as? String ?? data["to"] as? String ?? ""
                    
                    // Fallback: if fromId is empty, use the document ID (which should be the sender's ID)
                    let finalFromId = fromId.isEmpty ? document.documentID : fromId
                    
                    print("🔍 Final fromId: '\(finalFromId)'")
                    print("🔍 Final toId: '\(toId)'")
                    
                    return FriendRequest(
                        id: document.documentID,
                        from: finalFromId,
                        to: toId,
                        status: FriendRequestStatus(rawValue: data["status"] as? String ?? "") ?? .pending,
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    )
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
                
                self?.sentRequests = documents.compactMap { document -> FriendRequest? in
                    let data = document.data()
                    return FriendRequest(
                        id: document.documentID,
                        from: data["fromUserId"] as? String ?? data["from"] as? String ?? "",
                        to: data["toUserId"] as? String ?? data["to"] as? String ?? "",
                        status: FriendRequestStatus(rawValue: data["status"] as? String ?? "") ?? .pending,
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
            }
    }
    
    public func sendFriendRequest(to targetUserId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FriendRequestManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        let request = [
            "from": currentUserId,
            "to": targetUserId,
            "status": FriendRequestStatus.pending.rawValue,
            "timestamp": FieldValue.serverTimestamp()
        ] as [String : Any]
        
        // Add to target user's friendRequests
        try await db.collection("users")
            .document(targetUserId)
            .collection("friendRequests")
            .document(currentUserId)
            .setData(request)
        
        // Add to current user's sentRequests
        try await db.collection("users")
            .document(currentUserId)
            .collection("sentRequests")
            .document(targetUserId)
            .setData(request)
    }
    
    public func acceptFriendRequest(from senderId: String) async throws {
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
        
        // Add to friends arrays - use setData with merge to handle missing friends field
        try await db.collection("users").document(currentUserId)
            .setData(["friends": FieldValue.arrayUnion([senderId])], merge: true)
        
        try await db.collection("users").document(senderId)
            .setData(["friends": FieldValue.arrayUnion([currentUserId])], merge: true)
    }
    
    public func rejectFriendRequest(from senderId: String) async throws {
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
    
    public func cancelFriendRequest(to targetUserId: String) async throws {
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
public struct FriendRequest: Codable, Identifiable {
    public let id: String
    public let from: String
    public let to: String
    public let status: FriendRequestStatus
    public let timestamp: Date
    
    public var dictionary: [String: Any] {
        return [
            "id": id,
            "from": from,
            "to": to,
            "status": status.rawValue,
            "timestamp": Timestamp(date: timestamp)
        ]
    }
    
    public enum CodingKeys: String, CodingKey {
        case id
        case from
        case to
        case status
        case timestamp
    }
    
    public init(id: String, from: String, to: String, status: FriendRequestStatus, timestamp: Date) {
        self.id = id
        self.from = from
        self.to = to
        self.status = status
        self.timestamp = timestamp
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        from = try container.decode(String.self, forKey: .from)
        to = try container.decode(String.self, forKey: .to)
        status = try container.decode(FriendRequestStatus.self, forKey: .status)
        
        // Handle Firestore timestamp
        if let timestamp = try? container.decode(Timestamp.self, forKey: .timestamp) {
            self.timestamp = timestamp.dateValue()
        } else {
            self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(from, forKey: .from)
        try container.encode(to, forKey: .to)
        try container.encode(status, forKey: .status)
        try container.encode(Timestamp(date: timestamp), forKey: .timestamp)
    }
} 