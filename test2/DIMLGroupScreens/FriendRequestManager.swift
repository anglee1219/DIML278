import SwiftUI
import Foundation
import FirebaseFirestore
import FirebaseAuth
import UserNotifications

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
        
        // Get current user's name for the notification
        let currentUserDoc = try await db.collection("users").document(currentUserId).getDocument()
        let currentUserName = currentUserDoc.data()?["name"] as? String ?? "Someone"
        
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
        
        // Send push notification for friend request
        await sendFriendRequestNotification(to: targetUserId, fromUserName: currentUserName, fromUserId: currentUserId)
    }
    
    // MARK: - Push Notification Methods
    
    private func sendFriendRequestNotification(to targetUserId: String, fromUserName: String, fromUserId: String) async {
        print("🤝 === FRIEND REQUEST NOTIFICATION DEBUGGING ===")
        print("🤝 TARGET USER ID: \(targetUserId)")
        print("🤝 FROM USER ID: \(fromUserId)")
        print("🤝 FROM USER NAME: \(fromUserName)")
        print("🤝 CURRENT USER ID: \(Auth.auth().currentUser?.uid ?? "nil")")
        
        // Validate that we're not sending to ourselves
        if targetUserId == Auth.auth().currentUser?.uid {
            print("🤝 ❌ ERROR: Trying to send friend request notification to self!")
            return
        }
        
        // Get target user's FCM token
        do {
            print("🤝 Fetching FCM token for target user: \(targetUserId)")
            let userDoc = try await db.collection("users").document(targetUserId).getDocument()
            
            guard userDoc.exists else {
                print("🤝 ❌ Target user document does not exist: \(targetUserId)")
                return
            }
            
            guard let userData = userDoc.data() else {
                print("🤝 ❌ No data in target user document: \(targetUserId)")
                return
            }
            
            guard let fcmToken = userData["fcmToken"] as? String else {
                print("🤝 ⚠️ No FCM token found for target user \(targetUserId)")
                print("🤝 ⚠️ Available fields: \(userData.keys)")
                return
            }
            
            print("🤝 ✅ Found FCM token for target user: \(String(fcmToken.suffix(8)))")
            
            // Add target user ID to notification data for extra verification
            await sendFCMPushNotification(
                token: fcmToken,
                title: "🤝 New Friend Request",
                body: "\(fromUserName) wants to be your friend!",
                data: [
                    "type": "friend_request",
                    "fromUserId": fromUserId,
                    "fromUserName": fromUserName,
                    "targetUserId": targetUserId  // Add this for verification
                ]
            )
            
        } catch {
            print("🤝 ❌ Error getting FCM token: \(error)")
        }
    }
    
    private func sendFCMPushNotification(token: String, title: String, body: String, data: [String: String]) async {
        print("🤝 📱 === FCM PUSH NOTIFICATION DEBUGGING ===")
        print("🤝 📱 FCM Token (last 8): \(String(token.suffix(8)))")
        print("🤝 📱 Title: \(title)")
        print("🤝 📱 Body: \(body)")
        print("🤝 📱 Data: \(data)")
        
        // Verify target user from data
        if let targetUserId = data["targetUserId"] {
            print("🤝 📱 TARGET USER VERIFICATION: \(targetUserId)")
            print("🤝 📱 CURRENT USER: \(Auth.auth().currentUser?.uid ?? "nil")")
            
            if targetUserId == Auth.auth().currentUser?.uid {
                print("🤝 📱 ❌ ERROR: FCM notification target is current user - ABORTING!")
                return
            }
        }
        
        // Create the notification payload
        let payload: [String: Any] = [
            "to": token,
            "notification": [
                "title": title,
                "body": body,
                "sound": "default",
                "badge": 1
            ],
            "data": data,
            "priority": "high",
            "content_available": true
        ]
        
        print("🤝 📱 FCM Payload: \(payload)")
        
        // Store notification request in Firestore to trigger Cloud Function
        let notificationRequest: [String: Any] = [
            "fcmToken": token,
            "title": title,
            "body": body,
            "data": data,
            "timestamp": FieldValue.serverTimestamp(),
            "processed": false,
            "targetUserId": data["targetUserId"] ?? "",  // Add for Cloud Function verification
            "senderUserId": Auth.auth().currentUser?.uid ?? ""
        ]
        
        do {
            let docRef = try await db.collection("notificationRequests").addDocument(data: notificationRequest)
            print("🤝 ✅ Friend request notification queued via Cloud Function with ID: \(docRef.documentID)")
            print("🤝 ✅ Notification should go to user: \(data["targetUserId"] ?? "unknown")")
        } catch {
            print("🤝 ❌ Error queuing friend request notification: \(error)")
        }
    }
    
    public func acceptFriendRequest(from senderId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FriendRequestManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        // Get current user's name for the notification
        let currentUserDoc = try await db.collection("users").document(currentUserId).getDocument()
        let currentUserName = currentUserDoc.data()?["name"] as? String ?? "Someone"
        
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
        
        // Send notification to the original sender that their request was accepted
        await sendFriendRequestAcceptedNotification(to: senderId, fromUserName: currentUserName, fromUserId: currentUserId)
    }
    
    private func sendFriendRequestAcceptedNotification(to targetUserId: String, fromUserName: String, fromUserId: String) async {
        print("🤝 ✅ Sending friend request accepted notification to \(targetUserId)")
        
        // Get target user's FCM token
        do {
            let userDoc = try await db.collection("users").document(targetUserId).getDocument()
            guard let userData = userDoc.data(),
                  let fcmToken = userData["fcmToken"] as? String else {
                print("🤝 ⚠️ No FCM token found for user \(targetUserId)")
                // Don't send local notification as it will go to wrong user
                return
            }
            
            // Send FCM push notification
            await sendFCMPushNotification(
                token: fcmToken,
                title: "🎉 Friend Request Accepted!",
                body: "\(fromUserName) accepted your friend request!",
                data: [
                    "type": "friend_request_accepted",
                    "fromUserId": fromUserId,
                    "fromUserName": fromUserName
                ]
            )
            
        } catch {
            print("🤝 ❌ Error getting FCM token for accepted notification: \(error)")
            // Don't send local notification fallback as it will go to wrong user
        }
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