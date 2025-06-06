import SwiftUI
import FirebaseAuth

struct EntryInteractionView: View {
    let entryId: String
    @ObservedObject var entryStore: EntryStore
    let groupMembers: [User]?
    @State private var commentText = ""
    
    init(entryId: String, entryStore: EntryStore, groupMembers: [User]? = nil) {
        self.entryId = entryId
        self.entryStore = entryStore
        self.groupMembers = groupMembers
    }
    
    private var entry: DIMLEntry? {
        entryStore.entries.first { $0.id == entryId }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry?.prompt ?? "")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(entry?.response ?? "")
                        .font(.body)

                    if let image = entry?.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: min(geometry.size.height * 0.3, 200))
                            .cornerRadius(12)
                    } else if let imageURL = entry?.imageURL {
                        AsyncImage(url: URL(string: imageURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: min(geometry.size.height * 0.3, 200))
                                    .cornerRadius(12)
                            case .failure:
                                VStack {
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                    Text("Failed to load image")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .frame(height: min(geometry.size.height * 0.2, 100))
                            case .empty:
                                ProgressView()
                                    .frame(height: min(geometry.size.height * 0.2, 100))
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }

                    // Comments Section
                    Text("Comments (\(entry?.comments.count ?? 0))")
                        .font(.headline)
                    
                    ForEach(entry?.comments ?? []) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                HStack(spacing: 6) {
                                    ProfilePictureView(userId: comment.userId, size: 20, groupMembers: groupMembers)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(getUserName(for: comment.userId))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        Text("@\(getUserUsername(for: comment.userId))")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                                Text(comment.timestamp, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(comment.text)
                                    .font(.subheadline)
                                    .padding(.leading, 26)
                                
                                // Display image if comment has one
                                if let imageData = comment.imageData, let image = UIImage(data: imageData) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: min(geometry.size.height * 0.25, 150))
                                        .cornerRadius(12)
                                        .padding(.leading, 26)
                                } else if let imageURL = comment.imageURL {
                                    AsyncImage(url: URL(string: imageURL)) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFit()
                                                .frame(maxHeight: min(geometry.size.height * 0.25, 150))
                                                .cornerRadius(12)
                                        case .failure:
                                            VStack {
                                                Image(systemName: "photo")
                                                    .foregroundColor(.gray)
                                                Text("Failed to load image")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                            .frame(height: 80)
                                        case .empty:
                                            ProgressView()
                                                .frame(height: 80)
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                    .padding(.leading, 26)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                    }

                    // Comment Input
                    HStack(spacing: 8) {
                        ProfilePictureView(userId: Auth.auth().currentUser?.uid ?? "", size: 28, groupMembers: groupMembers)
                        TextField("Add a comment...", text: $commentText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 36)
                        Button("Post") {
                            guard !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                            
                            let userId = Auth.auth().currentUser?.uid ?? "anonymous"
                            let newComment = Comment(
                                id: UUID().uuidString,
                                userId: userId,
                                text: commentText.trimmingCharacters(in: .whitespacesAndNewlines),
                                timestamp: Date()
                            )
                            
                            print("💬 Adding comment to entry \(entryId): \(commentText)")
                            entryStore.addComment(to: entryId, comment: newComment)
                            commentText = ""
                        }
                        .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, geometry.size.width < 375 ? 12 : 16)
                .padding(.vertical, 12)
                
                // New reaction button positioned in bottom right corner
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ReactionButton(entryId: entryId, entryStore: entryStore, groupMembers: groupMembers)
                            .padding(.trailing, geometry.size.width < 375 ? 12 : 20)
                            .padding(.bottom, geometry.size.width < 375 ? 12 : 20)
                    }
                }
            }
        }
    }
    
    private func getUserName(for userId: String) -> String {
        // Use the same mock system as ProfilePictureView
        let currentUserId = Auth.auth().currentUser?.uid ?? ""
        let currentUserName = SharedProfileViewModel.shared.name
        
        let mockUsers: [String: String] = [
            currentUserId: currentUserName,
            "user_0": "Emma",
            "user_1": "Liam", 
            "user_2": "Olivia",
            "user_3": "Noah",
            "user_4": "Ava",
            "user_5": "Sophia"
        ]
        return mockUsers[userId] ?? "User"
    }
    
    private func getUserUsername(for userId: String) -> String {
        // Generate consistent usernames based on names
        let name = getUserName(for: userId)
        return name.lowercased().replacingOccurrences(of: " ", with: "")
    }
}
