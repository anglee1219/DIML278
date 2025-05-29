import SwiftUI

struct EntryInteractionView: View {
    @State var entry: DIMLEntry
    @State private var commentText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(entry.prompt)
                .font(.caption)
                .foregroundColor(.gray)
            Text(entry.response)
                .font(.body)

            if let image = entry.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(12)
            }

            // Reactions
            HStack {
                ForEach(["❤️", "😂", "👏", "🔥"], id: \.self) { emoji in
                    Button(emoji) {
                        entry.reactions[emoji, default: 0] += 1
                    }
                }
            }

            // Display reaction counts
            HStack {
                ForEach(entry.reactions.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    Text("\(key) \(value)")
                        .font(.caption)
                }
            }

            // Comments Section
            Text("Comments")
                .font(.headline)
            ForEach(entry.comments) { comment in
                VStack(alignment: .leading) {
                    Text(comment.text)
                        .font(.subheadline)
                    Text(comment.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 4)
            }

            // Comment Input
            HStack {
                TextField("Add a comment...", text: $commentText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Post") {
                    let newComment = Comment(id: UUID().uuidString, userId: "me", text: commentText, timestamp: Date())
                    entry.comments.append(newComment)
                    commentText = ""
                }
            }
        }
        .padding()
    }
}
