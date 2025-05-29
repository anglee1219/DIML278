import SwiftUI

struct PromptCard: View {
    var prompt: String
    var response: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(prompt)
                .font(.caption)
                .foregroundColor(.gray)
            Text(response)
                .font(.body)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(15)
    }
}
