import Foundation
import FirebaseFirestore
import FirebaseAuth
import UserNotifications

// Simplified version of PushNotificationManager that works with Cloud Functions
class PushNotificationManager: ObservableObject {
    static let shared = PushNotificationManager()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    // Send push notification via Cloud Function
    func sendPushNotification(to userIds: [String], title: String, body: String, data: [String: String]) {
        print("📱 🚀 === PushNotificationManager: Sending push notifications ===")
        
        for userId in userIds {
            // Get FCM token and store notification request
            db.collection("users").document(userId).getDocument { [weak self] document, error in
                guard let self = self else { return }
                
                guard let userData = document?.data(),
                      let fcmToken = userData["fcmToken"] as? String else {
                    print("📱 🚀 ⚠️ No FCM token for user \(userId)")
                    return
                }
                
                // Store notification request for Cloud Function
                let notificationRequest: [String: Any] = [
                    "fcmToken": fcmToken,
                    "title": title,
                    "body": body,
                    "data": data,
                    "timestamp": FieldValue.serverTimestamp(),
                    "processed": false
                ]
                
                self.db.collection("notificationRequests").addDocument(data: notificationRequest) { error in
                    if let error = error {
                        print("📱 🚀 ❌ Error storing notification: \(error)")
                    } else {
                        print("📱 🚀 ✅ Push notification queued for user \(userId)")
                    }
                }
            }
        }
    }
} 