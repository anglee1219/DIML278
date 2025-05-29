import SwiftUI

struct AddEntryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: EntryStore

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
                store.addEntry(prompt: prompt, response: response, image: selectedImage)
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
        AddEntryView(store: EntryStore())
    }
}
