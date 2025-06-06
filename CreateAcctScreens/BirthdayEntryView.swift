NavigationView {
    ScrollView {
        VStack(spacing: 30) {
            Spacer()
                .frame(height: 20)
            
            Image(systemName: "person.2.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("When's your birthday?")
                .font(.custom("Markazi Text", size: 32))
                .foregroundColor(Color(red: 0.969, green: 0.757, blue: 0.224))
                .padding(.bottom, 10)
            
            Text("You must be at least 13 years old to use DIML")
                .font(.custom("Markazi Text", size: 18))
                .foregroundColor(.gray)
            
            // ... existing code ...
            
            // Continue Button
            NavigationLink(destination: UserNameEntryView()) {
                Text("Continue")
                    .font(.custom("Markazi Text", size: 24))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.mainBlue)
                    .cornerRadius(15)
                    .padding(.horizontal, 20)
            }
            .opacity(isValidAge ? 1.0 : 0.3)
            .disabled(!isValidAge)
            
            // Add bottom padding for scroll content
            Spacer()
                .frame(height: 60)
        }
        .padding(.bottom, 20) // Extra bottom padding
    }
} 