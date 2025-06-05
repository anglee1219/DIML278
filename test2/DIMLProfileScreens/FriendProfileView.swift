import SwiftUI
import FirebaseFirestore

struct FriendProfileView: View {
    let user: User
    @Environment(\.dismiss) var dismiss
    private let profileImageSize: CGFloat = 120
    private let mainYellow = Color(red: 1.0, green: 0.75, blue: 0)
    
    @State private var fullUserData: User?
    @State private var isLoading = true
    
    // Generate consistent color for user based on their ID
    private func getPlaceholderColor() -> Color {
        return Color.gray.opacity(0.3) // Consistent light grey for all users
    }
    
    var displayUser: User {
        return fullUserData ?? user
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Navigation Bar
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.black)
                        .imageScale(.large)
                }
                
                Spacer()
                
                Text(displayUser.name)
                    .font(.custom("Fredoka-Medium", size: 20))
                
                Spacer()
                
                // Empty view to balance the back button
                Color.clear
                    .frame(width: 24, height: 24)
            }
            .padding()
            .background(Color.white)
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            
            if isLoading {
                // Loading state
                VStack(spacing: 20) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading profile...")
                        .font(.custom("Fredoka-Regular", size: 16))
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Image Section
                        VStack(spacing: 16) {
                            AsyncImage(url: URL(string: displayUser.profileImageUrl ?? "")) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Circle()
                                    .fill(getPlaceholderColor())
                                    .overlay(
                                        Text(displayUser.name.prefix(1).uppercased())
                                            .font(.system(size: 40, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                    )
                            }
                            .frame(width: profileImageSize, height: profileImageSize)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                                    .shadow(color: .gray.opacity(0.3), radius: 8, x: 0, y: 4)
                            )
                            .padding(.top, 40)
                            
                            // Name and pronouns
                            VStack(spacing: 8) {
                                Text(displayUser.name)
                                    .font(.custom("Fredoka-Bold", size: 32))
                                    .multilineTextAlignment(.center)
                                
                                if let pronouns = displayUser.pronouns, !pronouns.isEmpty {
                                    Text("(\(pronouns))")
                                        .font(.custom("Fredoka-Regular", size: 18))
                                        .foregroundColor(.gray)
                                }
                                
                                // Username
                                if let username = displayUser.username, !username.isEmpty {
                                    Text("@\(username)")
                                        .font(.custom("Fredoka-Regular", size: 16))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        // Profile Information Cards
                        VStack(spacing: 16) {
                            // Location Card
                            if let location = displayUser.location, !location.isEmpty {
                                profileInfoCard(
                                    icon: "location.fill",
                                    iconColor: .red,
                                    title: "Location",
                                    value: location
                                )
                            }
                            
                            // School Card
                            if let school = displayUser.school, !school.isEmpty {
                                profileInfoCard(
                                    icon: "graduationcap.fill",
                                    iconColor: .blue,
                                    title: "School",
                                    value: school
                                )
                            }
                            
                            // Zodiac Sign Card
                            if let zodiacSign = displayUser.zodiacSign, !zodiacSign.isEmpty {
                                profileInfoCard(
                                    icon: "sparkles",
                                    iconColor: .purple,
                                    title: "Zodiac Sign",
                                    value: zodiacSign
                                )
                            }
                            
                            // Interests Card
                            if let interests = displayUser.interests, !interests.isEmpty {
                                profileInfoCard(
                                    icon: "heart.fill",
                                    iconColor: mainYellow,
                                    title: "Interests",
                                    value: interests
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        // Capsule Section (placeholder for future functionality)
                        VStack(alignment: .leading, spacing: 16) {
                            Text("\(displayUser.name)'s Capsule")
                                .font(.custom("Fredoka-Bold", size: 24))
                                .padding(.horizontal, 24)
                            
                            VStack(spacing: 0) {
                                VStack(spacing: 12) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 30))
                                        .foregroundColor(.gray.opacity(0.6))
                                    
                                    Text("No DIMLs yet")
                                        .font(.custom("Fredoka-Medium", size: 16))
                                        .foregroundColor(.gray)
                                    
                                    Text("This user hasn't shared any DIMLs yet")
                                        .font(.custom("Fredoka-Regular", size: 14))
                                        .foregroundColor(.gray.opacity(0.8))
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.vertical, 30)
                            }
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
                            .padding(.horizontal, 24)
                        }
                        
                        Spacer(minLength: 80)
                    }
                }
            }
        }
        .background(Color(red: 1, green: 0.989, blue: 0.93).ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            loadFullUserData()
        }
    }
    
    private func profileInfoCard(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 30)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Fredoka-Medium", size: 14))
                    .foregroundColor(.gray)
                
                Text(value)
                    .font(.custom("Fredoka-Regular", size: 16))
                    .foregroundColor(.black)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
    }
    
    private func loadFullUserData() {
        // If we already have full data, no need to fetch again
        if user.profileImageUrl != nil && user.pronouns != nil {
            fullUserData = user
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        
        db.collection("users").document(user.id).getDocument { document, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("❌ Error fetching full user profile: \(error.localizedDescription)")
                    self.fullUserData = user // Use whatever data we have
                    return
                }
                
                guard let document = document,
                      document.exists,
                      let data = document.data() else {
                    print("❌ No user document found for profile view")
                    self.fullUserData = user // Use whatever data we have
                    return
                }
                
                // Create enhanced User object with all available data
                self.fullUserData = User(
                    id: user.id,
                    name: data["name"] as? String ?? user.name,
                    username: data["username"] as? String ?? user.username,
                    email: data["email"] as? String ?? user.email,
                    role: user.role,
                    profileImageUrl: data["profileImageURL"] as? String,
                    pronouns: data["pronouns"] as? String,
                    zodiacSign: data["zodiacSign"] as? String,
                    location: data["location"] as? String,
                    school: data["school"] as? String,
                    interests: data["interests"] as? String
                )
                
                print("✅ Loaded full profile data for: \(self.fullUserData?.name ?? "Unknown")")
                if let imageURL = self.fullUserData?.profileImageUrl, !imageURL.isEmpty {
                    print("📸 Profile has image URL: \(imageURL)")
                } else {
                    print("📸 Profile has no image URL")
                }
            }
        }
    }
}

// MARK: - Convenience initializer for SuggestedUser compatibility
extension FriendProfileView {
    init(suggestedUser: SuggestedUser) {
        self.init(user: User(
            id: UUID().uuidString, // This should ideally be passed from the suggested user
            name: suggestedUser.name,
            username: suggestedUser.username,
            role: .member
        ))
    }
}

struct FriendProfileView_Previews: PreviewProvider {
    static var previews: some View {
        FriendProfileView(user: User(
            id: "preview",
            name: "Sarah Chen",
            username: "sarahc",
            email: "sarah@example.com",
            role: .member,
            profileImageUrl: nil,
            pronouns: "she/her",
            zodiacSign: "Gemini",
            location: "San Francisco, CA",
            school: "UC Berkeley",
            interests: "Photography, hiking, coffee"
        ))
    }
} 