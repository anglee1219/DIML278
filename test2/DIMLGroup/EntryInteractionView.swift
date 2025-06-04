import SwiftUI
import FirebaseAuth

struct EntryInteractionView: View {
    let entryId: String
    @ObservedObject var entryStore: EntryStore
    @State private var commentText = ""
    
    private var entry: DIMLEntry? {
        entryStore.entries.first { $0.id == entryId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(entry?.prompt ?? "")
                .font(.caption)
                .foregroundColor(.gray)
            Text(entry?.response ?? "")
                .font(.body)

            if let image = entry?.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(12)
            } else if let imageURL = entry?.imageURL {
                AsyncImage(url: URL(string: imageURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .cornerRadius(12)
                    case .failure:
                        VStack {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                            Text("Failed to load image")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(height: 200)
                    case .empty:
                        ProgressView()
                            .frame(height: 200)
                    @unknown default:
                        EmptyView()
                    }
                }
            }

            // Reactions
            HStack {
                ForEach(["❤️", "😂", "👏", "🔥"], id: \.self) { emoji in
                    Button(action: {
                        print("💬 Adding reaction \(emoji) to entry \(entryId)")
                        entryStore.addReaction(to: entryId, reaction: emoji)
                    }) {
                        HStack(spacing: 4) {
                            Text(emoji)
                            Text("\(entry?.reactions[emoji, default: 0] ?? 0)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }

            // Comments Section
            Text("Comments (\(entry?.comments.count ?? 0))")
                .font(.headline)
            ForEach(entry?.comments ?? []) { comment in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(comment.userId)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        Spacer()
                        Text(comment.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Text(comment.text)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }

            // Comment Input
            HStack {
                TextField("Add a comment...", text: $commentText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
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
        }
        .padding()
    }
}
