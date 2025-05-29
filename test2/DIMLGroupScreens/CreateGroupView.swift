import SwiftUI

struct CreateGroupView: View {
    var onGroupCreated: (Group) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var groupName = ""
    @State private var newMembers: [User] = []
    @State private var memberName = ""
    @State private var memberPhone = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Group Name")) {
                    TextField("Enter group name", text: $groupName)
                }

                Section(header: Text("Add Members")) {
                    VStack {
                        TextField("Name", text: $memberName)
                        TextField("Phone", text: $memberPhone)
                            .keyboardType(.phonePad)
                        Button("Add Member") {
                            let newUser = User(id: UUID().uuidString, name: memberName)
                            newMembers.append(newUser)
                            memberName = ""
                            memberPhone = ""
                        }
                    }

                    ForEach(newMembers, id: \.id) { member in
                        Text(member.name)
                    }
                }
            }
            .navigationTitle("Create Group")
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            }, trailing: Button("Create") {
                let influencerId = newMembers.randomElement()?.id ?? UUID().uuidString
                let newGroup = Group(id: UUID().uuidString, name: groupName, members: newMembers, currentInfluencerId: influencerId, date: Date())
                onGroupCreated(newGroup)
                dismiss()
            }.disabled(groupName.isEmpty || newMembers.isEmpty))
        }
    }
}
