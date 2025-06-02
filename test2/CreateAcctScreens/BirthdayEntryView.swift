import SwiftUI

struct BirthdayEntryView: View {
    @StateObject private var viewModel = ProfileViewModel.shared
    @State private var selectedDate = Date()
    @State private var goToNextScreen = false
    @State private var goToPreviousScreen = false
    
    private func calculateZodiacSign(from date: Date) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        
        switch (month, day) {
        case (3, 21...31), (4, 1...19):
            return "aries"
        case (4, 20...30), (5, 1...20):
            return "taurus"
        case (5, 21...31), (6, 1...20):
            return "gemini"
        case (6, 21...30), (7, 1...22):
            return "cancer"
        case (7, 23...31), (8, 1...22):
            return "leo"
        case (8, 23...31), (9, 1...22):
            return "virgo"
        case (9, 23...30), (10, 1...22):
            return "libra"
        case (10, 23...31), (11, 1...21):
            return "scorpio"
        case (11, 22...30), (12, 1...21):
            return "sagittarius"
        case (12, 22...31), (1, 1...19):
            return "capricorn"
        case (1, 20...31), (2, 1...18):
            return "aquarius"
        case (2, 19...29), (3, 1...20):
            return "pisces"
        default:
            return "unknown"
        }
    }
    
    var body: some View {
        ZStack {
            Color(red: 1, green: 0.988, blue: 0.929)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Image("DIML_Logo")
                    .resizable()
                    .frame(width: 60, height: 60)
                
                Text("When's your birthday?")
                    .font(.custom("Markazi Text", size: 32))
                    .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                
                DatePicker("Birthday", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .onChange(of: selectedDate) { newDate in
                        // Update the zodiac sign whenever the date changes
                        viewModel.zodiac = calculateZodiacSign(from: newDate)
                    }
                
                Spacer()
                
                // Forward arrow only
                HStack {
                    Spacer()
                    
                    Button(action: {
                        // Ensure zodiac is set before proceeding
                        viewModel.zodiac = calculateZodiacSign(from: selectedDate)
                        goToNextScreen = true
                    }) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 24))
                            .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0))
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
                
                // Hidden NavLinks for navigation
                NavigationLink(destination: BioEntryView(), isActive: $goToNextScreen) { EmptyView() }
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .onAppear {
            // Set initial zodiac sign
            viewModel.zodiac = calculateZodiacSign(from: selectedDate)
        }
    }
}

struct BirthdayEntryView_Previews: PreviewProvider {
    static var previews: some View {
        BirthdayEntryView()
    }
}
