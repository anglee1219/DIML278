import SwiftUI

struct DIMLView: View {
    @StateObject var store: EntryStore
    var group: Group
    @State private var showingAddEntry = false
    @State private var showTestingAlert = false
    
    init(store: EntryStore? = nil, group: Group) {
        self.group = group
        if let store = store {
            self._store = StateObject(wrappedValue: store)
        } else {
            self._store = StateObject(wrappedValue: EntryStore(groupId: group.id))
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Rebecca's DIML")
                                .font(.title)
                                .bold()
                            Text("she/her")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        
                        // Testing button
                        Button {
                            startTestingMode()
                        } label: {
                            Image(systemName: "stopwatch")
                                .foregroundColor(.orange)
                        }
                        
                        Button {
                            // Future: Settings to adjust prompt timing
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                    }
                    .padding(.horizontal)

                    // Testing info banner
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("Testing Mode Available")
                                .font(.custom("Fredoka-Medium", size: 16))
                                .foregroundColor(.orange)
                            Spacer()
                        }
                        Text("Tap the stopwatch icon to activate 1-minute prompt testing")
                            .font(.custom("Fredoka-Regular", size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Example prompt cards showing different types
                    VStack(spacing: 16) {
                        Text("Today's Prompts")
                            .font(.custom("Fredoka-Medium", size: 20))
                            .foregroundColor(.black)
                            .padding(.horizontal)
                        
                        // Simple text prompt
                        PromptCard(configuration: .simpleText(prompt: "what does your typical morning look like?")) { response in
                            print("Simple text response: \(response.textResponses)")
                        }
                        
                        // Image prompt
                        PromptCard(configuration: .imageWithText(prompt: "campus views")) { response in
                            print("Image response: \(response)")
                        }
                        
                        // Multi-field daily check
                        PromptCard(configuration: .dailyCheck(dateLabel: "Nov 8", locationLabel: "Miami")) { response in
                            print("Daily check response: \(response)")
                        }
                        
                        // Photo story prompt
                        PromptCard(configuration: .photoStory(prompt: "finishing up my day at on call")) { response in
                            print("Photo story response: \(response)")
                        }
                        
                        // Activity prompt
                        PromptCard(configuration: .activityPrompt(prompt: "into any sports?")) { response in
                            print("Activity response: \(response.textResponses)")
                        }
                        
                        // Custom multi-field prompt with mood selector
                        PromptCard(configuration: customMoodPrompt()) { response in
                            print("Custom mood response: \(response)")
                        }
                        
                        // Rating prompt example
                        PromptCard(configuration: ratingPrompt()) { response in
                            print("Rating response: \(response)")
                        }
                    }

                    // Legacy entries (for backwards compatibility)
                    if !store.entries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Previous Entries")
                                .font(.custom("Fredoka-Medium", size: 20))
                                .foregroundColor(.black)
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
                                    // Use the old PromptCard for existing entries
                                    PromptCard(prompt: entry.prompt, response: entry.response)
                                }
                            }
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
                AddEntryView(store: store) { entry in
                    print("New entry added: \(entry)")
                }
            }
            .alert("Testing Mode Activated!", isPresented: $showTestingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You'll receive prompt notifications every minute for the next 10 minutes. Make sure notifications are enabled!")
            }
        }
    }
    
    private func startTestingMode() {
        // Use a dummy user ID for testing
        let testUserId = "test_user_\(Date().timeIntervalSince1970)"
        UserDefaults.standard.set(testUserId, forKey: "currentUserId")
        
        PromptScheduler.shared.schedulePrompts(for: .testing, influencerId: testUserId) {
            print("🎉 Testing mode activated!")
            showTestingAlert = true
        }
    }
    
    // Custom prompt configurations
    private func customMoodPrompt() -> PromptConfiguration {
        let fields = [
            PromptField(title: "How's your energy?", placeholder: "High, medium, or low?", type: .mood),
            PromptField(title: "What's on your mind?", placeholder: "Share your thoughts...", type: .multiText, isRequired: false),
            PromptField(title: "Location", placeholder: "Where are you?", type: .location, isRequired: false)
        ]
        return PromptConfiguration(
            prompt: "Daily Check-in",
            fields: fields,
            backgroundColor: "pink",
            dateLabel: "Today",
            locationLabel: nil
        )
    }
    
    private func ratingPrompt() -> PromptConfiguration {
        let fields = [
            PromptField(title: "Rate your day", placeholder: "1-5 stars", type: .rating),
            PromptField(title: "Why this rating?", placeholder: "Tell us more...", type: .text, isRequired: false)
        ]
        return PromptConfiguration(
            prompt: "How was your day?",
            fields: fields,
            backgroundColor: "green"
        )
    }
}
