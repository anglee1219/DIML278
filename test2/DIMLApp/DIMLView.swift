import SwiftUI

struct DIMLView: View {
    @ObservedObject var store: EntryStore
    var group: Group
    @State private var showingAddEntry = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Rebecca’s DIML")
                                .font(.title)
                                .bold()
                            Text("she/her")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Button {
                            // Future: Settings
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                    }
                    .padding(.horizontal)

                    ForEach(store.entries) { entry in
                        VStack(spacing: 10) {
                            if let image = entry.image {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 250)
                                    .clipped()
                                    .cornerRadius(15)
                            }
                            PromptCard(prompt: entry.prompt, response: entry.response)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Your Day")
            .navigationBarItems(trailing: Button(action: {
                showingAddEntry = true
            }) {
                Image(systemName: "plus")
            })
            .sheet(isPresented: $showingAddEntry) {
                AddEntryView(store: store)
            }
        }
    }
}
