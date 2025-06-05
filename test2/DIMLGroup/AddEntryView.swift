import SwiftUI

struct AddEntryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: EntryStore
    var onComplete: ((DIMLEntry) -> Void)?

    @State private var prompt = ""
    @State private var response = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Prompt")) {
                    TextField("e.g. what does your morning look like?", text: $prompt)
                }
                Section(header: Text("Response")) {
                    TextField("e.g. corepower w/ eliza", text: $response)
                }
                Section {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                    }
                    Button("Select Photo") {
                        showingImagePicker = true
                    }
                }
            }
            .navigationTitle("Add Entry")
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            }, trailing: Button("Save") {
                let newEntry = DIMLEntry(
                    userId: "sampleUser",
                    prompt: prompt,
                    response: response,
                    image: selectedImage,
                    frameSize: FrameSize.random,
                    promptType: selectedImage != nil ? .image : .text
                )
                store.addEntry(newEntry)
                onComplete?(newEntry)
                dismiss()
            }.disabled(prompt.isEmpty || response.isEmpty))
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
            }
        }
    }
}

struct AddEntryView_Previews: PreviewProvider {
    static var previews: some View {
        AddEntryView(store: EntryStore(groupId: "preview-group"))
    }
}
