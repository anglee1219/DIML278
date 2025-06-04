import Foundation
import SwiftUI

class EntryStore: ObservableObject {
    @Published private(set) var entries: [DIMLEntry] = []
    private let groupId: String
    
    init(groupId: String) {
        self.groupId = groupId
        loadEntries()
    }
    
    func addEntry(_ entry: DIMLEntry) {
        print("💾 EntryStore: Adding entry with ID: \(entry.id)")
        print("💾 EntryStore: Entry imageURL: \(entry.imageURL ?? "nil")")
        entries.insert(entry, at: 0)  // Add new entries at the top
        print("💾 EntryStore: Total entries after add: \(entries.count)")
        saveEntries()
    }
    
    func updateEntry(_ entry: DIMLEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            saveEntries()
        }
    }
    
    func addComment(to entryId: String, comment: Comment) {
        print("💬 EntryStore: Adding comment to entry \(entryId)")
        print("💬 EntryStore: Comment text: \(comment.text)")
        print("💬 EntryStore: Comment user: \(comment.userId)")
        if let index = entries.firstIndex(where: { $0.id == entryId }) {
            print("💬 EntryStore: Found entry at index \(index), current comment count: \(entries[index].comments.count)")
            entries[index].comments.append(comment)
            print("💬 EntryStore: Added comment, new comment count: \(entries[index].comments.count)")
            saveEntries()
            print("💬 EntryStore: Comment saved to UserDefaults")
        } else {
            print("💬 EntryStore: ERROR - Entry with ID \(entryId) not found!")
        }
    }
    
    func addReaction(to entryId: String, reaction: String) {
        print("💬 EntryStore: Adding reaction \(reaction) to entry \(entryId)")
        if let index = entries.firstIndex(where: { $0.id == entryId }) {
            let oldCount = entries[index].reactions[reaction, default: 0]
            entries[index].reactions[reaction, default: 0] += 1
            let newCount = entries[index].reactions[reaction, default: 0]
            print("💬 EntryStore: Reaction \(reaction) count: \(oldCount) -> \(newCount)")
            saveEntries()
            print("💬 EntryStore: Reaction saved to UserDefaults")
        } else {
            print("💬 EntryStore: ERROR - Entry with ID \(entryId) not found!")
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
                    frameSize: entry.frameSize
                )
                print("💾 EntryStore: Created CodableDIMLEntry with imageURL: \(codableEntry.imageURL ?? "nil")")
                return codableEntry
            }
            
            let data = try encoder.encode(codableEntries)
            UserDefaults.standard.set(data, forKey: "entries_\(groupId)")
            print("💾 EntryStore: Successfully saved \(entries.count) entries for group \(groupId)")
            print("💾 EntryStore: Data size: \(data.count) bytes")
        } catch {
            print("💾 EntryStore: Failed to save entries: \(error)")
        }
    }
    
    private func loadEntries() {
        print("💾 EntryStore: Loading entries for group \(groupId)")
        guard let data = UserDefaults.standard.data(forKey: "entries_\(groupId)") else {
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
        entries = []
        UserDefaults.standard.removeObject(forKey: "entries_\(groupId)")
    }
    
    // Method to force reload entries from UserDefaults
    func reloadEntries() {
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
    let frameSize: FrameSize
} 