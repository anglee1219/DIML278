import SwiftUI

struct GroupDetailView: View {
    var group: Group
    @StateObject var store = EntryStore()
    @State private var goToDIML = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Group: \(group.name)")
                .font(.title2)
                .padding()

            Text("Today's Influencer:")
                .font(.headline)
            Text(group.members.first { $0.id == group.currentInfluencerId }?.name ?? "Unknown")
                .font(.title3)
                .bold()

            List {
                ForEach(group.members, id: \.id) { member in
                    Text(member.name)
                }
            }

            Button("Enter Group Feed") {
                goToDIML = true
            }
            .padding()

            NavigationLink(destination: DIMLView(store: store, group: group), isActive: $goToDIML) {
                EmptyView()
            }
        }
        .navigationTitle("Group Info")
    }
}

