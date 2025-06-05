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
                    Image(systemName: "house")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundColor(currentTab == .home ? .black : .gray)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                // Camera Icon
                Button(action: {
                    onCameraTap()
                }) {
                    ZStack {
                    Circle()
                            .stroke(shouldBounceCamera ? Color.yellow : Color.gray.opacity(0.5), lineWidth: 2)
                        .frame(width: 50, height: 50)
                        
                            Image(systemName: "camera")
                            .foregroundColor(shouldBounceCamera ? .yellow : .gray.opacity(0.7))
                    }
                    .offset(y: bounceOffset)
                    .animation(
                        shouldBounceCamera ?
                            Animation
                                .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true) :
                            .default,
                        value: bounceOffset
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .onAppear {
                    if shouldBounceCamera {
                        bounceOffset = -15
                    }
                }
                .onChange(of: isInfluencer) { newValue in
                    bounceOffset = shouldBounceCamera ? -15 : 0
                }
                .onChange(of: shouldBounceCamera) { newValue in
                    bounceOffset = newValue ? -15 : 0
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
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 50)
            .padding(.vertical, 16)
            .padding(.bottom, 20)
            .background(Color(red: 1, green: 0.989, blue: 0.93))
            .transition(.move(edge: .bottom))
        }
    }
}
