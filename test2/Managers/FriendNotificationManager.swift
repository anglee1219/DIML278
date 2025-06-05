import Foundation
import UserNotifications
import FirebaseAuth
import FirebaseFirestore

class FriendNotificationManager: ObservableObject {
    static let shared = FriendNotificationManager()
    
    private let db = Firestore.firestore()
    private var friendRequestListener: ListenerRegistration?
    
    private init() {
        startListening()
    }
    
    deinit {
        friendRequestListener?.remove()
    }
    
    private func startListening() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Listen for new friend requests
        friendRequestListener = db.collection("users")
            .document(currentUserId)
            .collection("friendRequests")
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("🔔 Friend request listener error: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot else { return }
                
                // Check for new documents (friend requests)
                for change in snapshot.documentChanges {
                    if change.type == .added {
                        let data = change.document.data()
                        let senderId = data["from"] as? String ?? ""
                        
                        // Get sender's name and send notification
                        self.getSenderNameAndNotify(senderId: senderId)
                    }
                }
            }
    }
    
    private func getSenderNameAndNotify(senderId: String) {
        db.collection("users").document(senderId).getDocument { [weak self] document, error in
            guard let data = document?.data() else { return }
            
            let senderName = data["name"] as? String ?? "Someone"
            
            DispatchQueue.main.async {
                self?.sendFriendRequestNotification(senderName: senderName)
            }
        }
    }
    
    private func sendFriendRequestNotification(senderName: String) {
        let content = UNMutableNotificationContent()
        content.title = "🤝 New Friend Request"
        content.body = "\(senderName) wants to be your friend!"
        content.sound = .default
        content.badge = 1
        
        // Custom data for handling the tap
        content.userInfo = [
            "type": "friend_request",
            "sender_name": senderName
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let identifier = "friend_request_\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🔔 ❌ Error sending friend request notification: \(error)")
            } else {
                print("🔔 ✅ Friend request notification sent")
            }
        }
    }
    
    func clearFriendRequestNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let friendRequestNotifications = requests.filter { $0.identifier.contains("friend_request") }
            let identifiers = friendRequestNotifications.map { $0.identifier }
            
            if !identifiers.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
                print("🔔 Cleared \(identifiers.count) friend request notifications")
            }
        }
    }
} 