import Foundation
import FirebaseFirestore
import FirebaseAuth
import UserNotifications

class PushNotificationManager: ObservableObject {
    static let shared = PushNotificationManager()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Send FCM Push Notifications
    
    func sendPromptUnlockPushNotification(to userId: String, prompt: String, groupName: String, groupId: String) {
        print("📱 🚀 === SENDING FCM PUSH NOTIFICATION FOR PROMPT UNLOCK ===")
        print("📱 🚀 Target user: \(userId)")
        print("📱 🚀 Prompt: \(prompt)")
        print("📱 🚀 Group: \(groupName)")
        
        // Get the user's FCM token from Firestore
        db.collection("users").document(userId).getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                print("📱 🚀 ❌ Error fetching user FCM token: \(error.localizedDescription)")
                return
            }
            
            guard let data = document?.data(),
                  let fcmToken = data["fcmToken"] as? String else {
                print("📱 🚀 ⚠️ No FCM token found for user \(userId)")
                print("📱 🚀 ⚠️ User may need to restart app to register for push notifications")
                return
            }
            
            print("📱 🚀 ✅ Found FCM token for user: \(String(fcmToken.suffix(8)))")
            
            // Send the push notification via FCM
            self.sendFCMPushNotification(
                token: fcmToken,
                title: "✨ New Prompt Ready!",
                body: "Your new prompt is ready in \(groupName): \(prompt)",
                data: [
                    "type": "prompt_unlock",
                    "groupId": groupId,
                    "groupName": groupName,
                    "prompt": prompt,
                    "userId": userId
                ]
            )
        }
    }
    
    func sendDIMLUploadPushNotification(to userIds: [String], uploaderName: String, prompt: String, groupId: String) {
        print("📱 🚀 === SENDING FCM PUSH NOTIFICATIONS FOR DIML UPLOAD ===")
        print("📱 🚀 Target users: \(userIds.count)")
        print("📱 🚀 Uploader: \(uploaderName)")
        print("📱 🚀 Prompt: \(prompt)")
        
        // Get FCM tokens for all target users
        let group = DispatchGroup()
        
        for userId in userIds {
            group.enter()
            
            db.collection("users").document(userId).getDocument { [weak self] document, error in
                defer { group.leave() }
                
                guard let self = self else { return }
                
                if let error = error {
                    print("📱 🚀 ❌ Error fetching FCM token for user \(userId): \(error.localizedDescription)")
                    return
                }
                
                guard let data = document?.data(),
                      let fcmToken = data["fcmToken"] as? String else {
                    print("📱 🚀 ⚠️ No FCM token found for user \(userId)")
                    return
                }
                
                print("📱 🚀 📤 Sending DIML upload push to user \(userId)")
                
                // Send the push notification via FCM
                self.sendFCMPushNotification(
                    token: fcmToken,
                    title: "📸 New DIML Posted!",
                    body: "\(uploaderName) shared: \(prompt)",
                    data: [
                        "type": "diml_upload",
                        "groupId": groupId,
                        "uploaderName": uploaderName,
                        "prompt": prompt,
                        "userId": userId
                    ]
                )
            }
        }
        
        group.notify(queue: .main) {
            print("📱 🚀 ✅ All DIML upload push notifications sent")
        }
    }
    
    func sendReactionPushNotification(to userId: String, reactorName: String, reaction: String, groupId: String) {
        print("📱 🚀 === SENDING FCM PUSH NOTIFICATION FOR REACTION ===")
        
        db.collection("users").document(userId).getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            guard let data = document?.data(),
                  let fcmToken = data["fcmToken"] as? String else {
                print("📱 🚀 ⚠️ No FCM token found for reaction notification to user \(userId)")
                return
            }
            
            self.sendFCMPushNotification(
                token: fcmToken,
                title: "🎉 New Reaction!",
                body: "\(reactorName) reacted \(reaction) to your DIML",
                data: [
                    "type": "reaction",
                    "groupId": groupId,
                    "reactorName": reactorName,
                    "reaction": reaction,
                    "userId": userId
                ]
            )
        }
    }
    
    func sendCommentPushNotification(to userId: String, commenterName: String, commentText: String, groupId: String) {
        print("📱 🚀 === SENDING FCM PUSH NOTIFICATION FOR COMMENT ===")
        
        db.collection("users").document(userId).getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            guard let data = document?.data(),
                  let fcmToken = data["fcmToken"] as? String else {
                print("📱 🚀 ⚠️ No FCM token found for comment notification to user \(userId)")
                return
            }
            
            self.sendFCMPushNotification(
                token: fcmToken,
                title: "💬 New Comment!",
                body: "\(commenterName): \(commentText)",
                data: [
                    "type": "comment",
                    "groupId": groupId,
                    "commenterName": commenterName,
                    "commentText": commentText,
                    "userId": userId
                ]
            )
        }
    }
    
    // MARK: - FCM HTTP API
    
    private func sendFCMPushNotification(token: String, title: String, body: String, data: [String: String]) {
        print("📱 🚀 🌐 === SENDING HTTP REQUEST TO FCM API ===")
        print("📱 🚀 🌐 Token: ...\(String(token.suffix(8)))")
        print("📱 🚀 🌐 Title: \(title)")
        print("📱 🚀 🌐 Body: \(body)")
        
        // FCM HTTP v1 API endpoint
        let fcmURL = "https://fcm.googleapis.com/v1/projects/cs-278-diml/messages:send"
        
        guard let url = URL(string: fcmURL) else {
            print("📱 🚀 ❌ Invalid FCM URL")
            return
        }
        
        // Create the FCM message payload
        let message: [String: Any] = [
            "message": [
                "token": token,
                "notification": [
                    "title": title,
                    "body": body
                ],
                "data": data,
                "apns": [
                    "payload": [
                        "aps": [
                            "alert": [
                                "title": title,
                                "body": body
                            ],
                            "sound": "default",
                            "badge": 1
                        ]
                    ]
                ]
            ]
        ]
        
        // Create the HTTP request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Get OAuth token for FCM (this would need to be implemented)
        // For now, we'll use a simplified approach with Cloud Functions
        print("📱 🚀 ⚠️ FCM HTTP v1 API requires OAuth token - implementing via Cloud Functions instead")
        
        // Alternative: Store notification in Firestore and let Cloud Functions send it
        sendViaCloudFunction(token: token, title: title, body: body, data: data)
    }
    
    // MARK: - Cloud Function Alternative
    
    private func sendViaCloudFunction(token: String, title: String, body: String, data: [String: String]) {
        print("📱 🚀 ☁️ === TRIGGERING CLOUD FUNCTION FOR PUSH NOTIFICATION ===")
        
        // Store notification request in Firestore to trigger Cloud Function
        let notificationRequest: [String: Any] = [
            "fcmToken": token,
            "title": title,
            "body": body,
            "data": data,
            "timestamp": FieldValue.serverTimestamp(),
            "processed": false
        ]
        
        db.collection("notificationRequests").addDocument(data: notificationRequest) { error in
            if let error = error {
                print("📱 🚀 ❌ Error storing notification request: \(error.localizedDescription)")
            } else {
                print("📱 🚀 ✅ Notification request stored - Cloud Function will send push notification")
                print("📱 🚀 ✅ This will work even when app is completely terminated!")
            }
        }
    }
    
    // MARK: - Fallback to Local Notifications
    
    func sendLocalNotificationFallback(title: String, body: String, data: [String: String]) {
        print("📱 🚀 📱 === FALLBACK TO LOCAL NOTIFICATION ===")
        print("📱 🚀 📱 This will only work if app is running or backgrounded")
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        content.userInfo = data
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let identifier = "fallback_\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("📱 🚀 📱 ❌ Error sending local notification fallback: \(error)")
            } else {
                print("📱 🚀 📱 ✅ Local notification fallback sent")
            }
        }
    }
} 