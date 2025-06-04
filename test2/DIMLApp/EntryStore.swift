import SwiftUI

class EntryStore: ObservableObject {
    @Published var entries: [DIMLEntry] = []

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
    }
}
