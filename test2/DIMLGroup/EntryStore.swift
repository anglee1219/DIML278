import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class EntryStore: ObservableObject {
    @Published private(set) var entries: [DIMLEntry] = []
    private let groupId: String
    private var currentUserId: String?
    private let db = Firestore.firestore()
    private var entriesListener: ListenerRegistration?
    
    init(groupId: String) {
        self.groupId = groupId
        self.currentUserId = Auth.auth().currentUser?.uid
        setupEntriesListener()
    }
    
    deinit {
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
        
        // Remove existing listener
        entriesListener?.remove()
        
        // Listen for entries in this group with real-time updates
        entriesListener = db.collection("groups")
            .document(groupId)
            .collection("entries")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                guard let self = self else { return }
                
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
                print("🔄 EntryStore: Received snapshot from \(source) with \(snapshot.documents.count) documents")
                
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
                        frameSize: frameSize
                    )
                }
                
                print("✅ EntryStore: Loaded \(entries.count) entries from Firestore (\(source)) for group \(self.groupId)")
                
                // Log reaction and comment counts for debugging
                for entry in entries.prefix(3) {
                    print("📊 Entry \(entry.id): \(entry.userReactions.count) reactions, \(entry.comments.count) comments")
                }
                
                DispatchQueue.main.async {
                    self.entries = entries
                    // Also save to local storage as backup
                    self.saveEntriesToLocal()
                    print("🔄 EntryStore: Updated local entries array with \(entries.count) entries")
                }
            }
    }
    
    func addEntry(_ entry: DIMLEntry) {
        print("💾 EntryStore: Adding entry to Firestore for group \(groupId)")
        print("💾 EntryStore: Entry ID: \(entry.id), User: \(entry.userId)")
        print("💾 EntryStore: Entry imageURL: \(entry.imageURL ?? "nil")")
        
        // Prepare entry data for Firestore
        var entryData: [String: Any] = [
            "userId": entry.userId,
            "prompt": entry.prompt,
            "response": entry.response,
            "timestamp": Timestamp(date: entry.timestamp),
            "frameSize": entry.frameSize.rawValue,
            "reactions": entry.reactions,
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
                    // The listener will automatically update the local entries array
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
                            // The listener will automatically update the local entries array
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
                    frameSize: entry.frameSize
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
                    frameSize: codableEntry.frameSize
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
        print("🔄 EntryStore: Reloading entries from Firestore")
        setupEntriesListener()
    }
    
    private func saveEntriesToLocal() {
        print("💾 EntryStore: Saving \(entries.count) entries to local storage")
        saveEntries()
    }
    
    private func loadEntriesFromLocal() {
        print("💾 EntryStore: Loading entries from local storage")
        loadEntries()
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
} 