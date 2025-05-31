import SwiftUI

enum Tab {
    case home
    case camera
    case profile
}

struct BottomNavBar: View {
    @Binding var currentTab: Tab
    var onCameraTap: () -> Void

    var body: some View {
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
                Circle()
                    .stroke(Color.gray, lineWidth: 2)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "camera")
                            .foregroundColor(.gray)
                    )
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
        .padding(.bottom, 20)
    }
}
