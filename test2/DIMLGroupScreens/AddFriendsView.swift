import SwiftUI


struct AddFriendsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var addedFriends: Set<String> = []
    private let mainYellow = Color(red: 1.0, green: 0.75, blue: 0)

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            searchBar
            findFriendsTitle
            suggestionsList
        }
        .background(Color(red: 1, green: 0.989, blue: 0.93).ignoresSafeArea())
    }

    // MARK: - Header
    private var headerBar: some View {
        ZStack {
            Rectangle()
                .fill(Color.white)
                .frame(height: 50)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.orange)

                Spacer()

                Text("Add Friends")
                    .font(.custom("Fredoka-Regular", size: 20))
                    .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))

                Spacer()

                Text("     ") // Balance spacer
                    .foregroundColor(.clear)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            Text("Search friends…")
                .foregroundColor(.gray)
            Spacer()
        }
        .padding()
        .background(Color(red: 0.95, green: 0.95, blue: 0.9))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Title
    private var findFriendsTitle: some View {
        Text("Find Friends")
            .font(.custom("Markazi Text", size: 28))
            .bold()
            .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0))
            .padding(.horizontal)
            .padding(.top, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Suggested Friends List
    private var suggestionsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    ForEach(sampleSuggestions.indices, id: \.self) { index in
                        friendRow(person: sampleSuggestions[index])

                        if index < sampleSuggestions.count - 1 {
                            Divider()
                                .padding(.horizontal)
                                .background(Color.gray.opacity(0.2))
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
                .padding()
            }
        }
    }

    // MARK: - Row UI
    private func friendRow(person: SuggestedUser) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(Text(person.name.prefix(1)).font(.headline))

            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.custom("Fredoka-Regular", size: 16))

                Text(person.username)
                    .font(.caption)
                    .foregroundColor(.gray)

                Text(person.source)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 4)

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    if addedFriends.contains(person.username) {
                        addedFriends.remove(person.username)
                    } else {
                        addedFriends.insert(person.username)
                    }
                }
            }) {
                HStack(spacing: 4) {
                    Text(addedFriends.contains(person.username) ? "Added" : "Add Friend")
                    Image(systemName: addedFriends.contains(person.username) ? "checkmark" : "person.badge.plus")
                }
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(addedFriends.contains(person.username) ? mainYellow : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .scaleEffect(addedFriends.contains(person.username) ? 0.95 : 1.0)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
    }
}

// MARK: - Preview
struct AddFriendsView_Previews: PreviewProvider {
    static var previews: some View {
        AddFriendsView()
    }
}
