import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UserNotifications


class EntryStore: ObservableObject {
    @Published private(set) var entries: [DIMLEntry] = []
    private let groupId: String
    private var currentUserId: String?
    private let db = Firestore.firestore()
    private var entriesListener: ListenerRegistration?
    
    init(groupId: String) {
        self.groupId = groupId
        self.currentUserId = Auth.auth().currentUser?.uid
        print("🏗️ EntryStore: Initializing for group \(groupId) with user \(currentUserId ?? "unknown")")
        setupEntriesListener()
    }
    
    deinit {
        print("💀 EntryStore: Deinitializing for group \(groupId)")
        entriesListener?.remove()
    }
    
    private var storageKey: String {
        guard let userId = currentUserId ?? Auth.auth().currentUser?.uid else {
            return "entries_anonymous_\(groupId)" // Fallback
        }
        return "entries_\(userId)_\(groupId)"
    }
    
    private func setupEntriesListener() {
        print("🔄 EntryStore: Setting up Firestore listener for group \(groupId)")
        print("🔄 EntryStore: Current user: \(Auth.auth().currentUser?.uid ?? "none")")
        
        // Remove existing listener
        if let existingListener = entriesListener {
            print("🔄 EntryStore: Removing existing listener")
            existingListener.remove()
        }
        
        // Listen for entries in this group with real-time updates
        print("🔄 EntryStore: Creating new Firestore listener with includeMetadataChanges: true")
        entriesListener = db.collection("groups")
            .document(groupId)
            .collection("entries")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                guard let self = self else { 
                    print("❌ EntryStore: Self is nil in listener callback")
                    return 
                }
                
                if let error = error {
                    print("❌ EntryStore: Error fetching entries from Firestore: \(error.localizedDescription)")
                    // Fallback to local storage
                    self.loadEntriesFromLocal()
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("❌ EntryStore: No snapshot received")
                    return
                }
                
                // Check if this is a real-time update or from cache
                let source = snapshot.metadata.isFromCache ? "cache" : "server"
                let hasPendingWrites = snapshot.metadata.hasPendingWrites
                print("🔄 EntryStore: Received snapshot from \(source) with \(snapshot.documents.count) documents")
                print("🔄 EntryStore: Has pending writes: \(hasPendingWrites)")
                
                // CRITICAL: Process ALL updates, not just server ones
                if !snapshot.metadata.isFromCache {
                    print("🌟 EntryStore: REAL-TIME SERVER UPDATE - This should show latest reactions!")
                } else if snapshot.metadata.hasPendingWrites {
                    print("🔄 EntryStore: LOCAL UPDATE with pending writes - processing...")
                } else {
                    print("🔄 EntryStore: CACHE UPDATE - processing...")
                }
                
                guard !snapshot.documents.isEmpty else {
                    print("📭 EntryStore: No entries found in Firestore for group \(self.groupId)")
                    DispatchQueue.main.async {
                        self.entries = []
                    }
                    return
                }
                
                let entries = snapshot.documents.compactMap { document -> DIMLEntry? in
                    let data = document.data()
                    
                    guard let userId = data["userId"] as? String,
                          let prompt = data["prompt"] as? String,
                          let response = data["response"] as? String else {
                        print("❌ EntryStore: Invalid entry data for document \(document.documentID)")
                        return nil
                    }
                    
                    // Handle timestamp
                    let timestamp: Date
                    if let firestoreTimestamp = data["timestamp"] as? Timestamp {
                        timestamp = firestoreTimestamp.dateValue()
                    } else {
                        timestamp = Date()
                    }
                    
                    // Handle comments
                    let comments: [Comment]
                    if let commentsData = data["comments"] as? [[String: Any]] {
                        comments = commentsData.compactMap { commentData -> Comment? in
                            guard let commentId = commentData["id"] as? String,
                                  let commentUserId = commentData["userId"] as? String,
                                  let commentText = commentData["text"] as? String else {
                                return nil
                            }
                            
                            let commentTimestamp: Date
                            if let commentFirestoreTimestamp = commentData["timestamp"] as? Timestamp {
                                commentTimestamp = commentFirestoreTimestamp.dateValue()
                            } else {
                                commentTimestamp = Date()
                            }
                            
                            // Handle image data
                            var imageData: Data?
                            if let imageDataString = commentData["imageData"] as? String {
                                imageData = Data(base64Encoded: imageDataString)
                            }
                            
                            let imageURL = commentData["imageURL"] as? String
                            
                            return Comment(
                                id: commentId,
                                userId: commentUserId,
                                text: commentText,
                                timestamp: commentTimestamp,
                                imageData: imageData,
                                imageURL: imageURL
                            )
                        }
                    } else {
                        comments = []
                    }
                    
                    // Handle reactions - try new format first, fallback to legacy
                    let userReactions: [UserReaction]
                    if let userReactionsData = data["userReactions"] as? [[String: Any]] {
                        userReactions = userReactionsData.compactMap { reactionData -> UserReaction? in
                            guard let id = reactionData["id"] as? String,
                                  let userId = reactionData["userId"] as? String,
                                  let emoji = reactionData["emoji"] as? String else {
                                print("⚠️ EntryStore: Invalid reaction data: \(reactionData)")
                                return nil
                            }
                            
                            let reactionTimestamp: Date
                            if let firestoreTimestamp = reactionData["timestamp"] as? Timestamp {
                                reactionTimestamp = firestoreTimestamp.dateValue()
                            } else {
                                reactionTimestamp = Date()
                            }
                            
                            return UserReaction(
                                id: id,
                                userId: userId,
                                emoji: emoji,
                                timestamp: reactionTimestamp
                            )
                        }
                    } else {
                        userReactions = []
                    }
                    
                    // Handle legacy reactions for backwards compatibility
                    let reactions = data["reactions"] as? [String: Int] ?? [:]
                    
                    // Handle frame size
                    let frameSizeRaw = data["frameSize"] as? String ?? "medium"
                    let frameSize = FrameSize(rawValue: frameSizeRaw) ?? .medium
                    
                    // Handle prompt type with backward compatibility
                    let promptTypeRaw = data["promptType"] as? String ?? "image" // Default to image for old entries
                    let promptType = PromptType(rawValue: promptTypeRaw) ?? .image
                    
                    return DIMLEntry(
                        id: document.documentID,
                        userId: userId,
                        prompt: prompt,
                        response: response,
                        image: nil,
                        imageURL: data["imageURL"] as? String,
                        timestamp: timestamp,
                        comments: comments,
                        reactions: reactions,
                        userReactions: userReactions,
                        frameSize: frameSize,
                        promptType: promptType
                    )
                }
                
                print("✅ EntryStore: Loaded \(entries.count) entries from Firestore (\(source)) for group \(self.groupId)")
                
                // Enhanced reaction debugging
                for entry in entries.prefix(5) { // Check more entries
                    print("📊 Entry \(entry.id.prefix(8)): \(entry.userReactions.count) reactions, \(entry.comments.count) comments")
                    if !entry.userReactions.isEmpty {
                        print("   🎉 Reactions for \(entry.id.prefix(8)):")
                        for reaction in entry.userReactions {
                            print("      - \(reaction.emoji) by \(reaction.userId.prefix(8)) at \(reaction.timestamp)")
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    let oldEntryCount = self.entries.count
                    let oldReactionCounts = self.entries.map { entry in
                        (entry.id, entry.userReactions.count)
                    }
                    
                    // CRITICAL: Always update, even from cache
                    self.entries = entries
                    
                    let newEntryCount = entries.count
                    let newReactionCounts = entries.map { entry in
                        (entry.id, entry.userReactions.count)
                    }
                    
                    print("🔄 EntryStore: Updated local entries array (\(source))")
                    print("   📊 Entry count: \(oldEntryCount) → \(newEntryCount)")
                    
                    // Check for reaction changes
                    for (entryId, newCount) in newReactionCounts {
                        if let oldCount = oldReactionCounts.first(where: { $0.0 == entryId })?.1 {
                            if newCount != oldCount {
                                print("   🎉 Reaction count changed for \(entryId.prefix(8)): \(oldCount) → \(newCount)")
                            }
                        } else {
                            print("   🆕 New entry with \(newCount) reactions: \(entryId.prefix(8))")
                        }
                    }
                    
                    // Trigger explicit UI refresh
                    self.objectWillChange.send()
                    
                    // Also save to local storage as backup
                    self.saveEntriesToLocal()
                    print("🔄 EntryStore: UI update completed (\(source))")
                }
            }
    }
    
    func addEntry(_ entry: DIMLEntry) {
        print("💾 EntryStore: Adding entry to Firestore for group \(groupId)")
        print("💾 EntryStore: Entry ID: \(entry.id), User: \(entry.userId)")
        print("💾 EntryStore: Entry imageURL: \(entry.imageURL ?? "nil")")
        print("💾 EntryStore: Entry prompt: '\(entry.prompt)'")
        print("💾 EntryStore: Entry response: '\(entry.response)'")
        print("💾 EntryStore: Is image entry: \(entry.imageURL != nil)")
        
        // Prepare entry data for Firestore
        var entryData: [String: Any] = [
            "userId": entry.userId,
            "prompt": entry.prompt,
            "response": entry.response,
            "timestamp": Timestamp(date: entry.timestamp),
            "frameSize": entry.frameSize.rawValue,
            "reactions": entry.reactions,
            "promptType": entry.promptType.rawValue,
            "userReactions": entry.userReactions.map { reaction in
                [
                    "id": reaction.id,
                    "userId": reaction.userId,
                    "emoji": reaction.emoji,
                    "timestamp": Timestamp(date: reaction.timestamp)
                ]
            },
            "comments": entry.comments.map { comment in
                var commentData: [String: Any] = [
                    "id": comment.id,
                    "userId": comment.userId,
                    "text": comment.text,
                    "timestamp": Timestamp(date: comment.timestamp)
                ]
                
                // Add image data if present
                if let imageData = comment.imageData {
                    commentData["imageData"] = imageData.base64EncodedString()
                }
                
                if let imageURL = comment.imageURL {
                    commentData["imageURL"] = imageURL
                }
                
                return commentData
            }
        ]
        
        // Add imageURL if it exists
        if let imageURL = entry.imageURL {
            entryData["imageURL"] = imageURL
            print("💾 EntryStore: ✅ Adding imageURL to Firestore data: \(imageURL)")
        } else {
            print("💾 EntryStore: ⚠️ No imageURL to add to Firestore")
        }
        
        print("💾 EntryStore: Firestore document data keys: \(entryData.keys)")
        
        // Save to Firestore
        db.collection("groups")
            .document(groupId)
            .collection("entries")
            .document(entry.id)
            .setData(entryData) { [weak self] error in
                if let error = error {
                    print("❌ EntryStore: Error saving entry to Firestore: \(error.localizedDescription)")
                    // Fallback to local storage
                    DispatchQueue.main.async {
                        self?.entries.insert(entry, at: 0)
                        self?.saveEntriesToLocal()
                    }
                } else {
                    print("✅ EntryStore: Successfully saved entry to Firestore")
                    print("✅ EntryStore: Entry ID \(entry.id) saved with imageURL: \(entry.imageURL ?? "nil")")
                    // The listener will automatically update the local entries array
                    
                    print("🔔 === ABOUT TO TRIGGER NOTIFICATIONS ===")
                    print("🔔 Entry saved successfully, now sending notifications to other members")
                    print("🔔 Entry prompt: '\(entry.prompt)'")
                    print("🔔 Entry user: \(entry.userId)")
                    print("🔔 Entry imageURL: \(entry.imageURL ?? "nil")")
                    print("🔔 Current time: \(Date())")
                    
                    // CRITICAL DEBUG: Check user IDs before sending notifications
                    let entryUserId = entry.userId
                    let currentAuthUserId = Auth.auth().currentUser?.uid
                    print("🧪 NOTIFICATION DEBUG:")
                    print("🧪 Entry.userId: \(entryUserId)")
                    print("🧪 Auth.currentUser?.uid: \(currentAuthUserId ?? "nil")")
                    print("🧪 Are they the same? \(entryUserId == currentAuthUserId)")
                    
                    // CRITICAL: Add immediate verification that this method is called
                    print("🚨 CRITICAL: addEntry notification block IS BEING EXECUTED")
                    print("🚨 CRITICAL: About to call getUserName for: \(entry.userId)")
                    
                    // Send upload notification to group members
                    self?.getUserName(for: entry.userId) { uploaderName in
                        print("🧪 NOTIFICATION DEBUG: Got uploader name: \(uploaderName)")
                        print("🚨 CRITICAL: getUserName callback executed successfully")
                        
                        // CRITICAL: Validate that this is actually an influencer posting
                        guard let currentUserId = Auth.auth().currentUser?.uid else {
                            print("🧪 ❌ No current user for notification validation")
                            return
                        }
                        
                        if entry.userId != currentUserId {
                            print("🧪 ⚠️ WARNING: Entry user ID (\(entry.userId)) doesn't match current user (\(currentUserId))")
                            print("🧪 ⚠️ This could indicate a sync issue - proceeding with entry.userId")
                        }
                        
                        print("🚨 CRITICAL: About to call getGroupMembers")
                        self?.getGroupMembers { groupMembers in
                            print("🧪 NOTIFICATION DEBUG: Got \(groupMembers.count) group members before sending notification")
                            print("🚨 CRITICAL: getGroupMembers callback executed with \(groupMembers.count) members")
                            
                            // CRITICAL: Double-check that we have other members to notify
                            if groupMembers.isEmpty {
                                print("🧪 ⚠️ WARNING: No other group members found - notifications will not be sent")
                                print("🧪 ⚠️ This could mean:")
                                print("🧪 ⚠️ 1. User is the only member in the group")
                                print("🧪 ⚠️ 2. getGroupMembers is not working correctly")
                                print("🧪 ⚠️ 3. Group data structure has changed")
                            } else {
                                print("🧪 ✅ Will send notifications to \(groupMembers.count) other members")
                                for (index, memberId) in groupMembers.enumerated() {
                                    print("🧪 ✅ [\(index + 1)] Member to notify: \(memberId)")
                                }
                            }
                            
                            print("🚨 CRITICAL: About to call sendDIMLUploadNotification")
                            self?.sendDIMLUploadNotification(uploaderName: uploaderName, prompt: entry.prompt, groupMembers: groupMembers)
                            
                            // Schedule next prompt unlock notification for the influencer
                            self?.scheduleNextPromptUnlockNotification()
                        }
                    }
                }
            }
    }
    
    func updateEntry(_ entry: DIMLEntry) {
        print("🔄 EntryStore: Updating entry \(entry.id) in Firestore")
        
        // Prepare entry data for Firestore
        var entryData: [String: Any] = [
            "userId": entry.userId,
            "prompt": entry.prompt,
            "response": entry.response,
            "timestamp": Timestamp(date: entry.timestamp),
            "frameSize": entry.frameSize.rawValue,
            "reactions": entry.reactions,
            "promptType": entry.promptType.rawValue,
            "userReactions": entry.userReactions.map { reaction in
                [
                    "id": reaction.id,
                    "userId": reaction.userId,
                    "emoji": reaction.emoji,
                    "timestamp": Timestamp(date: reaction.timestamp)
                ]
            },
            "comments": entry.comments.map { comment in
                var commentData: [String: Any] = [
                    "id": comment.id,
                    "userId": comment.userId,
                    "text": comment.text,
                    "timestamp": Timestamp(date: comment.timestamp)
                ]
                
                // Add image data if present
                if let imageData = comment.imageData {
                    commentData["imageData"] = imageData.base64EncodedString()
                }
                
                if let imageURL = comment.imageURL {
                    commentData["imageURL"] = imageURL
                }
                
                return commentData
            }
        ]
        
        // Add imageURL if it exists
        if let imageURL = entry.imageURL {
            entryData["imageURL"] = imageURL
        }
        
        // Update in Firestore
        db.collection("groups")
            .document(groupId)
            .collection("entries")
            .document(entry.id)
            .setData(entryData) { [weak self] error in
                if let error = error {
                    print("❌ EntryStore: Error updating entry in Firestore: \(error.localizedDescription)")
                    // Fallback to local update
                    if let index = self?.entries.firstIndex(where: { $0.id == entry.id }) {
                        DispatchQueue.main.async {
                            self?.entries[index] = entry
                            self?.saveEntriesToLocal()
                        }
                    }
                } else {
                    print("✅ EntryStore: Successfully updated entry in Firestore")
                    // The listener will automatically update the local entries array
                }
            }
    }
    
    func addComment(to entryId: String, comment: Comment) {
        print("💬 EntryStore: Adding comment to entry \(entryId) in Firestore")
        print("💬 EntryStore: Comment text: \(comment.text)")
        print("💬 EntryStore: Comment user: \(comment.userId)")
        print("💬 EntryStore: Comment has imageData: \(comment.imageData != nil)")
        print("💬 EntryStore: Comment has imageURL: \(comment.imageURL != nil)")
        if let imageURL = comment.imageURL {
            print("💬 EntryStore: Comment imageURL: \(imageURL)")
        }
        
        // First, get the current entry from Firestore
        db.collection("groups")
            .document(groupId)
            .collection("entries")
            .document(entryId)
            .getDocument { [weak self] document, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ EntryStore: Error fetching entry for comment: \(error.localizedDescription)")
                    return
                }
                
                guard let document = document, document.exists, let data = document.data() else {
                    print("❌ EntryStore: Entry not found for comment")
                    return
                }
                
                // Get existing comments
                var existingComments = data["comments"] as? [[String: Any]] ?? []
                
                // Add new comment
                var newCommentData: [String: Any] = [
                    "id": comment.id,
                    "userId": comment.userId,
                    "text": comment.text,
                    "timestamp": Timestamp(date: comment.timestamp)
                ]
                
                // Add image data if present
                if let imageData = comment.imageData {
                    // Convert Data to base64 string for Firestore storage
                    let base64String = imageData.base64EncodedString()
                    newCommentData["imageData"] = base64String
                    print("💬 EntryStore: Added imageData to comment (base64 length: \(base64String.count))")
                }
                
                if let imageURL = comment.imageURL {
                    newCommentData["imageURL"] = imageURL
                    print("💬 EntryStore: Added imageURL to comment: \(imageURL)")
                }
                
                existingComments.append(newCommentData)
                
                // Update the entry with new comments
                self.db.collection("groups")
                    .document(self.groupId)
                    .collection("entries")
                    .document(entryId)
                    .updateData(["comments": existingComments]) { error in
                        if let error = error {
                            print("❌ EntryStore: Error adding comment to Firestore: \(error.localizedDescription)")
                        } else {
                            print("✅ EntryStore: Successfully added comment to Firestore for group \(self.groupId)")
                            print("📨 EntryStore: Comment should now be visible to all \(existingComments.count) total comments")
                            print("📨 EntryStore: Picture comment sync - All group members will see this image!")
                            // The listener will automatically update the local entries array
                            
                            // Send comment notification to entry owner
                            let entryOwnerId = data["userId"] as? String ?? ""
                            let entryPrompt = data["prompt"] as? String ?? "your post"
                            
                            self.getUserName(for: comment.userId) { commenterName in
                                self.sendCommentNotification(commenterName: commenterName, commentText: comment.text, entryOwnerId: entryOwnerId, prompt: entryPrompt)
                            }
                        }
                    }
            }
    }
    
    func addReaction(to entryId: String, reaction: String) {
        print("💬 EntryStore: Adding/updating reaction \(reaction) for current user to entry \(entryId)")
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ EntryStore: No current user ID for reaction")
            return
        }
        
        // Get the current entry from Firestore
        db.collection("groups")
            .document(groupId)
            .collection("entries")
            .document(entryId)
            .getDocument { [weak self] document, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ EntryStore: Error fetching entry for reaction: \(error.localizedDescription)")
                    return
                }
                
                guard let document = document, document.exists, let data = document.data() else {
                    print("❌ EntryStore: Entry not found for reaction")
                    return
                }
                
                // Get existing user reactions
                var existingUserReactions: [UserReaction] = []
                if let userReactionsData = data["userReactions"] as? [[String: Any]] {
                    existingUserReactions = userReactionsData.compactMap { reactionData -> UserReaction? in
                        guard let id = reactionData["id"] as? String,
                              let userId = reactionData["userId"] as? String,
                              let emoji = reactionData["emoji"] as? String else {
                            return nil
                        }
                        
                        let reactionTimestamp: Date
                        if let firestoreTimestamp = reactionData["timestamp"] as? Timestamp {
                            reactionTimestamp = firestoreTimestamp.dateValue()
                        } else {
                            reactionTimestamp = Date()
                        }
                        
                        return UserReaction(
                            id: id,
                            userId: userId,
                            emoji: emoji,
                            timestamp: reactionTimestamp
                        )
                    }
                }
                
                // Remove any existing reaction from this user
                existingUserReactions.removeAll { $0.userId == currentUserId }
                
                // Add the new reaction
                let newReaction = UserReaction(
                    userId: currentUserId,
                    emoji: reaction
                )
                existingUserReactions.append(newReaction)
                
                print("💬 EntryStore: User \(currentUserId) reaction updated to \(reaction)")
                print("💬 EntryStore: Total reactions now: \(existingUserReactions.count)")
                
                // Convert back to Firestore format
                let userReactionsData = existingUserReactions.map { reaction in
                    [
                        "id": reaction.id,
                        "userId": reaction.userId,
                        "emoji": reaction.emoji,
                        "timestamp": Timestamp(date: reaction.timestamp)
                    ]
                }
                
                // Also update legacy reactions format for backwards compatibility
                var legacyReactions: [String: Int] = [:]
                for userReaction in existingUserReactions {
                    legacyReactions[userReaction.emoji, default: 0] += 1
                }
                
                // Update the entry with new reactions
                self.db.collection("groups")
                    .document(self.groupId)
                    .collection("entries")
                    .document(entryId)
                    .updateData([
                        "userReactions": userReactionsData,
                        "reactions": legacyReactions // Keep legacy format for compatibility
                    ]) { error in
                        if let error = error {
                            print("❌ EntryStore: Error updating reaction in Firestore: \(error.localizedDescription)")
                        } else {
                            print("✅ EntryStore: Successfully updated user reaction in Firestore for group \(self.groupId)")
                            print("🎉 EntryStore: Reaction \(reaction) should now be visible to all group members")
                            print("📊 EntryStore: Total reactions for this entry: \(existingUserReactions.count)")
                            print("📋 EntryStore: All reactions for entry \(entryId):")
                            for userReaction in existingUserReactions {
                                print("   - \(userReaction.emoji) by \(userReaction.userId)")
                            }
                            print("🔄 EntryStore: Firestore update complete - listener should trigger update")
                            // The listener will automatically update the local entries array
                            
                            // Send reaction notification to entry owner
                            let entryOwnerId = data["userId"] as? String ?? ""
                            let entryPrompt = data["prompt"] as? String ?? "your post"
                            
                            self.getUserName(for: currentUserId) { reactorName in
                                self.sendReactionNotification(reactorName: reactorName, reaction: reaction, entryOwnerId: entryOwnerId, prompt: entryPrompt)
                            }
                        }
                    }
            }
    }
    
    // Helper method to get entries for a specific user
    func getEntries(for userId: String) -> [DIMLEntry] {
        return entries.filter { $0.userId == userId }
    }
    
    // Helper method to get entries for a specific prompt
    func getEntries(forPrompt prompt: String) -> [DIMLEntry] {
        return entries.filter { $0.prompt == prompt }
    }
    
    // MARK: - Persistence Methods
    
    private func saveEntries() {
        print("💾 EntryStore: Saving \(entries.count) entries for group \(groupId)")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            // Convert entries to a codable format - use imageURL instead of imageData
            let codableEntries = entries.map { entry in
                print("💾 EntryStore: Converting entry \(entry.id) with imageURL: \(entry.imageURL ?? "nil")")
                let codableEntry = CodableDIMLEntry(
                    id: entry.id,
                    userId: entry.userId,
                    prompt: entry.prompt,
                    response: entry.response,
                    imageData: nil, // Don't save image data locally
                    imageURL: entry.imageURL, // Use Firebase Storage URL
                    timestamp: entry.timestamp,
                    comments: entry.comments,
                    reactions: entry.reactions,
                    userReactions: entry.userReactions,
                    frameSize: entry.frameSize,
                    promptType: entry.promptType
                )
                print("💾 EntryStore: Created CodableDIMLEntry with imageURL: \(codableEntry.imageURL ?? "nil")")
                return codableEntry
            }
            
            let data = try encoder.encode(codableEntries)
            UserDefaults.standard.set(data, forKey: storageKey)
            print("💾 EntryStore: Successfully saved \(entries.count) entries for group \(groupId)")
            print("💾 EntryStore: Data size: \(data.count) bytes")
        } catch {
            print("💾 EntryStore: Failed to save entries: \(error)")
        }
    }
    
    private func loadEntries() {
        print("💾 EntryStore: Loading entries for group \(groupId)")
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            print("💾 EntryStore: No saved entries found for group \(groupId)")
            return
        }
        
        print("💾 EntryStore: Found saved data, size: \(data.count) bytes")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let codableEntries = try decoder.decode([CodableDIMLEntry].self, from: data)
            print("💾 EntryStore: Decoded \(codableEntries.count) entries from storage")
            
            // Print details of what was decoded
            for (index, codableEntry) in codableEntries.enumerated() {
                print("💾 EntryStore: Decoded entry \(index): ID=\(codableEntry.id), imageURL=\(codableEntry.imageURL ?? "nil")")
            }
            
            // Convert back to DIMLEntry - use imageURL instead of local image
            entries = codableEntries.map { codableEntry in
                print("💾 EntryStore: Converting CodableDIMLEntry \(codableEntry.id) with imageURL: \(codableEntry.imageURL ?? "nil")")
                let dimlEntry = DIMLEntry(
                    id: codableEntry.id,
                    userId: codableEntry.userId,
                    prompt: codableEntry.prompt,
                    response: codableEntry.response,
                    image: nil, // Don't load local images
                    imageURL: codableEntry.imageURL, // Use Firebase Storage URL
                    timestamp: codableEntry.timestamp,
                    comments: codableEntry.comments,
                    reactions: codableEntry.reactions,
                    userReactions: codableEntry.userReactions,
                    frameSize: codableEntry.frameSize,
                    promptType: codableEntry.promptType
                )
                print("💾 EntryStore: Created DIMLEntry \(dimlEntry.id) with imageURL: \(dimlEntry.imageURL ?? "nil")")
                return dimlEntry
            }
            
            print("💾 EntryStore: Successfully loaded \(entries.count) entries for group \(groupId)")
            // Print first few entries for debugging
            for (index, entry) in entries.prefix(3).enumerated() {
                print("💾 EntryStore: Final entry \(index): ID=\(entry.id), imageURL=\(entry.imageURL ?? "nil")")
            }
        } catch {
            print("💾 EntryStore: Failed to load entries: \(error)")
            entries = []
        }
    }
    
    // Method to clear all entries (useful for testing)
    func clearAllEntries() {
        print("🧹 EntryStore: Clearing all entries from Firestore for group \(groupId)")
        
        // Clear from Firestore
        db.collection("groups")
            .document(groupId)
            .collection("entries")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ EntryStore: Error fetching entries to clear: \(error.localizedDescription)")
                    // Fallback to local clear
                    DispatchQueue.main.async {
                        self.entries = []
                        UserDefaults.standard.removeObject(forKey: self.storageKey)
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("📭 EntryStore: No entries to clear")
                    return
                }
                
                // Delete each entry document
                let batch = self.db.batch()
                for document in documents {
                    batch.deleteDocument(document.reference)
                }
                
                batch.commit { error in
                    if let error = error {
                        print("❌ EntryStore: Error clearing entries from Firestore: \(error.localizedDescription)")
                    } else {
                        print("✅ EntryStore: Successfully cleared all entries from Firestore")
                        // The listener will automatically update the local entries array
                    }
                }
            }
    }
    
    // Method to delete a specific entry
    func deleteEntry(_ entry: DIMLEntry) {
        print("🗑️ EntryStore: Deleting entry \(entry.id) from Firestore")
        
        db.collection("groups")
            .document(groupId)
            .collection("entries")
            .document(entry.id)
            .delete { [weak self] error in
                if let error = error {
                    print("❌ EntryStore: Error deleting entry from Firestore: \(error.localizedDescription)")
                    // Fallback to local deletion
                    DispatchQueue.main.async {
                        self?.entries.removeAll { $0.id == entry.id }
                        self?.saveEntriesToLocal()
                    }
                } else {
                    print("✅ EntryStore: Successfully deleted entry from Firestore")
                    // The listener will automatically update the local entries array
                }
            }
    }
    
    // Method to force reload entries from Firestore
    func reloadEntries() {
        print("🔄 EntryStore: Manually reloading entries from Firestore for group \(groupId)")
        setupEntriesListener()
    }
    
    // Method to force refresh without recreating listener
    func refreshEntries() {
        print("🔄 EntryStore: Force refreshing entries for group \(groupId)")
        
        // Make a direct query to get latest data
        db.collection("groups")
            .document(groupId)
            .collection("entries")
            .order(by: "timestamp", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ EntryStore: Error force refreshing entries: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("📭 EntryStore: No entries found during force refresh")
                    return
                }
                
                print("🔄 EntryStore: Force refresh found \(documents.count) entries")
                
                let entries = documents.compactMap { document -> DIMLEntry? in
                    let data = document.data()
                    
                    guard let userId = data["userId"] as? String,
                          let prompt = data["prompt"] as? String,
                          let response = data["response"] as? String else {
                        return nil
                    }
                    
                    // Handle timestamp
                    let timestamp: Date
                    if let firestoreTimestamp = data["timestamp"] as? Timestamp {
                        timestamp = firestoreTimestamp.dateValue()
                    } else {
                        timestamp = Date()
                    }
                    
                    // Handle comments
                    let comments: [Comment]
                    if let commentsData = data["comments"] as? [[String: Any]] {
                        comments = commentsData.compactMap { commentData -> Comment? in
                            guard let commentId = commentData["id"] as? String,
                                  let commentUserId = commentData["userId"] as? String,
                                  let commentText = commentData["text"] as? String else {
                                return nil
                            }
                            
                            let commentTimestamp: Date
                            if let commentFirestoreTimestamp = commentData["timestamp"] as? Timestamp {
                                commentTimestamp = commentFirestoreTimestamp.dateValue()
                            } else {
                                commentTimestamp = Date()
                            }
                            
                            var imageData: Data?
                            if let imageDataString = commentData["imageData"] as? String {
                                imageData = Data(base64Encoded: imageDataString)
                            }
                            
                            let imageURL = commentData["imageURL"] as? String
                            
                            return Comment(
                                id: commentId,
                                userId: commentUserId,
                                text: commentText,
                                timestamp: commentTimestamp,
                                imageData: imageData,
                                imageURL: imageURL
                            )
                        }
                    } else {
                        comments = []
                    }
                    
                    // Handle reactions
                    let userReactions: [UserReaction]
                    if let userReactionsData = data["userReactions"] as? [[String: Any]] {
                        userReactions = userReactionsData.compactMap { reactionData -> UserReaction? in
                            guard let id = reactionData["id"] as? String,
                                  let userId = reactionData["userId"] as? String,
                                  let emoji = reactionData["emoji"] as? String else {
                                return nil
                            }
                            
                            let reactionTimestamp: Date
                            if let firestoreTimestamp = reactionData["timestamp"] as? Timestamp {
                                reactionTimestamp = firestoreTimestamp.dateValue()
                            } else {
                                reactionTimestamp = Date()
                            }
                            
                            return UserReaction(
                                id: id,
                                userId: userId,
                                emoji: emoji,
                                timestamp: reactionTimestamp
                            )
                        }
                    } else {
                        userReactions = []
                    }
                    
                    let reactions = data["reactions"] as? [String: Int] ?? [:]
                    let frameSizeRaw = data["frameSize"] as? String ?? "medium"
                    let frameSize = FrameSize(rawValue: frameSizeRaw) ?? .medium
                    
                    let promptTypeRaw = data["promptType"] as? String ?? "image"
                    let promptType = PromptType(rawValue: promptTypeRaw) ?? .image
                    
                    let entry = DIMLEntry(
                        id: document.documentID,
                        userId: userId,
                        prompt: prompt,
                        response: response,
                        image: nil,
                        imageURL: data["imageURL"] as? String,
                        timestamp: timestamp,
                        comments: comments,
                        reactions: reactions,
                        userReactions: userReactions,
                        frameSize: frameSize,
                        promptType: promptType
                    )
                    
                    // Debug each entry's reactions
                    print("📊 Force refresh - Entry \(entry.id): \(entry.userReactions.count) reactions, \(entry.comments.count) comments")
                    if !entry.userReactions.isEmpty {
                        for reaction in entry.userReactions {
                            print("   🎉 Reaction: \(reaction.emoji) by user \(reaction.userId)")
                        }
                    }
                    
                    return entry
                }
                
                DispatchQueue.main.async {
                    self.entries = entries
                    print("✅ EntryStore: Force refresh completed with \(entries.count) entries")
                }
            }
    }
    
    // Debug method to check raw Firestore data
    func debugCheckFirestoreReactions(for entryId: String) {
        print("🐛 DEBUG: Checking raw Firestore data for entry \(entryId)")
        
        db.collection("groups")
            .document(groupId)
            .collection("entries")
            .document(entryId)
            .getDocument { document, error in
                if let error = error {
                    print("🐛 DEBUG: Error fetching entry: \(error.localizedDescription)")
                    return
                }
                
                guard let document = document, document.exists, let data = document.data() else {
                    print("🐛 DEBUG: Entry not found or no data")
                    return
                }
                
                print("🐛 DEBUG: Raw Firestore data for \(entryId):")
                if let userReactionsData = data["userReactions"] as? [[String: Any]] {
                    print("🐛 DEBUG: userReactions array has \(userReactionsData.count) items:")
                    for (index, reactionData) in userReactionsData.enumerated() {
                        print("🐛 DEBUG:   [\(index)] \(reactionData)")
                    }
                } else {
                    print("🐛 DEBUG: No userReactions field found")
                }
                
                if let legacyReactions = data["reactions"] as? [String: Int] {
                    print("🐛 DEBUG: Legacy reactions: \(legacyReactions)")
                } else {
                    print("🐛 DEBUG: No legacy reactions field found")
                }
            }
    }
    
    // Force sync all reactions from server (bypassing cache)
    func forceSyncReactions() {
        print("🔄 EntryStore: Force syncing reactions from server...")
        
        // Get fresh data from server only (no cache)
        db.collection("groups")
            .document(groupId)
            .collection("entries")
            .order(by: "timestamp", descending: true)
            .getDocuments(source: .server) { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ EntryStore: Error force syncing reactions: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("❌ EntryStore: No snapshot in force sync")
                    return
                }
                
                print("🌟 EntryStore: Force sync got \(snapshot.documents.count) entries from SERVER")
                
                let entries = snapshot.documents.compactMap { document -> DIMLEntry? in
                    let data = document.data()
                    
                    guard let userId = data["userId"] as? String,
                          let prompt = data["prompt"] as? String,
                          let response = data["response"] as? String else {
                        return nil
                    }
                    
                    let timestamp: Date
                    if let firestoreTimestamp = data["timestamp"] as? Timestamp {
                        timestamp = firestoreTimestamp.dateValue()
                    } else {
                        timestamp = Date()
                    }
                    
                    let comments: [Comment]
                    if let commentsData = data["comments"] as? [[String: Any]] {
                        comments = commentsData.compactMap { commentData -> Comment? in
                            guard let commentId = commentData["id"] as? String,
                                  let commentUserId = commentData["userId"] as? String,
                                  let commentText = commentData["text"] as? String else {
                                return nil
                            }
                            
                            let commentTimestamp: Date
                            if let commentFirestoreTimestamp = commentData["timestamp"] as? Timestamp {
                                commentTimestamp = commentFirestoreTimestamp.dateValue()
                            } else {
                                commentTimestamp = Date()
                            }
                            
                            var imageData: Data?
                            if let imageDataString = commentData["imageData"] as? String {
                                imageData = Data(base64Encoded: imageDataString)
                            }
                            
                            let imageURL = commentData["imageURL"] as? String
                            
                            return Comment(
                                id: commentId,
                                userId: commentUserId,
                                text: commentText,
                                timestamp: commentTimestamp,
                                imageData: imageData,
                                imageURL: imageURL
                            )
                        }
                    } else {
                        comments = []
                    }
                    
                    // Handle reactions
                    let userReactions: [UserReaction]
                    if let userReactionsData = data["userReactions"] as? [[String: Any]] {
                        userReactions = userReactionsData.compactMap { reactionData -> UserReaction? in
                            guard let id = reactionData["id"] as? String,
                                  let userId = reactionData["userId"] as? String,
                                  let emoji = reactionData["emoji"] as? String else {
                                return nil
                            }
                            
                            let reactionTimestamp: Date
                            if let firestoreTimestamp = reactionData["timestamp"] as? Timestamp {
                                reactionTimestamp = firestoreTimestamp.dateValue()
                            } else {
                                reactionTimestamp = Date()
                            }
                            
                            return UserReaction(
                                id: id,
                                userId: userId,
                                emoji: emoji,
                                timestamp: reactionTimestamp
                            )
                        }
                    } else {
                        userReactions = []
                    }
                    
                    let reactions = data["reactions"] as? [String: Int] ?? [:]
                    let frameSizeRaw = data["frameSize"] as? String ?? "medium"
                    let frameSize = FrameSize(rawValue: frameSizeRaw) ?? .medium
                    
                    let promptTypeRaw = data["promptType"] as? String ?? "image"
                    let promptType = PromptType(rawValue: promptTypeRaw) ?? .image
                    
                    let entry = DIMLEntry(
                        id: document.documentID,
                        userId: userId,
                        prompt: prompt,
                        response: response,
                        image: nil,
                        imageURL: data["imageURL"] as? String,
                        timestamp: timestamp,
                        comments: comments,
                        reactions: reactions,
                        userReactions: userReactions,
                        frameSize: frameSize,
                        promptType: promptType
                    )
                    
                    // Debug each entry's reactions
                    print("📊 Force sync - Entry \(entry.id): \(entry.userReactions.count) reactions, \(entry.comments.count) comments")
                    if !entry.userReactions.isEmpty {
                        for reaction in entry.userReactions {
                            print("   🎉 Reaction: \(reaction.emoji) by user \(reaction.userId)")
                        }
                    }
                    
                    return entry
                }
                
                DispatchQueue.main.async {
                    self.entries = entries
                    print("✅ EntryStore: Force sync completed with \(entries.count) entries")
                }
            }
    }
    
    // Check current user's authentication and group access
    func debugUserAuth() {
        if let currentUser = Auth.auth().currentUser {
            print("🔐 DEBUG: Current user ID: \(currentUser.uid)")
            print("🔐 DEBUG: Current user email: \(currentUser.email ?? "no email")")
            print("🔐 DEBUG: Group ID: \(groupId)")
            
            // Check if user is member of this group
            db.collection("groups").document(groupId).getDocument { document, error in
                if let error = error {
                    print("🔐 DEBUG: Error fetching group: \(error.localizedDescription)")
                    return
                }
                
                guard let document = document, document.exists, let data = document.data() else {
                    print("🔐 DEBUG: Group not found")
                    return
                }
                
                if let memberIds = data["memberIds"] as? [String] {
                    let isMember = memberIds.contains(currentUser.uid)
                    print("🔐 DEBUG: User is member of group: \(isMember)")
                    print("🔐 DEBUG: Group members: \(memberIds)")
                } else {
                    print("🔐 DEBUG: No memberIds field found in group")
                }
            }
        } else {
            print("🔐 DEBUG: No authenticated user")
        }
    }
    
    private func saveEntriesToLocal() {
        print("💾 EntryStore: Saving \(entries.count) entries to local storage")
        saveEntries()
    }
    
    private func loadEntriesFromLocal() {
        print("💾 EntryStore: Loading entries from local storage")
        loadEntries()
    }
    
    // MARK: - Notification Methods
    
    private func sendDIMLUploadNotification(uploaderName: String, prompt: String, groupMembers: [String]) {
        print("📱 EntryStore: === SENDING DIML UPLOAD NOTIFICATION ===")
        print("📱 🚨 CRITICAL: sendDIMLUploadNotification WAS CALLED!")
        print("📱 Uploader: \(uploaderName)")
        print("📱 Prompt: \(prompt)")
        print("📱 Group members received: \(groupMembers.count)")
        print("📱 Group members list:")
        for (index, member) in groupMembers.enumerated() {
            print("📱 [\(index + 1)] Member ID: \(member)")
        }
        print("📱 🚨 Function called at: \(Date())")
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("📱 ❌ No current user for upload notification")
            return
        }
        
        print("📱 Current uploader user ID: \(currentUserId)")
        
        // CRITICAL: The groupMembers should already be filtered by getGroupMembers, 
        // but we double-check here to ensure the uploader never gets notified
        let membersToNotify = groupMembers.filter { memberId in
            let shouldNotify = memberId != currentUserId
            if !shouldNotify {
                print("📱 ⚠️ PREVENTED: Almost notified the uploader themselves! (ID: \(memberId))")
            }
            return shouldNotify
        }
        
        print("📱 After filtering out uploader: \(membersToNotify.count) members to notify")
        print("📱 Members to notify:")
        for (index, member) in membersToNotify.enumerated() {
            print("📱 🔔 [\(index + 1)] Will notify: \(member)")
        }
        
        // FINAL VALIDATION: Ensure the uploader is NOT in the notification list
        if membersToNotify.contains(currentUserId) {
            print("📱 🚨 CRITICAL ERROR: Uploader is still in notification list! This should never happen!")
            print("📱 🚨 Uploader ID: \(currentUserId)")
            print("📱 🚨 Members to notify: \(membersToNotify)")
            return // Abort to prevent self-notification
        }
        
        // Check for duplicates in members to notify
        let uniqueMembersToNotify = Set(membersToNotify)
        if membersToNotify.count != uniqueMembersToNotify.count {
            print("📱 ⚠️ DUPLICATE NOTIFICATION TARGETS DETECTED!")
            print("📱 ⚠️ Total targets: \(membersToNotify.count), Unique targets: \(uniqueMembersToNotify.count)")
            print("📱 ⚠️ This will cause duplicate notifications!")
        }
        
        // CRITICAL: If no other members to notify, don't send any notifications
        guard !membersToNotify.isEmpty else {
            print("📱 ℹ️ No other members to notify - user is the only member or filtering failed")
            return
        }
        
        // CRITICAL FIX: Only send FCM push notifications (device-specific)
        // DO NOT send local notifications as they appear on the current device regardless of target user
        print("📱 🚀 === SENDING ONLY FCM PUSH NOTIFICATIONS ===")
        print("📱 🚀 FCM notifications will go to \(membersToNotify.count) specific circle members' devices")
        print("📱 🚀 Local notifications REMOVED to prevent uploader seeing their own notifications")
        
        // Send FCM push notifications using the same pattern as reactions
        print("📱 🚀 Sending FCM push notifications via Cloud Function...")
        print("📱 🚀 FCM notifications will be sent to: \(membersToNotify)")
        sendUploadNotificationsToMembers(
            memberIds: membersToNotify,
            uploaderName: uploaderName,
            prompt: prompt
        )
        
        print("📱 === UPLOAD NOTIFICATION SENDING COMPLETE ===")
    }
    
    private func sendUploadNotificationsToMembers(memberIds: [String], uploaderName: String, prompt: String) {
        print("📱 Sending upload notifications to \(memberIds.count) circle members...")
        print("📱 🚨 CRITICAL: sendUploadNotificationsToMembers WAS CALLED!")
        print("📱 🚨 Member IDs to notify: \(memberIds)")
        print("📱 🚨 Uploader: \(uploaderName)")
        print("📱 🚨 Prompt: \(prompt)")
        
        for (index, memberId) in memberIds.enumerated() {
            print("📱 🚨 [\(index + 1)] Processing member: \(memberId)")
            
            // Get member's FCM token and send notification
            db.collection("users").document(memberId).getDocument { [weak self] userDoc, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("📱 ❌ Error getting member \(memberId) for upload notification: \(error.localizedDescription)")
                    return
                }
                
                guard let userDoc = userDoc, userDoc.exists, let userData = userDoc.data() else {
                    print("📱 ❌ Member \(memberId) not found for upload notification")
                    return
                }
                
                guard let fcmToken = userData["fcmToken"] as? String else {
                    print("📱 ⚠️ No FCM token found for member \(memberId)")
                    return
                }
                
                // Send FCM notification to this member using notificationRequests pattern
                self.sendUploadFCMNotification(
                    token: fcmToken,
                    uploaderName: uploaderName,
                    targetUserId: memberId,
                    prompt: prompt
                )
            }
        }
    }
    
    private func sendUploadFCMNotification(token: String, uploaderName: String, targetUserId: String, prompt: String) {
        print("📱 🚨 === UPLOAD FCM NOTIFICATION DEBUG ===")
        print("📱 🚨 Token (last 8): \(String(token.suffix(8)))")
        print("📱 🚨 Uploader: \(uploaderName)")
        print("📱 🚨 Target User: \(targetUserId)")
        print("📱 🚨 Current User: \(Auth.auth().currentUser?.uid ?? "nil")")
        print("📱 🚨 Group ID: \(groupId)")
        print("📱 🚨 Prompt: \(prompt)")
        
        // CRITICAL: Verify we're not sending to the uploader
        if targetUserId == Auth.auth().currentUser?.uid {
            print("📱 🚨 ❌ ABORTING: Target user is the uploader!")
            return
        }
        
        // Create notification request for Cloud Function
        let notificationRequest: [String: Any] = [
            "fcmToken": token,
            "title": "📷 New DIML Upload!",
            "body": "\(uploaderName) just shared their day in your circle",
            "data": [
                "type": "diml_upload",
                "groupId": groupId,
                "uploaderName": uploaderName,
                "targetUserId": targetUserId,
                "prompt": prompt
            ],
            "timestamp": FieldValue.serverTimestamp(),
            "processed": false,
            "targetUserId": targetUserId,
            "notificationType": "diml_upload"
        ]
        
        print("📱 🚨 Notification request data:")
        for (key, value) in notificationRequest {
            if key != "timestamp" {
                print("📱 🚨   \(key): \(value)")
            }
        }
        
        print("📱 🚨 About to add notification request to Firestore...")
        print("📱 🚨 Request data: \(notificationRequest)")
        
        db.collection("notificationRequests").addDocument(data: notificationRequest) { error in
            if let error = error {
                print("❌ Error queuing DIML upload notification: \(error.localizedDescription)")
                print("❌ 🚨 CRITICAL ERROR: \(error)")
            } else {
                print("✅ DIML upload notification queued via Cloud Function for member \(targetUserId)")
                print("✅ 🚨 CRITICAL SUCCESS: Notification request successfully added to Firestore!")
                
                // Add follow-up verification
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    print("📱 🚨 FOLLOW-UP: Checking if notification was processed...")
                    // You can manually check Firestore console to see if the document was created
                }
            }
        }
    }
    
    // Manual function to test upload notifications (for debugging)
    func testUploadNotification() {
        print("🧪 🚀 === TESTING UPLOAD NOTIFICATION ===")
        
        getUserName(for: Auth.auth().currentUser?.uid ?? "") { [weak self] uploaderName in
            guard let self = self else { return }
            
            print("🧪 🚀 Testing with uploader name: \(uploaderName)")
            
            self.getGroupMembers { groupMembers in
                print("🧪 🚀 Testing notification to \(groupMembers.count) group members")
                
                self.sendDIMLUploadNotification(
                    uploaderName: uploaderName,
                    prompt: "Test notification prompt",
                    groupMembers: groupMembers
                )
            }
        }
    }
    
    private func sendReactionNotification(reactorName: String, reaction: String, entryOwnerId: String, prompt: String) {
        print("📱 EntryStore: === SENDING REACTION NOTIFICATION ===")
        print("📱 Reactor: \(reactorName)")
        print("📱 Reaction: \(reaction)")
        print("📱 Entry owner: \(entryOwnerId)")
        print("📱 Prompt: \(prompt)")
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("📱 ❌ No current user for reaction notification")
            return
        }
        
        print("📱 Current reactor user ID: \(currentUserId)")
        
        // Use the improved getGroupMembers method that already excludes current user
        getGroupMembers { [weak self] otherMemberIds in
            guard let self = self else { return }
            
            print("📱 📋 Reaction notification: Found \(otherMemberIds.count) other circle members to notify")
            
            if otherMemberIds.isEmpty {
                print("📱 ℹ️ No other members to notify about reaction")
                return
            }
            
            // Send FCM notifications to all other circle members (already excludes reactor)
            print("📱 🚀 Sending reaction FCM notifications to \(otherMemberIds.count) other members")
            self.sendReactionNotificationsToMembers(
                memberIds: otherMemberIds,
                reactorName: reactorName,
                reaction: reaction,
                entryOwnerId: entryOwnerId,
                prompt: prompt
            )
        }
    }
    
    private func sendReactionNotificationsToMembers(memberIds: [String], reactorName: String, reaction: String, entryOwnerId: String, prompt: String) {
        print("📱 Sending reaction notifications to \(memberIds.count) circle members...")
        
        for memberId in memberIds {
            print("📱 Sending reaction notification to member: \(memberId)")
            
            // Get member's FCM token and send notification
            db.collection("users").document(memberId).getDocument { [weak self] userDoc, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("📱 ❌ Error getting member \(memberId) for reaction notification: \(error.localizedDescription)")
                    return
                }
                
                guard let userDoc = userDoc, userDoc.exists, let userData = userDoc.data() else {
                    print("📱 ❌ Member \(memberId) not found for reaction notification")
                    return
                }
                
                guard let fcmToken = userData["fcmToken"] as? String else {
                    print("📱 ⚠️ No FCM token found for member \(memberId)")
                    return
                }
                
                print("📱 ✅ Found FCM token for member \(memberId), sending notification...")
                
                // Send FCM notification to this member
                self.sendReactionFCMNotification(
                    token: fcmToken,
                    reactorName: reactorName,
                    reaction: reaction,
                    entryOwnerId: entryOwnerId,
                    targetUserId: memberId,
                    prompt: prompt
                )
            }
        }
    }
    
    private func sendReactionFCMNotification(token: String, reactorName: String, reaction: String, entryOwnerId: String, targetUserId: String, prompt: String) {
        print("📱 🎉 === REACTION FCM NOTIFICATION DEBUG ===")
        print("📱 🎉 Token (last 8): \(String(token.suffix(8)))")
        print("📱 🎉 Reactor: \(reactorName)")
        print("📱 🎉 Reaction: \(reaction)")
        print("📱 🎉 Entry Owner: \(entryOwnerId)")
        print("📱 🎉 Target User: \(targetUserId)")
        print("📱 🎉 Current User: \(Auth.auth().currentUser?.uid ?? "nil")")
        print("📱 🎉 Group ID: \(groupId)")
        print("📱 🎉 Prompt: \(prompt)")
        
        // CRITICAL: Verify we're not sending to the reactor
        if targetUserId == Auth.auth().currentUser?.uid {
            print("📱 🎉 ❌ ABORTING: Target user is the reactor!")
            return
        }
        
        // Create notification request for Cloud Function
        let notificationRequest: [String: Any] = [
            "fcmToken": token,
            "title": "🎉 New Reaction!",
            "body": "\(reactorName) reacted \(reaction) to a post in your circle",
            "data": [
                "type": "reaction",
                "groupId": groupId,
                "reactorName": reactorName,
                "reaction": reaction,
                "entryOwnerId": entryOwnerId,
                "targetUserId": targetUserId,
                "prompt": prompt
            ],
            "timestamp": FieldValue.serverTimestamp(),
            "processed": false,
            "targetUserId": targetUserId,
            "notificationType": "reaction"
        ]
        
        print("📱 🎉 Reaction notification request data:")
        for (key, value) in notificationRequest {
            if key != "timestamp" {
                print("📱 🎉   \(key): \(value)")
            }
        }
        
        print("📱 🎉 Adding reaction notification request to Firestore...")
        db.collection("notificationRequests").addDocument(data: notificationRequest) { error in
            if let error = error {
                print("📱 🎉 ❌ Error queuing reaction notification: \(error.localizedDescription)")
                print("📱 🎉 ❌ CRITICAL ERROR: \(error)")
            } else {
                print("📱 🎉 ✅ Reaction notification queued via Cloud Function for member \(targetUserId)")
                print("📱 🎉 ✅ CRITICAL SUCCESS: Notification request successfully added to Firestore!")
            }
        }
    }
    
    private func sendCommentNotification(commenterName: String, commentText: String, entryOwnerId: String, prompt: String) {
        print("📱 EntryStore: === SENDING COMMENT NOTIFICATION ===")
        print("📱 Commenter: \(commenterName)")
        print("📱 Comment: \(commentText)")
        print("📱 Entry owner: \(entryOwnerId)")
        print("📱 Prompt: \(prompt)")
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("📱 ❌ No current user for comment notification")
            return
        }
        
        print("📱 Current commenter user ID: \(currentUserId)")
        
        // Use the improved getGroupMembers method that already excludes current user
        getGroupMembers { [weak self] otherMemberIds in
            guard let self = self else { return }
            
            print("📱 📋 Comment notification: Found \(otherMemberIds.count) other circle members to notify")
            
            if otherMemberIds.isEmpty {
                print("📱 ℹ️ No other members to notify about comment")
                return
            }
            
            // Send FCM notifications to all other circle members (already excludes commenter)
            print("📱 🚀 Sending comment FCM notifications to \(otherMemberIds.count) other members")
            self.sendCommentNotificationsToMembers(
                memberIds: otherMemberIds,
                commenterName: commenterName,
                commentText: commentText,
                entryOwnerId: entryOwnerId,
                prompt: prompt
            )
        }
    }
    
    private func sendCommentNotificationsToMembers(memberIds: [String], commenterName: String, commentText: String, entryOwnerId: String, prompt: String) {
        print("📱 Sending comment notifications to \(memberIds.count) circle members...")
        
        for memberId in memberIds {
            print("📱 Sending comment notification to member: \(memberId)")
            
            // Get member's FCM token and send notification
            db.collection("users").document(memberId).getDocument { [weak self] userDoc, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("📱 ❌ Error getting member \(memberId) for comment notification: \(error.localizedDescription)")
                    return
                }
                
                guard let userDoc = userDoc, userDoc.exists, let userData = userDoc.data() else {
                    print("📱 ❌ Member \(memberId) not found for comment notification")
                    return
                }
                
                guard let fcmToken = userData["fcmToken"] as? String else {
                    print("📱 ⚠️ No FCM token found for member \(memberId)")
                    return
                }
                
                // Send FCM notification to this member
                self.sendCommentFCMNotification(
                    token: fcmToken,
                    commenterName: commenterName,
                    commentText: commentText,
                    entryOwnerId: entryOwnerId,
                    targetUserId: memberId,
                    prompt: prompt
                )
            }
        }
    }
    
    private func sendCommentFCMNotification(token: String, commenterName: String, commentText: String, entryOwnerId: String, targetUserId: String, prompt: String) {
        print("📱 Sending FCM comment notification...")
        
        // Create notification request for Cloud Function
        let notificationRequest: [String: Any] = [
            "fcmToken": token,
            "title": "💬 New Comment!",
            "body": "\(commenterName): \(commentText)",
            "data": [
                "type": "comment",
                "groupId": groupId,
                "commenterName": commenterName,
                "commentText": commentText,
                "entryOwnerId": entryOwnerId,
                "targetUserId": targetUserId,
                "prompt": prompt
            ],
            "timestamp": FieldValue.serverTimestamp(),
            "processed": false,
            "targetUserId": targetUserId,
            "notificationType": "comment"
        ]
        
        db.collection("notificationRequests").addDocument(data: notificationRequest) { error in
            if let error = error {
                print("📱 ❌ Error queuing comment notification: \(error.localizedDescription)")
            } else {
                print("📱 ✅ Comment notification queued via Cloud Function for member \(targetUserId)")
            }
        }
    }
    
    private func sendPromptUnlockNotification(prompt: String, influencerId: String, groupName: String) {
        print("📱 EntryStore: === SENDING PROMPT UNLOCK NOTIFICATION ===")
        print("📱 Prompt: \(prompt)")
        print("📱 Influencer ID: \(influencerId)")
        print("📱 Group name: \(groupName)")
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("📱 ❌ No current user for prompt unlock notification")
            return
        }
        
        // Only notify if the current user is the influencer
        guard currentUserId == influencerId else {
            print("📱 ℹ️ Current user is not the influencer, not sending prompt unlock notification")
            return
        }
        
        print("📱 ✅ Current user is the influencer, sending prompt unlock notification")
        
        // Send local notification
        let content = UNMutableNotificationContent()
        content.title = "✨ New Prompt Ready!"
        content.body = "Your new prompt is ready in \(groupName): \(prompt)"
        content.sound = .default
        content.badge = 1
        
        // Custom data for handling the tap
        content.userInfo = [
            "type": "prompt_unlock",
            "groupId": groupId,
            "prompt": prompt,
            "influencerId": influencerId,
            "groupName": groupName
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let identifier = "prompt_unlock_local_\(groupId)_\(Date().timeIntervalSince1970)_\(influencerId)"
        
        print("📱 🔔 Local prompt unlock notification identifier: \(identifier)")
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("📱 ❌ Error sending LOCAL prompt unlock notification: \(error)")
            } else {
                print("📱 ✅ LOCAL prompt unlock notification sent to influencer \(influencerId)")
            }
        }
        
        // Send FCM push notification
        print("📱 🚀 Sending FCM push notification for prompt unlock...")
        sendFCMPushNotification(
            to: [influencerId],
            title: "✨ New Prompt Ready!",
            body: "Your new prompt is ready in \(groupName): \(prompt)",
            data: [
                "type": "prompt_unlock",
                "groupId": groupId,
                "prompt": prompt,
                "influencerId": influencerId,
                "groupName": groupName
            ]
        )
        
        print("📱 === PROMPT UNLOCK NOTIFICATION SENDING COMPLETE ===")
    }
    
    // Public method to send prompt unlock notification
    func notifyPromptUnlock(prompt: String, influencerId: String, groupName: String) {
        print("📱 🔔 === IMMEDIATE PROMPT UNLOCK NOTIFICATION ===")
        print("📱 🔔 Prompt: '\(prompt)'")
        print("📱 🔔 Influencer: \(influencerId)")
        print("📱 🔔 Group: \(groupName)")
        
        guard let currentUserId = Auth.auth().currentUser?.uid,
              currentUserId == influencerId else {
            print("📱 🔔 ⚠️ Not sending immediate notification - user is not influencer")
            return
        }
        
        // Send immediate local notification (for when app is backgrounded)
        let content = UNMutableNotificationContent()
        content.title = "🎉 New Prompt Unlocked!"
        content.body = "Your next DIML prompt is ready to answer!"  // Generic message - don't reveal the prompt
        content.sound = .default
        content.badge = 1
        content.userInfo = [
            "type": "prompt_unlocked_immediate",
            "groupId": self.groupId,
            "groupName": groupName,
            "userId": influencerId,
            "prompt": prompt  // Real prompt for animation (hidden from notification text)
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let identifier = "prompt_unlocked_immediate_\(influencerId)_\(self.groupId)_\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("📱 🔔 ❌ Error sending immediate prompt unlock notification: \(error)")
            } else {
                print("📱 🔔 ✅ Immediate prompt unlock notification sent")
            }
        }
    }
    
    private func getUserName(for userId: String, completion: @escaping (String) -> Void) {
        db.collection("users").document(userId).getDocument { document, error in
            if let data = document?.data(), let name = data["name"] as? String {
                completion(name)
            } else {
                completion("Someone") // Fallback name
            }
        }
    }
    
    private func getGroupMembers(completion: @escaping ([String]) -> Void) {
        print("📱 🔍 === GETTING GROUP MEMBERS ===")
        print("📱 🔍 Group ID: \(groupId)")
        print("📱 🔍 Current user: \(Auth.auth().currentUser?.uid ?? "None")")
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("📱 🔍 ❌ No authenticated user")
            completion([])
            return
        }
        
        print("📱 🔍 CRITICAL: Current user ID to filter out: '\(currentUserId)'")
        
        db.collection("groups").document(groupId).getDocument { document, error in
            if let error = error {
                print("📱 🔍 ❌ Error fetching group members: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let document = document, document.exists else {
                print("📱 🔍 ❌ Group document does not exist")
                completion([])
                return
            }
            
            guard let data = document.data() else {
                print("📱 🔍 ❌ No data in group document")
                completion([])
                return
            }
            
            print("📱 🔍 📋 Group document data keys: \(data.keys)")
            
            // Get member IDs from the members array (preferred method)
            if let memberData = data["members"] as? [[String: Any]] {
                let allMemberIds = memberData.compactMap { $0["id"] as? String }
                print("📱 🔍 📋 Found \(memberData.count) member objects in Firestore")
                print("📱 🔍 📋 Extracted \(allMemberIds.count) member IDs:")
                for (index, memberId) in allMemberIds.enumerated() {
                    let isCurrentUser = memberId == currentUserId
                    print("📱 🔍 📋 [\(index + 1)] Member ID: '\(memberId)' (Current user: \(isCurrentUser))")
                }
                
                // CRITICAL: Filter out the current user to get OTHER members only
                let otherMemberIds = allMemberIds.filter { memberId in
                    let shouldExclude = memberId == currentUserId
                    if shouldExclude {
                        print("📱 🔍 🚫 EXCLUDING current user: \(memberId)")
                    }
                    return !shouldExclude
                }
                print("📱 🔍 🎯 FILTERED RESULT: \(otherMemberIds.count) OTHER members (excluding current user)")
                for (index, memberId) in otherMemberIds.enumerated() {
                    print("📱 🔍 🎯 [\(index + 1)] OTHER member: \(memberId)")
                }
                
                // FINAL VALIDATION: Double-check current user is not in the result
                if otherMemberIds.contains(currentUserId) {
                    print("📱 🔍 🚨 CRITICAL ERROR: Current user '\(currentUserId)' is STILL in the filtered list!")
                    print("📱 🔍 🚨 This would cause self-notification!")
                    print("📱 🔍 🚨 Filtered list: \(otherMemberIds)")
                } else {
                    print("📱 🔍 ✅ VERIFIED: Current user '\(currentUserId)' is NOT in filtered list")
                }
                
                // Check for duplicates
                let uniqueOtherMemberIds = Set(otherMemberIds)
                if otherMemberIds.count != uniqueOtherMemberIds.count {
                    print("📱 🔍 ⚠️ DUPLICATE MEMBER IDS DETECTED in other members!")
                    print("📱 🔍 ⚠️ Total other IDs: \(otherMemberIds.count), Unique other IDs: \(uniqueOtherMemberIds.count)")
                }
                
                completion(otherMemberIds)
                
            } else if let memberIds = data["memberIds"] as? [String] {
                // Fallback to memberIds array if members array is not available
                print("📱 🔍 📋 Using fallback memberIds array with \(memberIds.count) members")
                print("📱 🔍 📋 All memberIds: \(memberIds)")
                let otherMemberIds = memberIds.filter { memberId in
                    let shouldExclude = memberId == currentUserId
                    if shouldExclude {
                        print("📱 🔍 🚫 EXCLUDING current user from fallback: \(memberId)")
                    }
                    return !shouldExclude
                }
                print("📱 🔍 🎯 Fallback filtered result: \(otherMemberIds.count) other members")
                print("📱 🔍 🎯 Fallback other members: \(otherMemberIds)")
                completion(otherMemberIds)
                
            } else {
                print("📱 🔍 ❌ No 'members' or 'memberIds' field found")
                print("📱 🔍 ❌ Available fields: \(data.keys)")
                completion([])
            }
        }
    }
    
    // MARK: - FCM Push Notification Helper
    
    private func sendFCMPushNotification(to userIds: [String], title: String, body: String, data: [String: String]) {
        print("📱 🚀 ☁️ === SENDING FCM PUSH NOTIFICATION VIA CLOUD FUNCTION ===")
        print("📱 🚀 ☁️ Target users: \(userIds.count)")
        print("📱 🚀 ☁️ Title: \(title)")
        print("📱 🚀 ☁️ Body: \(body)")
        
        // Send push notification to each user
        for userId in userIds {
            print("📱 🚀 ☁️ Processing user: \(userId)")
            
            // Get the user's FCM token from Firestore
            db.collection("users").document(userId).getDocument { [weak self] document, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("📱 🚀 ❌ Error fetching FCM token for user \(userId): \(error.localizedDescription)")
                    return
                }
                
                guard let data = document?.data(),
                      let fcmToken = data["fcmToken"] as? String else {
                    print("📱 🚀 ⚠️ No FCM token found for user \(userId)")
                    print("📱 🚀 ⚠️ User may need to restart app to register for push notifications")
                    return
                }
                
                print("📱 🚀 ✅ Found FCM token for user \(userId): ...\(String(fcmToken.suffix(8)))")
                
                // Store notification request in Firestore to trigger Cloud Function
                let notificationRequest: [String: Any] = [
                    "fcmToken": fcmToken,
                    "title": title,
                    "body": body,
                    "data": data,
                    "timestamp": FieldValue.serverTimestamp(),
                    "processed": false,
                    "targetUserId": userId,
                    "notificationType": "diml_upload"
                ]
                
                self.db.collection("notificationRequests").addDocument(data: notificationRequest) { error in
                    if let error = error {
                        print("📱 🚀 ❌ Error storing notification request for user \(userId): \(error.localizedDescription)")
                    } else {
                        print("📱 🚀 ✅ Notification request stored for user \(userId) - Cloud Function will send push notification")
                        print("📱 🚀 ✅ This will work even when app is completely terminated!")
                    }
                }
            }
        }
    }
    
    // MARK: - Debug and Testing Methods
    
    func debugNotificationFlow() {
        print("🧪 === DEBUGGING NOTIFICATION FLOW ===")
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("🧪 ❌ No current user")
            return
        }
        
        print("🧪 Current user ID: \(currentUserId)")
        print("🧪 Group ID: \(groupId)")
        
        // Test getGroupMembers
        getGroupMembers { memberIds in
            print("🧪 📋 getGroupMembers returned \(memberIds.count) members:")
            for (index, memberId) in memberIds.enumerated() {
                let isCurrentUser = memberId == currentUserId
                print("🧪 📋 [\(index + 1)] \(memberId) (Current user: \(isCurrentUser))")
            }
            
            if memberIds.contains(currentUserId) {
                print("🧪 🚨 PROBLEM: Current user is in the notification list!")
                print("🧪 🚨 This means notifications would be sent to the person who posted")
            } else {
                print("🧪 ✅ Good: Current user is NOT in the notification list")
                print("🧪 ✅ Notifications would only go to other circle members")
            }
        }
    }
    
    // New function to test notification sending
    func testNotificationSending() {
        print("🧪 🚀 === TESTING NOTIFICATION SENDING ===")
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("🧪 ❌ No current user")
            return
        }
        
        // Get group members to test notification flow
        getGroupMembers { [weak self] memberIds in
            guard let self = self else { return }
            
            print("🧪 🚀 Testing notification to \(memberIds.count) members")
            
            if memberIds.isEmpty {
                print("🧪 ❌ No members to notify - test failed")
                return
            }
            
            // Send a test notification
            self.sendFCMPushNotification(
                to: memberIds,
                title: "🧪 Test Notification",
                body: "This is a test notification from \(currentUserId)",
                data: [
                    "type": "test",
                    "groupId": self.groupId,
                    "testUserId": currentUserId
                ]
            )
            
            print("🧪 ✅ Test notification sent to \(memberIds.count) members")
        }
    }
    
    // MARK: - Comprehensive Notification System Test
    
    func testAllNotificationSystems() {
        print("🧪 === COMPREHENSIVE NOTIFICATION SYSTEM TEST ===")
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("🧪 ❌ No current user for notification testing")
            return
        }
        
        print("🧪 Current user ID: \(currentUserId)")
        print("🧪 Group ID: \(groupId)")
        
        // Test 1: Upload Notifications
        print("🧪 🚀 Testing upload notifications...")
        testUploadNotification()
        
        // Test 2: Reaction Notifications  
        print("🧪 🎉 Testing reaction notifications...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.testReactionNotification()
        }
        
        // Test 3: Group Members Retrieval
        print("🧪 👥 Testing group member retrieval...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.getGroupMembers { members in
                print("🧪 👥 Group members test result: \(members.count) members")
                for (index, memberId) in members.enumerated() {
                    print("🧪 👥 [\(index + 1)] Member: \(memberId)")
                }
                
                if members.contains(currentUserId) {
                    print("🧪 👥 ❌ PROBLEM: Current user is in the members list!")
                    print("🧪 👥 ❌ This would cause self-notifications!")
                } else {
                    print("🧪 👥 ✅ Good: Current user is NOT in the members list")
                }
            }
        }
        
        // Test 4: Check Cloud Function Requirements
        print("🧪 ☁️ Testing Cloud Function requirements...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            self.testCloudFunctionRequirements()
        }
    }
    
    private func testReactionNotification() {
        print("🧪 🎉 === TESTING REACTION NOTIFICATION ===")
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("🧪 🎉 ❌ No current user")
            return
        }
        
        getUserName(for: currentUserId) { reactorName in
            print("🧪 🎉 Reactor name: \(reactorName)")
            
            self.getGroupMembers { groupMembers in
                print("🧪 🎉 Testing reaction notification to \(groupMembers.count) group members")
                
                self.sendReactionNotification(
                    reactorName: reactorName,
                    reaction: "🧪",
                    entryOwnerId: "test_entry_owner",
                    prompt: "Test reaction notification prompt"
                )
            }
        }
    }
    
    private func testCloudFunctionRequirements() {
        print("🧪 ☁️ === TESTING CLOUD FUNCTION REQUIREMENTS ===")
        
        // Test what fields are being sent to the Cloud Function
        let testNotificationRequest: [String: Any] = [
            "fcmToken": "test_token_12345678",
            "title": "🧪 Test Notification",
            "body": "Testing Cloud Function requirements",
            "data": [
                "type": "test",
                "groupId": groupId,
                "testField": "testValue"
            ],
            "timestamp": FieldValue.serverTimestamp(),
            "processed": false,
            "targetUserId": "test_user_id",
            "notificationType": "test"
        ]
        
        print("🧪 ☁️ Test notification request structure:")
        for (key, value) in testNotificationRequest {
            if key != "timestamp" {
                print("🧪 ☁️   \(key): \(value)")
            }
        }
        
        print("🧪 ☁️ Adding test notification request to Firestore...")
        db.collection("notificationRequests").addDocument(data: testNotificationRequest) { error in
            if let error = error {
                print("🧪 ☁️ ❌ Error adding test notification: \(error.localizedDescription)")
                print("🧪 ☁️ ❌ This suggests a Firestore permission or connection issue")
            } else {
                print("🧪 ☁️ ✅ Test notification request successfully added to Firestore!")
                print("🧪 ☁️ ✅ This means the app can write to notificationRequests collection")
                print("🧪 ☁️ ✅ If notifications still don't work, the issue is likely in the Cloud Function")
            }
        }
    }

}

// MARK: - Prompt Unlock Notification Scheduling

extension EntryStore {
    
    // Generate a realistic next prompt text for notifications
    private func generateNextPromptText() -> String {
        let timeOfDay = TimeOfDay.current()
        let prompts: [String]
        
        switch timeOfDay {
        case .morning:
            prompts = [
                "What's your morning looking like?",
                "Show us your morning coffee or breakfast",
                "What's the first thing you did today?",
                "How are you starting your day?",
                "What's your morning vibe?"
            ]
        case .afternoon:
            prompts = [
                "What's happening in your afternoon?",
                "Show us what you're up to right now",
                "What's your current energy like?",
                "Share your afternoon activity",
                "What's your midday mood?"
            ]
        case .night:
            prompts = [
                "How did your day go?",
                "What's your evening looking like?",
                "Share something from your day",
                "What's your night routine?",
                "How are you winding down?"
            ]
        }
        
        // Use a simple random selection for now
        return prompts.randomElement() ?? "What does your day look like?"
    }
    
    // Schedule next prompt unlock notification - called after influencer uploads entry
    func scheduleNextPromptUnlockNotification() {
        print("📱 ⏭️ === SCHEDULING NEXT PROMPT UNLOCK NOTIFICATION ===")
        print("📱 ⏭️ Called from EntryStore.addEntry()")
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("📱 ⏭️ ❌ No authenticated user")
            return
        }
        
        print("📱 ⏭️ Current user: \(currentUserId)")
        print("📱 ⏭️ Group ID: \(groupId)")
        
        // Get group info to determine if current user is influencer and get frequency
        db.collection("groups").document(groupId).getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                print("📱 ⏭️ ❌ Error fetching group: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, document.exists, let data = document.data() else {
                print("📱 ⏭️ ❌ Group document not found")
                return
            }
            
            guard let currentInfluencerId = data["currentInfluencerId"] as? String else {
                print("📱 ⏭️ ❌ No current influencer ID found")
                return
            }
            
            // CRITICAL: Only schedule for the influencer themselves
            guard currentUserId == currentInfluencerId else {
                print("📱 ⏭️ ℹ️ Current user is not influencer, not scheduling notification")
                print("📱 ⏭️ ℹ️ Current user: \(currentUserId)")
                print("📱 ⏭️ ℹ️ Influencer: \(currentInfluencerId)")
                return
            }
            
            guard let frequencyRaw = data["promptFrequency"] as? String else {
                print("📱 ⏭️ ❌ No prompt frequency found")
                return
            }
            
            let groupName = data["name"] as? String ?? "DIML Group"
            let notificationsMuted = data["notificationsMuted"] as? Bool ?? false
            
            // Check if notifications are muted for this group
            guard !notificationsMuted else {
                print("📱 ⏭️ ℹ️ Notifications muted for group, not scheduling")
                return
            }
            
            print("📱 ⏭️ ✅ Current user IS the influencer - proceeding with scheduling")
            print("📱 ⏭️ Frequency: \(frequencyRaw)")
            print("📱 ⏭️ Group: \(groupName)")
            
            // Calculate next prompt time based on frequency
            let now = Date()
            var nextPromptTime: Date
            
            if frequencyRaw.contains("testing") {
                // Testing mode: 1 minute
                nextPromptTime = Calendar.current.date(byAdding: .minute, value: 1, to: now) ?? now
                print("📱 ⏭️ Testing mode: 1 minute interval")
            } else if frequencyRaw.contains("hourly") {
                nextPromptTime = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
                print("📱 ⏭️ Hourly mode: 1 hour interval")
            } else if frequencyRaw.contains("threeHours") {
                nextPromptTime = Calendar.current.date(byAdding: .hour, value: 3, to: now) ?? now
                print("📱 ⏭️ Three hours mode: 3 hour interval")
            } else if frequencyRaw.contains("sixHours") {
                nextPromptTime = Calendar.current.date(byAdding: .hour, value: 6, to: now) ?? now
                print("📱 ⏭️ Six hours mode: 6 hour interval")
            } else {
                // Default to 6 hours
                nextPromptTime = Calendar.current.date(byAdding: .hour, value: 6, to: now) ?? now
                print("📱 ⏭️ Default mode: 6 hour interval")
            }
            
            let timeInterval = nextPromptTime.timeIntervalSince(now)
            
            print("📱 ⏭️ Current time: \(now)")
            print("📱 ⏭️ Next prompt unlock time: \(nextPromptTime)")
            print("📱 ⏭️ Time interval: \(timeInterval) seconds (\(timeInterval/60) minutes)")
            
            guard timeInterval > 0 else {
                print("📱 ⏭️ ⚠️ Invalid time interval, not scheduling notification")
                return
            }
            
            // Cancel any existing prompt unlock notifications to prevent duplicates
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                let existingPromptNotifications = requests.filter { 
                    $0.identifier.contains("prompt_unlock") && $0.identifier.contains(currentInfluencerId)
                }
                
                if !existingPromptNotifications.isEmpty {
                    let identifiersToRemove = existingPromptNotifications.map { $0.identifier }
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
                    print("📱 ⏭️ 🗑️ Cancelled \(identifiersToRemove.count) existing prompt unlock notifications")
                }
                
                // Generate a realistic next prompt text for the notification
                let nextPromptText = self.generateNextPromptText()
                
                // Schedule LOCAL notification for influencer
                let content = UNMutableNotificationContent()
                content.title = "🎉 New Prompt Unlocked!"
                content.body = "Your next DIML prompt is ready to answer!"  // Generic message - don't reveal the prompt
                content.sound = .default
                content.badge = 1
                content.userInfo = [
                    "type": "prompt_unlock",
                    "groupId": self.groupId,
                    "groupName": groupName,
                    "userId": currentInfluencerId,
                    "prompt": nextPromptText,  // Real prompt for animation (hidden from notification text)
                    "promptFrequency": frequencyRaw,
                    "unlockTime": nextPromptTime.timeIntervalSince1970
                ]
                
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
                let identifier = "prompt_unlock_\(currentInfluencerId)_\(self.groupId)_\(nextPromptTime.timeIntervalSince1970)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                
                print("📱 ⏭️ 🔧 NOTIFICATION DETAILS:")
                print("📱 ⏭️ 🔧 Title: '\(content.title)'")
                print("📱 ⏭️ 🔧 Body: '\(content.body)' (generic message)")
                print("📱 ⏭️ 🔧 Hidden prompt for animation: '\(nextPromptText)'")
                print("📱 ⏭️ 🔧 Identifier: '\(identifier)'")
                print("📱 ⏭️ 🔧 Will fire in: \(Int(timeInterval)) seconds (\(Int(timeInterval/60)) minutes)")
                print("📱 ⏭️ 🔧 Target user: \(currentInfluencerId)")
                
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("📱 ⏭️ ❌ Error scheduling prompt unlock notification: \(error.localizedDescription)")
                    } else {
                        print("📱 ⏭️ ✅ Successfully scheduled LOCAL prompt unlock notification!")
                        print("📱 ⏭️ ✅ Influencer \(currentInfluencerId) will be notified in \(Int(timeInterval)) seconds")
                        print("📱 ⏭️ ✅ Local notification will work when app is backgrounded")
                        
                        // CRITICAL: Also schedule FCM push notification for when app is terminated
                        print("📱 ⏭️ 🚀 Also scheduling FCM push notification for app termination...")
                        self.scheduleFCMPromptUnlockNotification(
                            influencerId: currentInfluencerId,
                            groupName: groupName,
                            prompt: nextPromptText,
                            unlockTime: nextPromptTime
                        )
                        
                        // Verify local notification was scheduled
                        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                            let justScheduled = requests.filter { $0.identifier == identifier }
                            if justScheduled.isEmpty {
                                print("📱 ⏭️ ❌ CRITICAL: Local notification was NOT found in pending queue!")
                            } else {
                                print("📱 ⏭️ ✅ VERIFIED: Local notification is confirmed in pending queue")
                                if let trigger = justScheduled.first?.trigger as? UNTimeIntervalNotificationTrigger {
                                    print("📱 ⏭️ ✅ VERIFIED: Will fire at \(trigger.nextTriggerDate() ?? Date())")
                                }
                            }
                            print("📱 ⏭️ 📊 Total pending local notifications: \(requests.count)")
                        }
                    }
                }
            }
        }
    }
    
    // Schedule FCM push notification for prompt unlock (works when app is terminated)
    private func scheduleFCMPromptUnlockNotification(influencerId: String, groupName: String, prompt: String, unlockTime: Date) {
        print("📱 ⏭️ 🚀 === SCHEDULING FCM PROMPT UNLOCK NOTIFICATION ===")
        print("📱 ⏭️ 🚀 Influencer: \(influencerId)")
        print("📱 ⏭️ 🚀 Group: \(groupName)")
        print("📱 ⏭️ 🚀 Unlock time: \(unlockTime)")
        print("📱 ⏭️ 🚀 Prompt: \(prompt)")
        
        // Get the influencer's FCM token
        db.collection("users").document(influencerId).getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                print("📱 ⏭️ 🚀 ❌ Error fetching influencer FCM token: \(error.localizedDescription)")
                return
            }
            
            guard let userData = document?.data(),
                  let fcmToken = userData["fcmToken"] as? String else {
                print("📱 ⏭️ 🚀 ⚠️ No FCM token found for influencer \(influencerId)")
                print("📱 ⏭️ 🚀 ⚠️ FCM notification will not be sent when app is terminated")
                return
            }
            
            print("📱 ⏭️ 🚀 ✅ Found FCM token for influencer: ...\(String(fcmToken.suffix(8)))")
            
            // Create scheduled notification request for Cloud Function
            let scheduledNotificationRequest: [String: Any] = [
                "fcmToken": fcmToken,
                "title": "🎉 New Prompt Unlocked!",
                "body": "Your next DIML prompt is ready to answer!",  // Generic message
                "data": [
                    "type": "prompt_unlock",
                    "groupId": self.groupId,
                    "groupName": groupName,
                    "userId": influencerId,
                    "prompt": prompt,  // Real prompt for navigation
                    "unlockTime": String(unlockTime.timeIntervalSince1970)
                ],
                "scheduledFor": unlockTime,  // When to send the notification
                "processed": false,
                "targetUserId": influencerId,
                "notificationType": "prompt_unlock_scheduled",
                "createdAt": FieldValue.serverTimestamp()
            ]
            
            print("📱 ⏭️ 🚀 Storing scheduled FCM notification request...")
            
            // Store in Firestore for Cloud Function to process at the right time
            self.db.collection("scheduledNotifications").addDocument(data: scheduledNotificationRequest) { error in
                if let error = error {
                    print("📱 ⏭️ 🚀 ❌ Error storing scheduled FCM notification: \(error.localizedDescription)")
                } else {
                    print("📱 ⏭️ 🚀 ✅ Successfully stored scheduled FCM notification!")
                    print("📱 ⏭️ 🚀 ✅ Cloud Function will send FCM push at \(unlockTime)")
                    print("📱 ⏭️ 🚀 ✅ This ensures notification works when app is terminated")
                }
            }
        }
    }
}

// MARK: - Codable Entry Structure

private struct CodableDIMLEntry: Codable {
    let id: String
    let userId: String
    let prompt: String
    let response: String
    let imageData: Data?
    let imageURL: String?
    let timestamp: Date
    let comments: [Comment]
    let reactions: [String: Int]
    let userReactions: [UserReaction]
    let frameSize: FrameSize
    let promptType: PromptType
} 