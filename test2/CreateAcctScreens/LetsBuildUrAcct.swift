import SwiftUI

struct BuildProfileFlowView: View {
    @State private var showText = false
    @State private var showNextScreen = false

    var body: some View {
        ZStack {
            Color(red: 1, green: 0.988, blue: 0.929)
                .ignoresSafeArea()
            
            if showNextScreen {
                ProfilePhotoUploadView()
                    .transition(.opacity)
            } else {
                VStack(spacing: 40) {
                    Spacer()
                    
                    Image("DIML_Logo")
                        .resizable()
                        .frame(width: 60, height: 60)
                    
                    if showText {
                        VStack {
                            Text("Let's Build")
                            Text("Your Profile")
                        }
                        .font(.custom("Markazi Text", size: 32))
                        .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                        .transition(.opacity)
                    }
                    
                    Spacer()
                }
                .padding()
                .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.easeIn(duration: 1)) {
                showText = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    showNextScreen = true
                }
            }
        }
    }
}

#Preview {
    BuildProfileFlowView()
}
