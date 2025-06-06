var body: some View {
    ZStack {
        VStack(spacing: 0) {
            TopNavBar(showsMenu: true, onMenu: {
                showSettings = true
            })
            
            ScrollView {
                VStack(spacing: 20) { // Reduced from 24 to 20
                    // Add top padding for smaller screens
                    Spacer()
                        .frame(height: 10)
                    
                    // Profile Image Section
                    VStack {
                        ZStack(alignment: .topTrailing) {
                            if let profileImage = viewModel.profileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: profileImageSize, height: profileImageSize)
                                    .clipShape(Circle())
                            } else {
                                // ... existing code ...
                            }
                        }
                    }
                }
                
                // My Capsule Section
                if let capsule = viewModel.capsule {
                    NavigationLink(destination: MyCapsuleView(capsule: capsule)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("My Capsule")
                                .font(.custom("Fredoka-Medium", size: 20))
                                .foregroundColor(.black)
                            
                            if !capsule.entries.isEmpty {
                                let previewEntry = capsule.entries[0]
                                Text(previewEntry.prompt)
                                    .font(.custom("Fredoka-Regular", size: 14))
                                    .foregroundColor(.gray)
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
                        .padding(.horizontal, 24)
                    }
                }
                
                // Add bottom padding for smaller screens
                Spacer()
                    .frame(height: 40)
                }
                .padding(.bottom, 20) // Extra bottom padding for scroll content
            }
        }
    }
} 