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
                    
                    // Send upload notification to group members
                    self?.getUserName(for: entry.userId) { uploaderName in
                        self?.getGroupMembers { groupMembers in
                            self?.sendDIMLUploadNotification(uploaderName: uploaderName, prompt: entry.prompt, groupMembers: groupMembers)
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
                    newCommentData["imageData"] = imageData.base64EncodedString()
                }
                
                if let imageURL = comment.imageURL {
                    newCommentData["imageURL"] = imageURL
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
        print("📱 Uploader: \(uploaderName)")
        print("📱 Prompt: \(prompt)")
        print("📱 Group members received: \(groupMembers.count)")
        print("📱 Group members list:")
        for (index, member) in groupMembers.enumerated() {
            print("📱 [\(index + 1)] Member ID: \(member)")
        }
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("📱 ❌ No current user for upload notification")
            return
        }
        
        print("📱 Current uploader user ID: \(currentUserId)")
        
        // Don't notify the person who uploaded
        let membersToNotify = groupMembers.filter { $0 != currentUserId }
        print("📱 After filtering out uploader: \(membersToNotify.count) members to notify")
        print("📱 Members to notify:")
        for (index, member) in membersToNotify.enumerated() {
            print("📱 🔔 [\(index + 1)] Will notify: \(member)")
        }
        
        // Check for duplicates in members to notify
        let uniqueMembersToNotify = Set(membersToNotify)
        if membersToNotify.count != uniqueMembersToNotify.count {
            print("📱 ⚠️ DUPLICATE NOTIFICATION TARGETS DETECTED!")
            print("📱 ⚠️ Total targets: \(membersToNotify.count), Unique targets: \(uniqueMembersToNotify.count)")
            print("📱 ⚠️ This will cause duplicate notifications!")
        }
        
        // ENHANCED: Send both local notifications AND FCM push notifications
        print("📱 🚀 === SENDING BOTH LOCAL AND PUSH NOTIFICATIONS ===")
        
        // 1. Send local notifications (works when app is running/backgrounded)
        for (index, memberId) in membersToNotify.enumerated() {
            print("📱 🔔 Creating LOCAL notification \(index + 1) for member: \(memberId)")
            
            let content = UNMutableNotificationContent()
            content.title = "📸 New DIML Posted!"
            content.body = "\(uploaderName) shared: \(prompt)"
            content.sound = .default
            content.badge = 1
            
            // Custom data for handling the tap
            content.userInfo = [
                "type": "diml_upload",
                "groupId": groupId,
                "uploaderName": uploaderName,
                "prompt": prompt,
                "uploaderId": currentUserId
            ]
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
            let identifier = "diml_upload_local_\(groupId)_\(Date().timeIntervalSince1970)_\(memberId)"
            
            print("📱 🔔 Local notification identifier: \(identifier)")
            
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("📱 ❌ Error sending LOCAL DIML upload notification to \(memberId): \(error)")
                } else {
                    print("📱 ✅ LOCAL DIML upload notification sent to member \(memberId)")
                }
            }
        }
        
        // 2. Send FCM push notifications (works when app is completely terminated)
        print("📱 🚀 Sending FCM push notifications via Cloud Function...")
        sendFCMPushNotification(
            to: membersToNotify,
            title: "📸 New DIML Posted!",
            body: "\(uploaderName) shared: \(prompt)",
            data: [
                "type": "diml_upload",
                "groupId": groupId,
                "uploaderName": uploaderName,
                "prompt": prompt
            ]
        )
        
        print("📱 === UPLOAD NOTIFICATION SENDING COMPLETE ===")
    }
    
    private func sendReactionNotification(reactorName: String, reaction: String, entryOwnerId: String, prompt: String) {
        print("📱 EntryStore: Sending reaction notification")
        print("📱 Reactor: \(reactorName)")
        print("📱 Reaction: \(reaction)")
        print("📱 Entry owner: \(entryOwnerId)")
        print("📱 Prompt: \(prompt)")
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("📱 ❌ No current user for reaction notification")
            return
        }
        
        // Don't notify yourself
        guard currentUserId != entryOwnerId else {
            print("📱 ℹ️ Not sending reaction notification to self")
            return
        }
        
        // Send local notification
        let content = UNMutableNotificationContent()
        content.title = "🎉 New Reaction!"
        content.body = "\(reactorName) reacted \(reaction) to your DIML"
        content.sound = .default
        content.badge = 1
        
        // Custom data for handling the tap
        content.userInfo = [
            "type": "reaction",
            "groupId": groupId,
            "reactorName": reactorName,
            "reaction": reaction,
            "entryOwnerId": entryOwnerId,
            "prompt": prompt
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let identifier = "reaction_local_\(groupId)_\(Date().timeIntervalSince1970)_\(entryOwnerId)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("📱 ❌ Error sending LOCAL reaction notification: \(error)")
            } else {
                print("📱 ✅ LOCAL reaction notification sent to entry owner \(entryOwnerId)")
            }
        }
        
        // Send FCM push notification
        print("📱 🚀 Sending FCM push notification for reaction...")
        sendFCMPushNotification(
            to: [entryOwnerId],
            title: "🎉 New Reaction!",
            body: "\(reactorName) reacted \(reaction) to your DIML",
            data: [
                "type": "reaction",
                "groupId": groupId,
                "reactorName": reactorName,
                "reaction": reaction,
                "userId": entryOwnerId
            ]
        )
    }
    
    private func sendCommentNotification(commenterName: String, commentText: String, entryOwnerId: String, prompt: String) {
        print("📱 EntryStore: Sending comment notification")
        print("📱 Commenter: \(commenterName)")
        print("📱 Comment: \(commentText)")
        print("📱 Entry owner: \(entryOwnerId)")
        print("📱 Prompt: \(prompt)")
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("📱 ❌ No current user for comment notification")
            return
        }
        
        // Don't notify yourself
        guard currentUserId != entryOwnerId else {
            print("📱 ℹ️ Not sending comment notification to self")
            return
        }
        
        // Send local notification
        let content = UNMutableNotificationContent()
        content.title = "💬 New Comment!"
        content.body = "\(commenterName): \(commentText)"
        content.sound = .default
        content.badge = 1
        
        // Custom data for handling the tap
        content.userInfo = [
            "type": "comment",
            "groupId": groupId,
            "commenterName": commenterName,
            "commentText": commentText,
            "entryOwnerId": entryOwnerId,
            "prompt": prompt
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let identifier = "comment_local_\(groupId)_\(Date().timeIntervalSince1970)_\(entryOwnerId)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("📱 ❌ Error sending LOCAL comment notification: \(error)")
            } else {
                print("📱 ✅ LOCAL comment notification sent to entry owner \(entryOwnerId)")
            }
        }
        
        // Send FCM push notification
        print("📱 🚀 Sending FCM push notification for comment...")
        sendFCMPushNotification(
            to: [entryOwnerId],
            title: "💬 New Comment!",
            body: "\(commenterName): \(commentText)",
            data: [
                "type": "comment",
                "groupId": groupId,
                "commenterName": commenterName,
                "commentText": commentText,
                "userId": entryOwnerId
            ]
        )
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
        print("📱 EntryStore: Public method called for prompt unlock notification")
        sendPromptUnlockNotification(prompt: prompt, influencerId: influencerId, groupName: groupName)
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
            
            if let memberData = data["members"] as? [[String: Any]] {
                let memberIds = memberData.compactMap { $0["id"] as? String }
                print("📱 🔍 📋 Found \(memberData.count) member objects in Firestore")
                print("📱 🔍 📋 Extracted \(memberIds.count) member IDs:")
                for (index, memberId) in memberIds.enumerated() {
                    print("📱 🔍 📋 [\(index + 1)] Member ID: \(memberId)")
                    let isCurrentUser = memberId == Auth.auth().currentUser?.uid
                    print("📱 🔍 📋 [\(index + 1)] Is current user: \(isCurrentUser)")
                    
                    // Show the last 8 characters for easier identification
                    let shortId = String(memberId.suffix(8))
                    print("📱 🔍 📋 [\(index + 1)] Short ID: ...\(shortId)")
                }
                
                // Check for duplicates
                let uniqueMemberIds = Set(memberIds)
                if memberIds.count != uniqueMemberIds.count {
                    print("📱 🔍 ⚠️ DUPLICATE MEMBER IDS DETECTED!")
                    print("📱 🔍 ⚠️ Total IDs: \(memberIds.count), Unique IDs: \(uniqueMemberIds.count)")
                    
                    // Show which IDs are duplicated
                    let counts = memberIds.reduce(into: [:]) { counts, id in
                        counts[id, default: 0] += 1
                    }
                    for (id, count) in counts where count > 1 {
                        print("📱 🔍 ⚠️ Duplicate ID: \(id) appears \(count) times")
                    }
                }
                
                print("📱 🔍 🎯 THESE MEMBER IDS WILL RECEIVE NOTIFICATIONS:")
                let currentUserId = Auth.auth().currentUser?.uid ?? ""
                let membersToNotify = memberIds.filter { $0 != currentUserId }
                for (index, memberId) in membersToNotify.enumerated() {
                    let shortId = String(memberId.suffix(8))
                    print("📱 🔍 🎯 [\(index + 1)] WILL NOTIFY: ...\(shortId) (full: \(memberId))")
                }
                
                if membersToNotify.count > 1 {
                    print("📱 🔍 ⚠️ WARNING: \(membersToNotify.count) DIFFERENT USER IDS WILL RECEIVE NOTIFICATIONS")
                    print("📱 🔍 ⚠️ THIS WILL CAUSE \(membersToNotify.count) DUPLICATE NOTIFICATIONS ON THE SAME DEVICE")
                }
                
                completion(memberIds)
            } else {
                print("📱 🔍 ❌ No 'members' field found or wrong format")
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
                    "processed": false
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