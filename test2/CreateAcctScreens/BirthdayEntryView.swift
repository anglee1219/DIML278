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
        return age >= 18
    }
    
    var body: some View {
        ZStack {
            Color(red: 1, green: 0.988, blue: 0.929)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    Spacer()
                        .frame(height: 20)
                    
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("When's your birthday?")
                        .font(.custom("Markazi Text", size: 32))
                        .foregroundColor(Color(red: 0.969, green: 0.757, blue: 0.224))
                        .padding(.bottom, 10)
                    
                    Text("You must be at least 18 years old to use DIML")
                        .font(.custom("Markazi Text", size: 18))
                        .foregroundColor(.gray)
                    
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
                        Text("You must be at least 18 years old")
                            .font(.custom("Markazi Text", size: 16))
                            .foregroundColor(.red)
                    }
                    
                    NavigationLink(destination: PronounSelectionView(), isActive: $navigateBack) { EmptyView() }
                    NavigationLink(destination: BioEntryView(), isActive: $navigateToNext) { EmptyView() }
                    
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
                    .padding(.top, 30)
                    
                    Spacer()
                        .frame(height: 60)
                }
                .padding(.bottom, 20)
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
