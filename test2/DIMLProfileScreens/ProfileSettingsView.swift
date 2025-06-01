import SwiftUI

struct ProfileSettingsView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Top Header
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Text("Back")
                        .foregroundColor(.orange)
                        .font(.custom("Markazi Text", size: 20))
                }

                Spacer()

                Text("Settings")
                    .font(.custom("Markazi Text", size: 24))
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))

                Spacer()

                // Empty for symmetry
                Spacer().frame(width: 50)
            }
            .padding()
            .background(Color(red: 1, green: 0.988, blue: 0.929))
            .overlay(
                Divider()
                    .background(Color.gray.opacity(0.3)),
                alignment: .bottom
            )

            // Settings Options
            List {
                NavigationLink(destination: Text("Account and Privacy")) {
                    SettingsRow(icon: "gearshape", label: "Account and Privacy")
                }

                NavigationLink(destination: Text("Invite a Friend")) {
                    SettingsRow(icon: "person.crop.circle.badge.plus", label: "Invite a Friend")
                }

                Button(action: {
                    // Add logout logic here
                    print("User logged out")
                }) {
                    SettingsRow(icon: "arrow.backward.square", label: "Log out", isDestructive: true)
                }
            }
            .listStyle(PlainListStyle())
        }
        .background(Color(red: 1, green: 0.988, blue: 0.929).ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

// MARK: - Reusable Row
struct SettingsRow: View {
    var icon: String
    var label: String
    var isDestructive: Bool = false

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isDestructive ? .red : .gray)

            Text(label)
                .font(.custom("Markazi Text", size: 20))
                .foregroundColor(isDestructive ? .red : Color(red: 0.157, green: 0.212, blue: 0.094))

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview
struct ProfileSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                ProfileSettingsView()
            }
        } else {
            // Fallback on earlier versions
        }
    }
}
