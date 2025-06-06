import SwiftUI

struct PronounSelectionView: View {
    @State private var selectedPronoun: String? = nil
    @State private var navigateToBirthday = false
    @State private var navigateBack = false
    @StateObject private var profileViewModel = ProfileViewModel.shared

    let pronouns = [
        "she/her",
        "he/him",
        "they/them",
        "other",
        "prefer not to answer"
    ]

    var body: some View {
        ZStack {
            Color(red: 1, green: 0.988, blue: 0.929)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {
                    Spacer()
                        .frame(height: 20)
                    
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("What are your pronouns?")
                        .font(.custom("Markazi Text", size: 32))
                        .foregroundColor(Color(red: 0.969, green: 0.757, blue: 0.224))
                        .padding(.bottom, 20)

                    VStack(spacing: 16) {
                        ForEach(pronouns, id: \.self) { pronoun in
                            Button(action: {
                                selectedPronoun = pronoun
                                // Save to both UserDefaults and ProfileViewModel
                                UserDefaults.standard.set(pronoun, forKey: "profile_pronouns")
                                profileViewModel.pronouns = pronoun
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color.white)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 15)
                                                .stroke(selectedPronoun == pronoun ? Color.mainBlue : Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                    
                                    Text(pronoun)
                                        .font(.custom("Markazi Text", size: 24))
                                        .foregroundColor(selectedPronoun == pronoun ? Color.mainBlue : Color.gray)
                                }
                                .frame(height: 56)
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    NavigationLink(destination: ProfilePicSetup(), isActive: $navigateBack) { EmptyView() }
                    NavigationLink(destination: BirthdayEntryView(), isActive: $navigateToBirthday) { EmptyView() }

                    HStack {
                        Button(action: {
                            navigateBack = true
                        }) {
                            Image(systemName: "arrow.left")
                                .font(.title)
                                .foregroundColor(Color.mainBlue)
                        }

                        Spacer()

                        Button(action: {
                            if let pronoun = selectedPronoun {
                                // Save again before navigating to ensure it's saved
                                UserDefaults.standard.set(pronoun, forKey: "profile_pronouns")
                                profileViewModel.pronouns = pronoun
                                navigateToBirthday = true
                            }
                        }) {
                            Image(systemName: "arrow.right")
                                .font(.title)
                                .foregroundColor(selectedPronoun != nil ? Color.mainBlue : .gray)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    
                    Spacer()
                        .frame(height: 60)
                }
                .padding(.bottom, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Load any previously saved pronoun
            if let savedPronoun = UserDefaults.standard.string(forKey: "profile_pronouns") {
                selectedPronoun = savedPronoun
                profileViewModel.pronouns = savedPronoun
            }
        }
    }
}

#Preview {
    if #available(iOS 16.0, *) {
        NavigationStack {
            PronounSelectionView()
        }
    } else {
        // Fallback on earlier versions
    }
}
