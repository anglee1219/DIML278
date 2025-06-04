import SwiftUI
import CoreLocation
import UserNotifications

// MARK: - Prompt Configuration Models

enum PromptInputType: String, CaseIterable, Codable {
    case text = "text"
    case multiText = "multiText"
    case image = "image"
    case video = "video"
    case location = "location"
    case mood = "mood"
    case rating = "rating"
    case time = "time"
    case date = "date"
}

struct PromptField: Identifiable, Codable {
    let id: UUID
    let title: String
    let placeholder: String
    let type: PromptInputType
    let isRequired: Bool
    let maxLength: Int?
    
    init(title: String, placeholder: String, type: PromptInputType, isRequired: Bool = true, maxLength: Int? = nil) {
        self.id = UUID()
        self.title = title
        self.placeholder = placeholder
        self.type = type
        self.isRequired = isRequired
        self.maxLength = maxLength
    }
}

struct PromptConfiguration: Identifiable, Codable {
    let id: UUID
    let prompt: String
    let fields: [PromptField]
    let backgroundColor: String
    let dateLabel: String?
    let locationLabel: String?
    let imageURL: String?
    let frameSize: FrameSize?
    
    init(prompt: String, fields: [PromptField], backgroundColor: String = "cream", dateLabel: String? = nil, locationLabel: String? = nil, imageURL: String? = nil, frameSize: FrameSize? = nil) {
        self.id = UUID()
        self.prompt = prompt
        self.fields = fields
        self.backgroundColor = backgroundColor
        self.dateLabel = dateLabel
        self.locationLabel = locationLabel
        self.imageURL = imageURL
        self.frameSize = frameSize
    }
}

// MARK: - Response Data Models

struct PromptResponse: Codable {
    var textResponses: [String: String] = [:]
    var imageURL: String?
    var videoURL: String?
    var location: String?
    var mood: String?
    var rating: Int?
    var date: Date?
    var time: Date?
}

// MARK: - Enhanced Prompt Card

struct PromptCard: View {
    let configuration: PromptConfiguration
    @State private var response = PromptResponse()
    @State private var showingLocationPicker = false
    @State private var currentDate = Date()
    @State private var isEditingLocation = false
    @State private var editableLocation: String = ""
    @State private var cameraBounce = false
    
    let onComplete: ((PromptResponse) -> Void)?
    
    init(configuration: PromptConfiguration, onComplete: ((PromptResponse) -> Void)? = nil) {
        self.configuration = configuration
        self.onComplete = onComplete
    }
    
    // Convenience initializer for simple text prompts (backwards compatibility)
    init(prompt: String, response: String) {
        let textField = PromptField(title: "", placeholder: "Your response...", type: .text)
        self.configuration = PromptConfiguration(prompt: prompt, fields: [textField])
        self.onComplete = nil
        self._response = State(initialValue: PromptResponse())
        self.response.textResponses[""] = response
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with date/location if provided
            if configuration.dateLabel != nil || configuration.locationLabel != nil {
                headerView
            }
            
            // Check if this is an image prompt (no input fields)
            let isImagePrompt = configuration.fields.isEmpty
            
            if isImagePrompt {
                // IMAGE PROMPT: Taller layout with bouncing camera
                imagePromptView
            } else {
                // TEXT PROMPT: Standard layout with form fields
                textPromptView
            }
        }
        .frame(maxWidth: .infinity) // Ensure consistent full width
        .background(backgroundColorView)
        .cornerRadius(15)
        .padding(.horizontal, 20) // Small consistent gaps on both sides
        .onAppear {
            if configuration.fields.isEmpty {
                startCameraBounceAnimation()
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack(spacing: 12) {
            if let dateLabel = configuration.dateLabel {
                // Date bubble (non-editable)
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .foregroundColor(.white)
                    Text(dateLabel)
                        .font(.custom("Fredoka-Medium", size: 14))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .cornerRadius(20)
            }
            
            if let locationLabel = configuration.locationLabel {
                // Editable location bubble
                if isEditingLocation {
                    HStack(spacing: 6) {
                        Image(systemName: "location")
                            .foregroundColor(.white)
                        TextField("tell us wya? 👀", text: $editableLocation)
                            .font(.custom("Fredoka-Medium", size: 14))
                            .foregroundColor(.white)
                            .textFieldStyle(PlainTextFieldStyle())
                            .submitLabel(.done)
                            .onSubmit {
                                isEditingLocation = false
                            }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(20)
                    .onAppear {
                        // Initialize with empty text for user input
                        editableLocation = ""
                    }
                } else {
                    Button(action: {
                        editableLocation = ""
                        isEditingLocation = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "location")
                                .foregroundColor(.white)
                            Text(editableLocation.isEmpty ? locationLabel : editableLocation)
                                .font(.custom("Fredoka-Medium", size: 14))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(20)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    // MARK: - Image Prompt View
    
    private var imagePromptView: some View {
        VStack(spacing: 20) {
            // Prompt text
            Text(configuration.prompt)
                .font(.custom("Fredoka-Medium", size: 18))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.top, 30)
            
            if let imageURL = configuration.imageURL, let frameSize = configuration.frameSize, onComplete == nil {
                // This is a completed entry - show the actual image
                AsyncImage(url: URL(string: imageURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: frameSize.height)
                            .cornerRadius(12)
                            .clipped()
                    case .failure(_):
                        VStack {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                            Text("Failed to load image")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(height: frameSize.height)
                    case .empty:
                        ProgressView()
                            .frame(height: frameSize.height)
                    @unknown default:
                        EmptyView()
                    }
                }
                .padding(.horizontal, 20)
            } else {
                // This is an active prompt - show camera instruction
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("Take a photo")
                        .font(.custom("Fredoka-Regular", size: 16))
                        .foregroundColor(.gray)
                    
                    Text("💡 Use the camera button below")
                        .font(.custom("Fredoka-Regular", size: 12))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity, minHeight: 200) // Full width and taller layout
    }
    
    // MARK: - Text Prompt View
    
    private var textPromptView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Prompt text
            if !configuration.prompt.isEmpty {
                Text(configuration.prompt)
                    .font(.custom("Fredoka-Medium", size: 16))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
            }
            
            // Dynamic fields based on configuration
            ForEach(configuration.fields) { field in
                fieldView(for: field)
            }
            
            // Submit button for forms with fields
            if !configuration.fields.isEmpty && onComplete != nil {
                submitButton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading) // Full width with leading alignment
        .padding(.bottom, 16)
    }
    
    // MARK: - Field Views
    
    @ViewBuilder
    private func fieldView(for field: PromptField) -> some View {
        switch field.type {
        case .text:
            textFieldView(for: field)
        case .multiText:
            multiTextFieldView(for: field)
        case .image:
            imageFieldView(for: field)
        case .video:
            videoFieldView(for: field)
        case .location:
            locationFieldView(for: field)
        case .mood:
            moodFieldView(for: field)
        case .rating:
            ratingFieldView(for: field)
        case .time:
            timeFieldView(for: field)
        case .date:
            dateFieldView(for: field)
        }
    }
    
    private func textFieldView(for field: PromptField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !field.title.isEmpty {
                Text(field.title)
                    .font(.custom("Fredoka-Regular", size: 14))
                    .foregroundColor(.black)
            }
            
            if onComplete == nil {
                // This is a completed entry - show response text in card color
                Text(field.placeholder)
                    .font(.custom("Fredoka-Regular", size: 16))
                    .foregroundColor(getTextColorForBackground())
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            } else {
                // This is an active prompt - show input field
                TextField(field.placeholder, text: Binding(
                    get: { response.textResponses[field.title] ?? "" },
                    set: { response.textResponses[field.title] = $0 }
                ))
                .font(.custom("Fredoka-Regular", size: 16))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 16)
    }
    
    // Helper function to get text color that contrasts with background
    private func getTextColorForBackground() -> Color {
        switch configuration.backgroundColor {
        case "blue":
            return Color.blue.opacity(0.8) // Darker blue for blue background
        case "green":
            return Color.gray.opacity(0.7) // Darker grey for grey background
        case "cream", "pink":
            return Color(red: 1.0, green: 0.815, blue: 0.0).opacity(0.8) // Darker yellow for yellow backgrounds
        default:
            return Color(red: 1.0, green: 0.815, blue: 0.0).opacity(0.8) // Default to darker yellow
        }
    }
    
    private func multiTextFieldView(for field: PromptField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !field.title.isEmpty {
                Text(field.title)
                    .font(.custom("Fredoka-Regular", size: 14))
                    .foregroundColor(.black)
            }
            
            if onComplete == nil {
                // This is a completed entry - show response text in card color
                Text(field.placeholder)
                    .font(.custom("Fredoka-Regular", size: 16))
                    .foregroundColor(getTextColorForBackground())
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            } else {
                // This is an active prompt - show input field
                if #available(iOS 16.0, *) {
                    TextField(field.placeholder, text: Binding(
                        get: { response.textResponses[field.title] ?? "" },
                        set: { response.textResponses[field.title] = $0 }
                    ), axis: .vertical)
                    .font(.custom("Fredoka-Regular", size: 16))
                    .lineLimit(3...6)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )
                } else {
                    TextEditor(text: Binding(
                        get: { response.textResponses[field.title] ?? "" },
                        set: { response.textResponses[field.title] = $0 }
                    ))
                    .font(.custom("Fredoka-Regular", size: 16))
                    .frame(minHeight: 80)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    private func imageFieldView(for field: PromptField) -> some View {
        // For image prompts, just show as text field - users will use camera button
        VStack(alignment: .leading, spacing: 8) {
            if !field.title.isEmpty {
                Text(field.title)
                    .font(.custom("Fredoka-Regular", size: 14))
                    .foregroundColor(.black)
            }
            
            TextField(field.placeholder, text: Binding(
                get: { response.textResponses[field.title] ?? "" },
                set: { response.textResponses[field.title] = $0 }
            ))
            .font(.custom("Fredoka-Regular", size: 16))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
    }
    
    private func videoFieldView(for field: PromptField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !field.title.isEmpty {
                Text(field.title)
                    .font(.custom("Fredoka-Regular", size: 14))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
            }
            
            Button(action: {
                // Implement video picker
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                    Text(field.placeholder)
                        .font(.custom("Fredoka-Regular", size: 14))
                        .foregroundColor(.gray)
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                )
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func locationFieldView(for field: PromptField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !field.title.isEmpty {
                Text(field.title)
                    .font(.custom("Fredoka-Regular", size: 14))
                    .foregroundColor(.black)
            }
            
            Button(action: {
                showingLocationPicker = true
            }) {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.gray)
                    Text(response.location ?? field.placeholder)
                        .font(.custom("Fredoka-Regular", size: 16))
                        .foregroundColor(response.location != nil ? .black : .gray)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 16)
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView(selectedLocation: Binding(
                get: { response.location ?? "" },
                set: { response.location = $0 }
            ))
        }
    }
    
    private func moodFieldView(for field: PromptField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !field.title.isEmpty {
                Text(field.title)
                    .font(.custom("Fredoka-Regular", size: 14))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(moodOptions, id: \.self) { mood in
                        Button(action: {
                            response.mood = mood
                        }) {
                            Text(mood)
                                .font(.custom("Fredoka-Regular", size: 14))
                                .foregroundColor(response.mood == mood ? .white : .black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(response.mood == mood ? Color.blue : Color.white)
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func ratingFieldView(for field: PromptField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !field.title.isEmpty {
                Text(field.title)
                    .font(.custom("Fredoka-Regular", size: 14))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
            }
            
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { rating in
                    Button(action: {
                        response.rating = rating
                    }) {
                        Image(systemName: rating <= (response.rating ?? 0) ? "star.fill" : "star")
                            .foregroundColor(rating <= (response.rating ?? 0) ? .yellow : .gray)
                            .font(.system(size: 24))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func timeFieldView(for field: PromptField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !field.title.isEmpty {
                Text(field.title)
                    .font(.custom("Fredoka-Regular", size: 14))
                    .foregroundColor(.black)
            }
            
            DatePicker(
                "",
                selection: Binding(
                    get: { response.time ?? Date() },
                    set: { response.time = $0 }
                ),
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(CompactDatePickerStyle())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white)
            .cornerRadius(10)
        }
        .padding(.horizontal, 16)
    }
    
    private func dateFieldView(for field: PromptField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !field.title.isEmpty {
                Text(field.title)
                    .font(.custom("Fredoka-Regular", size: 14))
                    .foregroundColor(.black)
            }
            
            DatePicker(
                "",
                selection: Binding(
                    get: { response.date ?? Date() },
                    set: { response.date = $0 }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(CompactDatePickerStyle())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white)
            .cornerRadius(10)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Submit Button
    
    private var submitButton: some View {
        Button(action: {
            // Include edited location in response if it exists
            if !editableLocation.isEmpty && editableLocation != configuration.locationLabel {
                response.location = editableLocation
            }
            onComplete?(response)
        }) {
            HStack {
                Image(systemName: "checkmark")
                    .foregroundColor(.white)
                Text("Submit")
                    .font(.custom("Fredoka-Medium", size: 16))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(10)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Helper Views and Data
    
    private var backgroundColorView: some View {
        switch configuration.backgroundColor {
        case "cream":
            return Color(red: 1.0, green: 0.815, blue: 0.0).opacity(0.15) // Main yellow with low opacity
        case "blue":
            return Color.blue.opacity(0.1) // Main blue with low opacity
        case "green":
            return Color.gray.opacity(0.08) // Grey with very low opacity
        case "pink":
            return Color(red: 1.0, green: 0.815, blue: 0.0).opacity(0.25) // Main yellow with medium opacity
        default:
            return Color(red: 1.0, green: 0.815, blue: 0.0).opacity(0.15) // Default to main yellow
        }
    }
    
    private let moodOptions = [
        "excited", "happy", "calm", "focused", "tired", "stressed", "anxious", "grateful", "motivated", "creative"
    ]
    
    // MARK: - Animation Functions
    
    private func startCameraBounceAnimation() {
        cameraBounce = true
    }
}

// MARK: - Location Picker

struct LocationPickerView: View {
    @Binding var selectedLocation: String
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    private let commonLocations = [
        "Home", "Work", "School", "Gym", "Coffee Shop", "Library", "Park", "Restaurant", "Mall", "Beach"
    ]
    
    var filteredLocations: [String] {
        if searchText.isEmpty {
            return commonLocations
        }
        return commonLocations.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                LocationSearchBar(text: $searchText)
                    .padding()
                
                List {
                    ForEach(filteredLocations, id: \.self) { location in
                        Button(action: {
                            selectedLocation = location
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.blue)
                                Text(location)
                                    .foregroundColor(.black)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
        }
    }
}

// MARK: - Location Search Bar

struct LocationSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search locations...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Example Configurations

extension PromptConfiguration {
    // Simple text prompt (like "what does your typical morning look like?")
    static func simpleText(prompt: String) -> PromptConfiguration {
        let field = PromptField(title: "", placeholder: "Your response...", type: .text)
        return PromptConfiguration(prompt: prompt, fields: [field])
    }
    
    // Image with text prompt (like "campus views")
    static func imageWithText(prompt: String) -> PromptConfiguration {
        let fields = [
            PromptField(title: "", placeholder: "Add a photo", type: .image),
            PromptField(title: "", placeholder: "Add your thoughts...", type: .text, isRequired: false)
        ]
        return PromptConfiguration(prompt: prompt, fields: fields, backgroundColor: "blue")
    }
    
    // Multi-field prompt (like the mood + simple pleasure example)
    static func dailyCheck(dateLabel: String, locationLabel: String) -> PromptConfiguration {
        let fields = [
            PromptField(title: "current mood", placeholder: "how are you feeling?", type: .text),
            PromptField(title: "my simple pleasure", placeholder: "what made you smile today?", type: .text)
        ]
        return PromptConfiguration(
            prompt: "",
            fields: fields,
            backgroundColor: "cream",
            dateLabel: dateLabel,
            locationLabel: locationLabel
        )
    }
    
    // Sports/activity prompt
    static func activityPrompt(prompt: String) -> PromptConfiguration {
        let field = PromptField(title: "", placeholder: "Tell us about it...", type: .text)
        return PromptConfiguration(prompt: prompt, fields: [field])
    }
    
    // Photo with description
    static func photoStory(prompt: String) -> PromptConfiguration {
        let fields = [
            PromptField(title: "", placeholder: "Take a photo", type: .image),
            PromptField(title: "", placeholder: "What's happening here?", type: .multiText, isRequired: false)
        ]
        return PromptConfiguration(prompt: prompt, fields: fields, backgroundColor: "green")
    }
}

// MARK: - Preview

struct PromptCard_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Simple text prompt
                PromptCard(configuration: .simpleText(prompt: "what does your typical morning look like?"))
                
                // Image with text
                PromptCard(configuration: .imageWithText(prompt: "campus views"))
                
                // Daily check with date and location
                PromptCard(configuration: .dailyCheck(dateLabel: "Nov 8", locationLabel: "Miami"))
                
                // Photo story
                PromptCard(configuration: .photoStory(prompt: "finishing up my day at on call"))
                
                // Activity prompt
                PromptCard(configuration: .activityPrompt(prompt: "into any sports?"))
                
                // Custom mood prompt
                PromptCard(configuration: customMoodPrompt())
                
                // Rating prompt
                PromptCard(configuration: ratingPrompt())
        }
        .padding()
        }
        .background(Color(red: 1, green: 0.989, blue: 0.93))
    }
    
    static func customMoodPrompt() -> PromptConfiguration {
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
    
    static func ratingPrompt() -> PromptConfiguration {
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
