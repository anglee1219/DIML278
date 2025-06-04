import SwiftUI

enum Tab {
    case home
    case camera
    case profile
}

struct BottomNavBar: View {
    @Binding var currentTab: Tab
    var onCameraTap: () -> Void
    var isVisible: Bool = true
    var isInfluencer: Bool = false
    var shouldBounceCamera: Bool = false
    @State private var bounceOffset: CGFloat = 0

    var body: some View {
        if isVisible {
            HStack {
                // Home Icon
                Button(action: {
                    currentTab = .home
                }) {
                    Image(systemName: "house.fill")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundColor(currentTab == .home ? .black : .gray)
                }

                Spacer()

                // Camera Icon
                Button(action: {
                    onCameraTap()
                }) {
                    ZStack {
                    Circle()
                            .stroke((isInfluencer || shouldBounceCamera) ? Color.yellow : Color.gray, lineWidth: 2)
                        .frame(width: 50, height: 50)
                        
                            Image(systemName: "camera")
                            .foregroundColor((isInfluencer || shouldBounceCamera) ? .yellow : .gray)
                    }
                    .offset(y: bounceOffset)
                    .animation(
                        (isInfluencer || shouldBounceCamera) ?
                            Animation
                                .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true) :
                            .default,
                        value: bounceOffset
                    )
                }
                .onAppear {
                    if isInfluencer || shouldBounceCamera {
                        bounceOffset = -15
                    }
                }
                .onChange(of: isInfluencer) { newValue in
                    bounceOffset = (newValue || shouldBounceCamera) ? -15 : 0
                }
                .onChange(of: shouldBounceCamera) { newValue in
                    bounceOffset = (newValue || isInfluencer) ? -15 : 0
                }

                Spacer()

                // Profile Icon
                Button(action: {
                    currentTab = .profile
                }) {
                    Image(systemName: "person.crop.circle")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundColor(currentTab == .profile ? .black : .gray)
                }
            }
            .padding(.horizontal, 50)
            .padding(.vertical, 16)
            .padding(.bottom, 20)
            .background(Color(red: 1, green: 0.989, blue: 0.93))
            .transition(.move(edge: .bottom))
        }
    }
}
