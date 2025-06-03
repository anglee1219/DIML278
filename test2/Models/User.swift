import Foundation
import FirebaseFirestore

struct UserProfile: Codable, Identifiable {
    @DocumentID var id: String?
    let uid: String
    let email: String
    var username: String?
    var pronouns: String?
    var zodiacSign: String?
    var location: String?
    var school: String?
    var interests: String?
    var createdAt: Date?
    var lastUpdated: Date?
    
    // Privacy settings
    var showLocation: Bool = true
    var showSchool: Bool = true
    
    enum CodingKeys: String, CodingKey {
        case id
        case uid
        case email
        case username
        case pronouns
        case zodiacSign = "zodiacSign"
        case location
        case school
        case interests
        case createdAt
        case lastUpdated
        case showLocation = "privacy_show_location"
        case showSchool = "privacy_show_school"
    }
    
    // Initialize from UserDefaults data
    static func fromUserDefaults() -> UserProfile? {
        guard let email = UserDefaults.standard.string(forKey: "profile_email") else { return nil }
        
        return UserProfile(
            uid: UserDefaults.standard.string(forKey: "profile_uid") ?? "",
            email: email,
            username: UserDefaults.standard.string(forKey: "profile_username"),
            pronouns: UserDefaults.standard.string(forKey: "profile_pronouns"),
            zodiacSign: UserDefaults.standard.string(forKey: "profile_zodiac"),
            location: UserDefaults.standard.string(forKey: "profile_location"),
            school: UserDefaults.standard.string(forKey: "profile_school"),
            interests: UserDefaults.standard.string(forKey: "profile_interests"),
            showLocation: UserDefaults.standard.bool(forKey: "privacy_show_location"),
            showSchool: UserDefaults.standard.bool(forKey: "privacy_show_school")
        )
    }
    
    // Save to UserDefaults
    func saveToUserDefaults() {
        UserDefaults.standard.set(uid, forKey: "profile_uid")
        UserDefaults.standard.set(email, forKey: "profile_email")
        if let username = username {
            UserDefaults.standard.set(username, forKey: "profile_username")
        }
        if let pronouns = pronouns {
            UserDefaults.standard.set(pronouns, forKey: "profile_pronouns")
        }
        if let zodiacSign = zodiacSign {
            UserDefaults.standard.set(zodiacSign, forKey: "profile_zodiac")
        }
        if let location = location {
            UserDefaults.standard.set(location, forKey: "profile_location")
        }
        if let school = school {
            UserDefaults.standard.set(school, forKey: "profile_school")
        }
        if let interests = interests {
            UserDefaults.standard.set(interests, forKey: "profile_interests")
        }
        UserDefaults.standard.set(showLocation, forKey: "privacy_show_location")
        UserDefaults.standard.set(showSchool, forKey: "privacy_show_school")
    }
} 
