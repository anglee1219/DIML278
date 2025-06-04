import SwiftUI

struct BirthdayEntryView: View {
    @State private var birthDate = Date()
    @State private var showDatePicker = false
    @State private var navigateToNext = false
    @State private var navigateBack = false
    @State private var zodiacSign = ""
    @State private var zodiacEmoji = ""
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }
    
    private var canProceed: Bool {
        let calendar = Calendar.current
        let age = calendar.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
        return age >= 13
    }
    
    var body: some View {
        ZStack {
            Color(red: 1, green: 0.988, blue: 0.929)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Logo at the top
                Image("DIML_People_Icon")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .padding(.top, 60)
                
                // Question text
                Text("When's your birthday?")
                    .font(.custom("Markazi Text", size: 36))
                    .foregroundColor(Color(red: 0.969, green: 0.757, blue: 0.224))
                    .padding(.bottom, 10)
                
                Text("You must be at least 13 years old to use DIML")
                    .font(.custom("Markazi Text", size: 20))
                    .foregroundColor(.gray)
                
                // Birthday Button
                Button(action: {
                    showDatePicker = true
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.mainBlue, lineWidth: 1)
                            )
                        
                        HStack {
                            Text(dateFormatter.string(from: birthDate))
                                .font(.custom("Markazi Text", size: 24))
                                .foregroundColor(Color.mainBlue)
                            
                            if !zodiacSign.isEmpty {
                                Text(zodiacEmoji)
                                    .font(.system(size: 24))
                            }
                        }
                    }
                    .frame(height: 56)
                    .padding(.horizontal, 20)
                }
                
                if !canProceed {
                    Text("You must be at least 13 years old")
                        .font(.custom("Markazi Text", size: 16))
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                // Navigation Links
                NavigationLink(destination: PronounSelectionView(), isActive: $navigateBack) { EmptyView() }
                NavigationLink(destination: BioEntryView(), isActive: $navigateToNext) { EmptyView() }
                
                // Navigation arrows
                HStack {
                    Button(action: {
                        navigateBack = true
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.title)
                            .foregroundColor(Color.mainBlue)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if canProceed {
                            // Store both the zodiac sign and birthday
                            let sign = ZodiacCalculator.getZodiacSign(from: birthDate)
                            UserDefaults.standard.set(sign, forKey: "profile_zodiac")
                            UserDefaults.standard.set(birthDate, forKey: "profile_birthday")
                            navigateToNext = true
                        }
                    }) {
                        Image(systemName: "arrow.right")
                            .font(.title)
                            .foregroundColor(canProceed ? Color.mainBlue : .gray)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showDatePicker) {
            if #available(iOS 16.0, *) {
                DatePicker("Select your birthday",
                          selection: $birthDate,
                          in: ...Date(),
                          displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .presentationDetents([.height(300)])
                    .onChange(of: birthDate) { newDate in
                        let sign = ZodiacCalculator.getZodiacSign(from: newDate)
                        zodiacSign = sign
                        zodiacEmoji = ZodiacCalculator.getZodiacEmoji(for: sign)
                    }
            } else {
                DatePicker("Select your birthday",
                          selection: $birthDate,
                          in: ...Date(),
                          displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .onChange(of: birthDate) { newDate in
                        let sign = ZodiacCalculator.getZodiacSign(from: newDate)
                        zodiacSign = sign
                        zodiacEmoji = ZodiacCalculator.getZodiacEmoji(for: sign)
                    }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Calculate initial zodiac sign
            let sign = ZodiacCalculator.getZodiacSign(from: birthDate)
            zodiacSign = sign
            zodiacEmoji = ZodiacCalculator.getZodiacEmoji(for: sign)
        }
    }
}

#Preview {
    if #available(iOS 16.0, *) {
        NavigationStack {
            BirthdayEntryView()
        }
    } else {
        // Fallback on earlier versions
    }
}
