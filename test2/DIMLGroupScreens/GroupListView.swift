import SwiftUI
// Rebecca's initial
/*struct GroupListView: View {
    @State private var groups: [Group] = []
    @State private var showingCreateGroup = false

    var body: some View {
        NavigationView {
            List {
                ForEach(groups) { group in
                    NavigationLink(destination: GroupDetailView(group: group)) {
                        VStack(alignment: .leading) {
                            Text(group.name)
                                .font(.headline)
                            Text("Influencer: \(group.members.first(where: { $0.id == group.currentInfluencerId })?.name ?? "Unknown")")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("My Groups")
            .navigationBarItems(trailing:
                Button(action: {
                    showingCreateGroup = true
                }) {
                    Image(systemName: "plus")
                }
            )
            .sheet(isPresented: $showingCreateGroup) {
                CreateGroupView { newGroup in
                    groups.append(newGroup)
                }
            }
        }
    }
}
*/
import SwiftUI
//Angela's edits
struct GroupListView: View {
    @State private var groups: [Group] = []
    @State private var showingCreateGroup = false

    var body: some View {
        NavigationView {
            ZStack {
                // Background color
                Color(red: 1, green: 0.989, blue: 0.93)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top Bar
                    ZStack(alignment: .top) {
                        Rectangle()
                            .fill(Color(red: 1, green: 0.988, blue: 0.929))
                            .frame(height: 30)
                            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 4)

                        Image("DIML_Logo")
                            .resizable()
                            .frame(width: 105, height: 105)
                            .clipShape(Circle()) //
                            .offset(y: -60)

                    }

                    // Title and Plus Button
                    HStack {
                        Text("Your Circles")
                            .font(.custom("Markazi Text", size: 32))
                            .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))

                        Spacer()

                        Button(action: {
                            showingCreateGroup = true
                        }) {
                            Image(systemName: "plus.circle")
                                .resizable()
                                .frame(width: 25, height: 25)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, -30)

                    // Search Bar
                    HStack {
                        TextField("Search", text: .constant(""))
                            .padding(5)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(6)

                        Image(systemName: "mic.fill")
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                    Divider()
                        .padding(.top, 10)
                        .padding(.horizontal, 24)

                    // Content Area
                    if groups.isEmpty {
                        Spacer()

                        VStack(spacing: 10) {
                            Image(systemName: "moon.zzz")
                                .resizable()
                                .frame(width: 200, height: 225)
                                .foregroundColor(.gray.opacity(0.4))

                            Text("You have no Circles.")
                                .font(.custom("Fredoka-Regular", size: 22))
                                .fontWeight(.bold)
                                .foregroundColor(.black)

                            Text("Tap the ⊕ in the upper right corner\nto create a Circle!")
                                .multilineTextAlignment(.center)
                                .font(.custom("Markazi Text", size: 18))
                                .foregroundColor(.black)
                        }

                        Spacer()
                    } else {
                        List {
                            ForEach(groups) { group in
                                NavigationLink(destination: GroupDetailView(group: group)) {
                                    VStack(alignment: .leading) {
                                        Text(group.name)
                                            .font(.headline)
                                        Text("Influencer: \(group.members.first(where: { $0.id == group.currentInfluencerId })?.name ?? "Unknown")")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                    }

                    // Bottom Nav Bar
                    HStack {
                        Image(systemName: "house.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.gray)

                        Spacer()

                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .overlay(Text("○"))

                        Spacer()

                        Image(systemName: "person.crop.circle")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 50)
                    .padding(.bottom, 20)
                }
            }
            .sheet(isPresented: $showingCreateGroup) {
                CreateGroupView { newGroup in
                    groups.append(newGroup)
                }
            }
            .navigationBarHidden(true)
        }
    }
}
struct GroupListView_Previews: PreviewProvider {
    static var previews: some View {
        GroupListView()
    }
}
