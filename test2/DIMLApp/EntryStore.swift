import SwiftUI

class EntryStore: ObservableObject {
    @Published var entries: [DIMLEntry] = []

    func addEntry(prompt: String, response: String, image: UIImage?) {
        let newEntry = DIMLEntry(
            id: UUID().uuidString,
            userId: "sampleUser", // or pass in the user ID
            prompt: prompt,
            response: response,
            image: image,
            comments: [],
            reactions: [:]
        )
        entries.insert(newEntry, at: 0)
    }
}
