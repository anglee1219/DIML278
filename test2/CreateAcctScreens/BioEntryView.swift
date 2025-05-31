import SwiftUI

struct BioEntryView: View {
    @State private var bioText: String = ""
    @State private var navigateToMain = false

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                ZStack {
                    Color(red: 1, green: 0.988, blue: 0.929)
                        .ignoresSafeArea()
                        .onTapGesture {
                            hideKeyboard()
                        }
                    .navigationBarBackButtonHidden(true)


                    VStack(spacing: 30) {
                        Image("DIML_Logo")
                            .resizable()
                            .frame(width: 60, height: 60)

                        Text("Write A Short Bio:")
                            .font(.custom("Markazi Text", size: 28))
                            .fontWeight(.semibold)
                            .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))

                        TextEditor(text: $bioText)
                            .frame(height: 200)
                            .padding()
                            .background(Color(red: 0.878, green: 0.878, blue: 0.78))
                            .cornerRadius(16)
                            .padding(.horizontal)

                        Spacer()

                        NavigationLink(destination: GroupListView(), isActive: $navigateToMain) {
                            Button(action: {
                                navigateToMain = true
                            }) {
                                Text("Create Profile")
                                    .font(.custom("Markazi Text", size: 24))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.mainBlue)
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.top, 80)
                }
            }
        } else {
            Text("iOS 16+ required")
        }
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct BioEntryView_Previews: PreviewProvider {
    static var previews: some View {
        BioEntryView()
    }
}
