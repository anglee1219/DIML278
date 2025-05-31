import SwiftUI

struct BirthdayEntryView: View {
    @State private var selectedDate = Date()
    @State private var showDatePicker = false
    @State private var navigateToBio = false
    @State private var navigateToPronouns = false

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                ZStack {
                    Color(red: 1, green: 0.988, blue: 0.929)
                        .ignoresSafeArea()

                    VStack(spacing: 40) {
                        Image("DIML_Logo")
                            .resizable()
                            .frame(width: 60, height: 60)

                        Text("When Is Your Birthday?")
                            .font(.custom("Markazi Text", size: 32))
                            .fontWeight(.semibold)
                            .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))

                        Button(action: {
                            showDatePicker = true
                        }) {
                            HStack(spacing: 12) {
                                ForEach(formattedDateParts(), id: \.self) { part in
                                    Text(part)
                                        .frame(width: 60, height: 50)
                                        .background(Color(red: 0.878, green: 0.878, blue: 0.78))
                                        .cornerRadius(12)
                                        .foregroundColor(.black)
                                }
                            }
                        }

                        Spacer()

                        // Navigation Links
                        NavigationLink(destination: BioEntryView(), isActive: $navigateToBio) { EmptyView() }
                        NavigationLink(destination: PronounSelectionView(), isActive: $navigateToPronouns) { EmptyView() }

                        // Navigation Arrows
                        HStack {
                            Button(action: {
                                navigateToPronouns = true
                            }) {
                                Image(systemName: "arrow.left")
                                    .font(.title2)
                                    .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                            }

                            Spacer()

                            Button(action: {
                                navigateToBio = true
                            }) {
                                Image(systemName: "arrow.right")
                                    .font(.title2)
                                    .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                            }
                        }
                        .padding(.horizontal, 30)
                    }
                    .padding(.top, 100)
                    .padding(.horizontal)
                    .sheet(isPresented: $showDatePicker) {
                        VStack {
                            DatePicker("Select your birthday", selection: $selectedDate, displayedComponents: [.date])
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .padding()

                            Button("Done") {
                                showDatePicker = false
                            }
                            .padding()
                        }
                        .presentationDetents([.medium])
                    }
                }
                .navigationBarBackButtonHidden(true) // Hides default nav back button
            }
        } else {
            Text("iOS 16 or later required.")
        }
    }

    func formattedDateParts() -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM dd yyyy"
        return formatter.string(from: selectedDate).components(separatedBy: " ")
    }
}

struct BirthdayEntryView_Previews: PreviewProvider {
    static var previews: some View {
        BirthdayEntryView()
    }
}
