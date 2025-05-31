import SwiftUI

struct PronounSelectionView: View {
    @State private var selectedPronoun: String? = nil
    @State private var navigateToBirthday = false
    @State private var navigateBack = false

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

            VStack(spacing: 30) {
                Image("DIML_Logo")
                    .resizable()
                    .frame(width: 60, height: 60)

                Text("What are your pronouns?")
                    .font(.custom("Markazi Text", size: 30))
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.16, green: 0.21, blue: 0.09))

                VStack(spacing: 18) {
                    ForEach(pronouns, id: \.self) { pronoun in
                        Button(action: {
                            selectedPronoun = pronoun
                        }) {
                            Text(pronoun)
                                .font(.custom("Markazi Text", size: 20))
                                .foregroundColor(selectedPronoun == pronoun ? .black : .gray)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedPronoun == pronoun ? Color.black : Color.gray.opacity(0.4), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 30)
                    }
                }

                Spacer()

                // Navigation Links
                NavigationLink(destination: ProfilePhotoUploadView(), isActive: $navigateBack) { EmptyView() }
                NavigationLink(destination: BirthdayEntryView(), isActive: $navigateToBirthday) { EmptyView() }

                HStack {
                    Button(action: {
                        navigateBack = true
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                    }

                    Spacer()

                    Button(action: {
                        navigateToBirthday = true
                    }) {
                        Image(systemName: "arrow.right")
                            .font(.title2)
                            .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                    }
                }
                .padding(.horizontal, 30)
            }
            .padding(.top, 40)
        }
        .navigationBarBackButtonHidden(true) // Hides default nav bar back button
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
