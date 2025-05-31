import SwiftUI

struct TopNavBar: View {
    var showsBack: Bool = false
    var showsMenu: Bool = false
    var onBack: (() -> Void)? = nil
    var onMenu: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Cream background with shadow
            Color(red: 1, green: 0.988, blue: 0.929)
                .ignoresSafeArea()
                .frame(height: 0)
            
            ZStack {
                Color(red: 1, green: 0.988, blue: 0.929)
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 4)

                HStack {
                    // Back button
                    if showsBack {
                        Button(action: { onBack?() }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.black)
                                .font(.title3)
                        }
                    } else {
                        Spacer().frame(width: 44)
                    }

                    Spacer()

                    // Logo in the center
                    Image("DIML_Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)

                    Spacer()

                    // Menu button
                    if showsMenu {
                        Button(action: { onMenu?() }) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.black)
                                .font(.title3)
                        }
                    } else {
                        Spacer().frame(width: 44)
                    }
                }
                .padding(.horizontal, 40)
            }
            .frame(height: 65)
        }
    }
}
