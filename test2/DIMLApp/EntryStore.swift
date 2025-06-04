import SwiftUI

class EntryStore: ObservableObject {
    @Published var entries: [DIMLEntry] = []
    private let groupId: String
    
    init(groupId: String = "default-group") {
        self.groupId = groupId
        loadEntries()
    }

    func addEntry(prompt: String, response: String, image: UIImage?, frameSize: FrameSize? = nil) {
        let newEntry = DIMLEntry(
            id: UUID().uuidString,
            userId: "sampleUser", // or pass in the user ID
            prompt: prompt,
            response: response,
            image: image,
            frameSize: frameSize ?? FrameSize.random
        )
        entries.insert(newEntry, at: 0)
        saveEntries()
    }
    
    func addEntry(_ entry: DIMLEntry) {
        entries.insert(entry, at: 0)
        saveEntries()
    }
    
    // MARK: - Persistence Methods
    
    private func saveEntries() {
        // Simple UserDefaults saving for the old app
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            // Convert entries to a codable format (simplified version)
            let codableEntries = entries.map { entry in
                SimpleCodableEntry(
                    id: entry.id,
                    userId: entry.userId,
                    prompt: entry.prompt,
                    response: entry.response,
                    imageData: entry.image?.jpegData(compressionQuality: 0.8),
                    timestamp: entry.timestamp,
                    frameSize: entry.frameSize
                )
            }
            
            let data = try encoder.encode(codableEntries)
            UserDefaults.standard.set(data, forKey: "entries_\(groupId)")
        } catch {
            print("Failed to save entries: \(error)")
        }
    }
    
    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: "entries_\(groupId)") else {
            return
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let codableEntries = try decoder.decode([SimpleCodableEntry].self, from: data)
            
            // Convert back to DIMLEntry
            entries = codableEntries.map { codableEntry in
                let image = codableEntry.imageData != nil ? UIImage(data: codableEntry.imageData!) : nil
                
                return DIMLEntry(
                    id: codableEntry.id,
                    userId: codableEntry.userId,
                    prompt: codableEntry.prompt,
                    response: codableEntry.response,
                    image: image,
                    timestamp: codableEntry.timestamp,
                    frameSize: codableEntry.frameSize
                )
            }
        } catch {
            print("Failed to load entries: \(error)")
            entries = []
        }
    }
}

private struct SimpleCodableEntry: Codable {
    let id: String
    let userId: String
    let prompt: String
    let response: String
    let imageData: Data?
    let timestamp: Date
    let frameSize: FrameSize
}
