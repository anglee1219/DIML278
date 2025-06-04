import Foundation
import SwiftUI

class EntryStore: ObservableObject {
    @Published private(set) var entries: [DIMLEntry] = []
    
    func addEntry(_ entry: DIMLEntry) {
        entries.insert(entry, at: 0)  // Add new entries at the top
    }
    
    func updateEntry(_ entry: DIMLEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        }
    }
    
    func addComment(to entryId: String, comment: Comment) {
        if let index = entries.firstIndex(where: { $0.id == entryId }) {
            entries[index].comments.append(comment)
        }
    }
    
    func addReaction(to entryId: String, reaction: String) {
        if let index = entries.firstIndex(where: { $0.id == entryId }) {
            entries[index].reactions[reaction, default: 0] += 1
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
} 