import SwiftUI

class ProfileViewModel: ObservableObject {
    @Published var name: String {
        didSet {
            saveProfile()
        }
    }
    @Published var pronouns: String {
        didSet {
            saveProfile()
        }
    }
    @Published var zodiac: String {
        didSet {
            saveProfile()
        }
    }
    @Published var location: String {
        didSet {
            saveProfile()
        }
    }
    @Published var school: String {
        didSet {
            saveProfile()
        }
    }
    @Published var interests: String {
        didSet {
            saveProfile()
        }
    }
    @Published var profileImageData: Data? {
        didSet {
            saveProfileImage()
        }
    }
    
    init() {
        // Load saved values or use defaults
        self.name = UserDefaults.standard.string(forKey: "profile_name") ?? "Rebecca"
        self.pronouns = UserDefaults.standard.string(forKey: "profile_pronouns") ?? "she/her"
        self.zodiac = UserDefaults.standard.string(forKey: "profile_zodiac") ?? "scorpio"
        self.location = UserDefaults.standard.string(forKey: "profile_location") ?? "miami, fl"
        self.school = UserDefaults.standard.string(forKey: "profile_school") ?? "stanford"
        self.interests = UserDefaults.standard.string(forKey: "profile_interests") ?? "hiking, cooking, & taking pictures"
        self.profileImageData = UserDefaults.standard.data(forKey: "profile_image")
    }
    
    private func saveProfile() {
        UserDefaults.standard.set(name, forKey: "profile_name")
        UserDefaults.standard.set(pronouns, forKey: "profile_pronouns")
        UserDefaults.standard.set(zodiac, forKey: "profile_zodiac")
        UserDefaults.standard.set(location, forKey: "profile_location")
        UserDefaults.standard.set(school, forKey: "profile_school")
        UserDefaults.standard.set(interests, forKey: "profile_interests")
    }
    
    private func saveProfileImage() {
        if let imageData = profileImageData {
            UserDefaults.standard.set(imageData, forKey: "profile_image")
        }
    }
    
    func updateProfileImage(_ image: UIImage) {
        if let imageData = image.jpegData(compressionQuality: 0.7) {
            self.profileImageData = imageData
        }
    }
    
    func removeProfileImage() {
        self.profileImageData = nil
        UserDefaults.standard.removeObject(forKey: "profile_image")
    }
    
    var profileImage: UIImage? {
        if let imageData = profileImageData {
            return UIImage(data: imageData)
        }
        return nil
    }
} 