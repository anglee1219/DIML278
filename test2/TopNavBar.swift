import SwiftUI

struct TopNavBar: View {
    var showsBack: Bool = false
    var showsMenu: Bool = false
    var onBack: (() -> Void)? = nil
    var onMenu: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Color(red: 1, green: 0.988, blue: 0.929)
                .frame(height: 0)
            
            ZStack {
                Color(red: 1, green: 0.988, blue: 0.929)
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 4)

                HStack {
                    // Back button or placeholder
                    if showsBack {
                        Button(action: { onBack?() }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.black)
                                .font(.title3)
                        }
                    } else {
                        Color.clear
                            .frame(width: 24, height: 24)
                    }

                    Spacer()

                    // Center logo
                    Image("DIML_Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)

                    Spacer()

                    // Menu button or placeholder
                    if showsMenu {
                        Button(action: { onMenu?() }) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.black)
                                .font(.title3)
                        }
                    } else {
                        Color.clear
                            .frame(width: 24, height: 24)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 60)
        }
        .background(Color(red: 1, green: 0.988, blue: 0.929))
    }
}

