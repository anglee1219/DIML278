import Foundation

struct ZodiacCalculator {
    static func getZodiacSign(from date: Date) -> String {
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
    
    static func getZodiacEmoji(for sign: String) -> String {
        switch sign.lowercased() {
        case "aries":
            return "♈️"
        case "taurus":
            return "♉️"
        case "gemini":
            return "♊️"
        case "cancer":
            return "♋️"
        case "leo":
            return "♌️"
        case "virgo":
            return "♍️"
        case "libra":
            return "♎️"
        case "scorpio":
            return "♏️"
        case "sagittarius":
            return "♐️"
        case "capricorn":
            return "♑️"
        case "aquarius":
            return "♒️"
        case "pisces":
            return "♓️"
        default:
            return "⭐️"
        }
    }
} 