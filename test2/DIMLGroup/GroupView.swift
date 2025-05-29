import SwiftUI

struct GroupViewWithCompletion: View {
    var onGroupCreated: (Group) -> Void
    @State private var groupName = ""
    @State private var joined = false
    @State private var currentGroup: Group? = nil

    var body: some View {
        VStack(spacing: 20) {
            if joined, let group = currentGroup {
                Text("Welcome to \(group.name)!")
                Button("Continue") {
                    onGroupCreated(group)
                }
            } else {
                TextField("Group Name", text: $groupName)
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)

                Button("Create Group") {
                    let sampleUsers = [
                        User(id: UUID().uuidString, name: "Rebecca"),
                        User(id: UUID().uuidString, name: "Alex"),
                        User(id: UUID().uuidString, name: "Taylor")
                    ]
                    let influencerId = sampleUsers.randomElement()!.id
                    let group = Group(id: UUID().uuidString, name: groupName, members: sampleUsers, currentInfluencerId: influencerId, date: Date())
                    currentGroup = group
                    joined = true
                }
            }
        }
        .padding()
    }
}

