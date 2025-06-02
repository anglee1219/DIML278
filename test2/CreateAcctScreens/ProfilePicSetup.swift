import SwiftUI

struct ProfilePhotoUploadView: View {
    @State private var image: UIImage?
    @State private var showImagePicker = false
    @State private var showActionSheet = false
    @State private var useCamera = false
    @State private var goToNextScreen = false
    @State private var goToPreviousScreen = false
    @State private var showCropPreview = false
    @State private var pendingProfileImage: UIImage?

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
                    get: { pendingProfileImage },
                    set: { if let image = $0 {
                        pendingProfileImage = image
                        showCropPreview = true
                    }
                }))
            }
            .sheet(isPresented: $showCropPreview) {
                if let previewImage = pendingProfileImage {
                    if #available(iOS 16.0, *) {
                        VStack(spacing: 24) {
                            Text("Adjust Your Photo")
                                .font(.title2)
                                .padding(.top)
                            
                            GeometryReader { geometry in
                                ImageAdjustmentView(image: previewImage) { adjustedImage in
                                    image = adjustedImage
                                    pendingProfileImage = nil
                                    showCropPreview = false
                                }
                            }
                            .aspectRatio(1, contentMode: .fit)
                            .padding(.horizontal)
                            
                            Text("Pinch to zoom • Drag to adjust")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Button("Cancel") {
                                pendingProfileImage = nil
                                showCropPreview = false
                            }
                            .foregroundColor(.red)
                            .padding(.bottom)
                        }
                        .padding()
                        .presentationDetents([.height(600)])
                        .background(Color(red: 1, green: 0.989, blue: 0.93))
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
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
