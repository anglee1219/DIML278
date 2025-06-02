import SwiftUI

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated: Bool {
        didSet {
            UserDefaults.standard.set(isAuthenticated, forKey: "isAuthenticated")
            if !isAuthenticated {
                // Clear user data when logging out
                UserDefaults.standard.removeObject(forKey: "profile_name")
                UserDefaults.standard.removeObject(forKey: "profile_username")
                UserDefaults.standard.removeObject(forKey: "profile_pronouns")
                UserDefaults.standard.removeObject(forKey: "profile_zodiac")
                UserDefaults.standard.removeObject(forKey: "profile_location")
                UserDefaults.standard.removeObject(forKey: "profile_school")
                UserDefaults.standard.removeObject(forKey: "profile_interests")
                UserDefaults.standard.removeObject(forKey: "profile_image")
                UserDefaults.standard.removeObject(forKey: "privacy_show_location")
                UserDefaults.standard.removeObject(forKey: "privacy_show_school")
                
                // Reset root view to login screen
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController = UIHostingController(rootView: 
                        NavigationView {
                            LoginScreen()
                        }
                    )
                }
            }
        }
    }
    
    static let shared = AuthenticationManager()
    
    init() {
        self.isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
    }
    
    func signOut() {
        isAuthenticated = false
    }
}

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

                    NavigationLink {
                        Text("Invite a Friend")
                    } label: {
                        SettingsRow(icon: "person.crop.circle.badge.plus", label: "Invite a Friend")
                    }

                    Button(action: {
                        dismiss() // Dismiss the settings sheet first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            authManager.signOut() // Then sign out
                        }
                    }) {
                        SettingsRow(icon: "arrow.backward.square", label: "Log out", isDestructive: true, showChevron: false)
                    }
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
                .foregroundColor(isDestructive ? .red : Color(red: 0.157, green: 0.212, blue: 0.094))

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
