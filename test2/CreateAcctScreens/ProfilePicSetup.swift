import SwiftUI

struct ProfilePhotoUploadView: View {
    @State private var image: UIImage?
    @State private var showImagePicker = false
    @State private var showActionSheet = false
    @State private var useCamera = false
    @State private var goToNextScreen = false
    @State private var goToPreviousScreen = false

    var body: some View {
        ZStack {
            Color(red: 1, green: 0.988, blue: 0.929)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Image("DIML_Logo")
                    .resizable()
                    .frame(width: 60, height: 60)

                Button(action: {
                    showActionSheet = true
                }) {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 160, height: 160)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray.opacity(0.4), lineWidth: 2))
                    } else {
                        Image(systemName: "person.crop.circle")
                            .resizable()
                            .frame(width: 160, height: 160)
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }

                Text("Select a Profile Photo")
                    .font(.custom("Markazi Text", size: 18))
                    .foregroundColor(.gray)

                Spacer()

                // Hidden NavLinks for navigation
                NavigationLink(destination: PronounSelectionView(), isActive: $goToNextScreen) { EmptyView() }
                NavigationLink(destination: CreateAccountView(), isActive: $goToPreviousScreen) { EmptyView() }

                // Navigation arrows
                HStack {
                    Button(action: {
                        goToPreviousScreen = true
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                    }

                    Spacer()

                    Button(action: {
                        if image != nil {
                            goToNextScreen = true
                        }
                    }) {
                        Image(systemName: "arrow.right")
                            .font(.title2)
                            .foregroundColor(image != nil ?
                                Color(red: 0.157, green: 0.212, blue: 0.094) :
                                .gray.opacity(0.4))
                    }
                    .disabled(image == nil)
                }
                .padding(.horizontal, 30)
            }
            .padding(.top, 40)
            .confirmationDialog("Choose a photo", isPresented: $showActionSheet, titleVisibility: .visible) {
                Button("Take Photo") {
                    useCamera = true
                    showImagePicker = true
                }
                Button("Choose from Library") {
                    useCamera = false
                    showImagePicker = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: Binding(
                    get: { image },
                    set: { newImage in
                        image = newImage
                    }
                ))
            }
        }
        .navigationBarBackButtonHidden(true) // ← Hides default back arrow
    }
}

struct ProfilePhotoUploadView_Previews: PreviewProvider {
    static var previews: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                ProfilePhotoUploadView()
            }
        } else {
            // Fallback on earlier versions
        }
    }
}
