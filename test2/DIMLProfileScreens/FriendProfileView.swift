import SwiftUI

struct FriendProfileView: View {
    let user: SuggestedUser
    @Environment(\.dismiss) var dismiss
    private let profileImageSize: CGFloat = 120
    
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
                
                Text(user.name)
                    .font(.system(size: 20, weight: .semibold))
                
                Spacer()
                
                // Empty view to balance the back button
                Color.clear
                    .frame(width: 24, height: 24)
            }
            .padding()
            .background(Color.white)
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Image Section
                    VStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                            .frame(width: profileImageSize, height: profileImageSize)
                            .overlay(
                                VStack(spacing: 0) {
                                    Spacer()
                                        .frame(height: 25)
                                    
                                    // Head
                                    Circle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                        .frame(width: 40, height: 40)
                                        .padding(.bottom, 4)
                                    
                                    // Body
                                    Circle()
                                        .trim(from: 0, to: 0.5)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                        .frame(width: 65, height: 65)
                                        .rotationEffect(.degrees(180))
                                    
                                    Spacer()
                                        .frame(height: 5)
                                }
                            )
                            .padding(.top, 40)
                    }
                    
                    // Name
                    Text(user.name)
                        .font(.system(size: 32, weight: .bold))
                        .padding(.top, 8)
                    
                    // Username
                    Text(user.username)
                        .font(.system(size: 16))
                        .foregroundColor(.black.opacity(0.6))
                    
                    // Mutual Friends
                    if user.mutualFriends > 0 {
                        Text("\(user.mutualFriends) mutual friend\(user.mutualFriends > 1 ? "s" : "")")
                            .font(.system(size: 16))
                            .foregroundColor(.black.opacity(0.6))
                    }
                    
                    // My Capsule Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Capsule")
                            .font(.system(size: 28, weight: .bold))
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                        
                        VStack(spacing: 0) {
                            Text("May 9th, 2025")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
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
        .background(Color(red: 1, green: 0.989, blue: 0.93).ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

struct FriendProfileView_Previews: PreviewProvider {
    static var previews: some View {
        FriendProfileView(user: sampleSuggestions[0])
    }
} 