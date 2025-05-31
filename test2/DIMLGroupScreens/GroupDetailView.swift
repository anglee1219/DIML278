/*import SwiftUI

struct GroupDetailView: View {
    var group: Group
    @StateObject var store = EntryStore()
    @State private var goToDIML = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Group: \(group.name)")
                .font(.title2)
                .padding()

            Text("Today's Influencer:")
                .font(.headline)
            Text(group.members.first { $0.id == group.currentInfluencerId }?.name ?? "Unknown")
                .font(.title3)
                .bold()

            List {
                ForEach(group.members, id: \.id) { member in
                    Text(member.name)
                }
            }

            Button("Enter Group Feed") {
                goToDIML = true
            }
            .padding()

            NavigationLink(destination: DIMLView(store: store, group: group), isActive: $goToDIML) {
                EmptyView()
            }
        }
        .navigationTitle("Group Info")
    }
}

*/
import SwiftUI
import AVFoundation

struct GroupDetailView: View {
    var group: Group
    @StateObject var store = EntryStore()
    @State private var goToDIML = false
    @State private var showCamera = false
    @State private var showPermissionAlert = false
    @Environment(\.dismiss) private var dismiss
    @State private var currentTab: Tab = .home

    let currentUserId = "1"

    var influencer: User? {
        group.members.first(where: { $0.id == group.currentInfluencerId })
    }

    var isInfluencer: Bool {
        currentUserId == group.currentInfluencerId
    }

    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.showCamera = granted
                }
            }
        default:
            showPermissionAlert = true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Bar
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.black)
                }

                Spacer()

                Image("DIML_Logo")
                    .resizable()
                    .frame(width: 40, height: 40)

                Spacer()

                Button(action: {
                    // Settings action
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)

            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(influencer?.name ?? "Unknown")’s DIML")
                            .font(.custom("Fredoka-Regular", size: 22))
                            .foregroundColor(isInfluencer ? Color.blue : Color(red: 0.16, green: 0.21, blue: 0.09))

                        Text("she/her") // Placeholder
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)

                    // Message Box
                    VStack(spacing: 12) {
                        Image(systemName: "sun.max.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(isInfluencer ? .yellow : .gray)

                        Text(isInfluencer
                             ? "Snap a picture to\nkick off your day!"
                             : "\(influencer?.name ?? "Your friend") is starting today’s DIML")
                            .font(.system(size: 18, weight: .medium))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.94, green: 0.93, blue: 0.88))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // Locked Box
                    VStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.gray)

                        Text("Next Prompt Unlocking in…")
                            .font(.custom("Markazi Text", size: 18))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 1, green: 0.89, blue: 0.64))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                .padding(.top)
            }

            Spacer()

            NavigationLink(destination: DIMLView(store: store, group: group), isActive: $goToDIML) {
                EmptyView()
            }

        }
        .background(Color(red: 1, green: 0.989, blue: 0.93).ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showCamera) {
            CameraView(isPresented: $showCamera) { image in
                print("Image captured")
            }
        }
        .alert(isPresented: $showPermissionAlert) {
            Alert(
                title: Text("Camera Access Required"),
                message: Text("Please enable camera access in Settings to take photos."),
                primaryButton: .default(Text("Settings"), action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }),
                secondaryButton: .cancel()
            )
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let completion: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.completion(image)
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}


// MARK: - Preview
struct GroupDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let mockMembers = [
            User(id: "1", name: "Rebecca"),
            User(id: "2", name: "Taylor")
        ]

        let mockGroup = Group(
            id: "g1",
            name: "Test Group",
            members: mockMembers,
            currentInfluencerId: "1",
            date: Date()
        )

        GroupDetailView(group: mockGroup)
    }
}
