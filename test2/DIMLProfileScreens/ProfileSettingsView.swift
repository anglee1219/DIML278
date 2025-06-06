import SwiftUI
import FirebaseAuth

struct ProfileSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authManager = AuthenticationManager.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top Header
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Cancel")
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
                    NavigationLink {
                        AccountPrivacyView()
                            .navigationBarBackButtonHidden(true)
                    } label: {
                        SettingsRow(icon: "gearshape", label: "Account and Privacy")
                    }
                    .listRowBackground(Color(red: 1, green: 0.988, blue: 0.929))

                    NavigationLink {
                        Text("Invite a Friend")
                    } label: {
                        SettingsRow(icon: "person.crop.circle.badge.plus", label: "Invite a Friend")
                    }
                    .listRowBackground(Color(red: 1, green: 0.988, blue: 0.929))

                    Button(action: {
                        print("🔴 Log out button tapped")
                        print("🔴 About to call authManager.signOut()")
                        
                        // Dismiss immediately first
                        dismiss()
                        
                        // Then logout after a brief delay to ensure clean dismissal
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            authManager.signOut()
                            print("🔴 authManager.signOut() completed")
                        }
                    }) {
                        SettingsRow(icon: "arrow.backward.square", label: "Log out", isDestructive: true, showChevron: false)
                    }
                    .listRowBackground(Color(red: 1, green: 0.988, blue: 0.929))
                }
                .listStyle(PlainListStyle())
            }
            .background(Color(red: 1, green: 0.988, blue: 0.929).ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Reusable Row
struct SettingsRow: View {
    var icon: String
    var label: String
    var isDestructive: Bool = false
    var showChevron: Bool = false

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isDestructive ? .red : .gray)

            Text(label)
                .font(.custom("Markazi Text", size: 20))
                .foregroundColor(isDestructive ? .red : .black)

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
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
