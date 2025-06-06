import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

class ProfileViewModel: ObservableObject {
    static let shared = ProfileViewModel()
    
    private var isInitializing = true // Flag to prevent saving during initialization
    
    @Published var name: String = "" {
        didSet {
            guard !isInitializing else { return }
            saveProfile()
        }
    }
    
    @Published var username: String = "" {
        didSet {
            guard !isInitializing else { return }
            saveProfile()
        }
    }
    
    @Published var pronouns: String = "" {
        didSet {
            guard !isInitializing else { return }
            saveProfile()
            // Also save to UserDefaults for immediate access
            UserDefaults.standard.set(pronouns, forKey: "profile_pronouns")
        }
    }
    
    @Published var zodiac: String = "" {
        didSet {
            guard !isInitializing else { return }
            saveProfile()
        }
    }
    
    @Published var birthday: Date = Date() {
        didSet {
            guard !isInitializing else { return }
            saveProfile()
            // Also save to UserDefaults for immediate access
            UserDefaults.standard.set(birthday, forKey: "profile_birthday")
        }
    }
    
    @Published var location: String = "" {
        didSet {
            guard !isInitializing else { return }
            saveProfile()
        }
    }
    
    @Published var school: String = "" {
        didSet {
            guard !isInitializing else { return }
            saveProfile()
        }
    }
    
    @Published var interests: String = "" {
        didSet {
            guard !isInitializing else { return }
            saveProfile()
        }
    }
    
    @Published var showLocation: Bool = true {
        didSet {
            guard !isInitializing else { return }
            savePrivacySettings()
            objectWillChange.send()
        }
    }
    
    @Published var showSchool: Bool = true {
        didSet {
            guard !isInitializing else { return }
            savePrivacySettings()
            objectWillChange.send()
        }
    }
    
    @Published var profileImageData: Data? {
        didSet {
            guard !isInitializing else { return }
            saveProfileImage()
            // Cache the image data locally
            if let imageData = profileImageData {
                UserDefaults.standard.set(imageData, forKey: "cached_profile_image_\(Auth.auth().currentUser?.uid ?? "")")
            } else {
                UserDefaults.standard.removeObject(forKey: "cached_profile_image_\(Auth.auth().currentUser?.uid ?? "")")
            }
        }
    }
    
    init() {
        // Set default values
        showLocation = true
        showSchool = true
        
        // Load initial data from UserDefaults first
        loadInitialData()
        
        // Set up Auth state listener
        _ = Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            if user != nil {
                self?.loadUserProfile()
            } else {
                self?.clearProfile()
            }
        }
        
        // Load from Firestore immediately if user is already authenticated
        if Auth.auth().currentUser != nil {
            loadUserProfile()
        }
        
        // Complete initialization after a shorter delay and ensure data is loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isInitializing = false
            
            // Force refresh if profile data is empty but we have UserDefaults data
            if self.name.isEmpty || self.username.isEmpty {
                self.loadInitialData()
                if Auth.auth().currentUser != nil {
                    self.loadUserProfile()
                }
            }
        }
    }
    
    private func loadInitialData() {
        // Load initial data from UserDefaults
        self.name = UserDefaults.standard.string(forKey: "profile_name") ?? ""
        self.username = UserDefaults.standard.string(forKey: "profile_username") ?? ""
        self.pronouns = UserDefaults.standard.string(forKey: "profile_pronouns") ?? ""
        self.zodiac = UserDefaults.standard.string(forKey: "profile_zodiac") ?? ""
        self.birthday = UserDefaults.standard.object(forKey: "profile_birthday") as? Date ?? Date()
        self.location = UserDefaults.standard.string(forKey: "profile_location") ?? ""
        self.school = UserDefaults.standard.string(forKey: "profile_school") ?? ""
        self.interests = UserDefaults.standard.string(forKey: "profile_interests") ?? ""
        // Always default to showing location and school
        self.showLocation = true
        self.showSchool = true
        
        if let imageData = UserDefaults.standard.data(forKey: "cached_profile_image_\(Auth.auth().currentUser?.uid ?? "")") {
            self.profileImageData = imageData
        }
    }
    
    func loadUserProfile() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No authenticated user")
            return
        }
        
        // First try to load from cache
        if let cachedImageData = UserDefaults.standard.data(forKey: "cached_profile_image_\(userId)") {
            self.profileImageData = cachedImageData
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { [weak self] (document, error) in
            if let error = error {
                print("Error loading profile: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, document.exists, let data = document.data() else {
                print("No profile document found")
                // Try to load from UserDefaults as fallback
                self?.loadFromUserDefaults()
                // Mark initialization as complete even for fallback
                DispatchQueue.main.async {
                    self?.isInitializing = false
                }
                return
            }
            
            DispatchQueue.main.async {
                // Update UserDefaults with the latest data
                UserDefaults.standard.set(data["name"] as? String ?? "", forKey: "profile_name")
                UserDefaults.standard.set(data["username"] as? String ?? "", forKey: "profile_username")
                UserDefaults.standard.set(data["pronouns"] as? String ?? "", forKey: "profile_pronouns")
                UserDefaults.standard.set(data["zodiacSign"] as? String ?? "", forKey: "profile_zodiac")
                if let timestamp = data["birthday"] as? Timestamp {
                    UserDefaults.standard.set(timestamp.dateValue(), forKey: "profile_birthday")
                }
                UserDefaults.standard.set(data["location"] as? String ?? "", forKey: "profile_location")
                UserDefaults.standard.set(data["school"] as? String ?? "", forKey: "profile_school")
                UserDefaults.standard.set(data["interests"] as? String ?? "", forKey: "profile_interests")
                
                // Update the view model properties
                self?.name = data["name"] as? String ?? ""
                self?.username = data["username"] as? String ?? ""
                self?.pronouns = data["pronouns"] as? String ?? ""
                self?.zodiac = data["zodiacSign"] as? String ?? ""
                if let timestamp = data["birthday"] as? Timestamp {
                    self?.birthday = timestamp.dateValue()
                }
                self?.location = data["location"] as? String ?? ""
                self?.school = data["school"] as? String ?? ""
                self?.interests = data["interests"] as? String ?? ""
                // Always default to showing location and school unless explicitly set to false
                self?.showLocation = data["showLocation"] as? Bool ?? true
                self?.showSchool = data["showSchool"] as? Bool ?? true
                
                // Mark initialization as complete
                self?.isInitializing = false
                
                // Load profile image from Firebase Storage
                if let imageURL = data["profileImageURL"] as? String,
                   let url = URL(string: imageURL) {
                    URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                        if let error = error {
                            print("Error downloading profile image: \(error.localizedDescription)")
                            return
                        }
                        guard let data = data,
                              let self = self else { return }
                        
                            DispatchQueue.main.async {
                            self.profileImageData = data
                                // Cache the image data
                            if let userId = Auth.auth().currentUser?.uid {
                                UserDefaults.standard.set(data, forKey: "cached_profile_image_\(userId)")
                            }
                        }
                    }.resume()
                }
            }
        }
    }
    
    private func loadFromUserDefaults() {
        // Load from UserDefaults as fallback
        self.name = UserDefaults.standard.string(forKey: "profile_name") ?? ""
        self.username = UserDefaults.standard.string(forKey: "profile_username") ?? ""
        self.pronouns = UserDefaults.standard.string(forKey: "profile_pronouns") ?? ""
        self.zodiac = UserDefaults.standard.string(forKey: "profile_zodiac") ?? ""
        self.birthday = UserDefaults.standard.object(forKey: "profile_birthday") as? Date ?? Date()
        self.location = UserDefaults.standard.string(forKey: "profile_location") ?? ""
        self.school = UserDefaults.standard.string(forKey: "profile_school") ?? ""
        self.interests = UserDefaults.standard.string(forKey: "profile_interests") ?? ""
        // Always default to showing location and school
        self.showLocation = true
        self.showSchool = true
        
        if let imageData = UserDefaults.standard.data(forKey: "profile_image") {
            self.profileImageData = imageData
        }
    }
    
    private func clearProfile() {
        print("🧹 ProfileViewModel: Clearing all profile data")
        
        name = ""
        username = ""
        pronouns = ""
        zodiac = ""
        birthday = Date()
        location = ""
        school = ""
        interests = ""
        showLocation = true
        showSchool = true
        profileImageData = nil
        
        // Clear ALL user-specific data from UserDefaults
        let keysToRemove = [
            "profile_name",
            "profile_username", 
            "profile_pronouns",
            "profile_zodiac",
            "profile_location",
            "profile_school",
            "profile_interests",
            "profile_birthday",
            "profile_image",
            "profile_image_url",
            "privacy_show_location",
            "privacy_show_school"
        ]
        
        keysToRemove.forEach { key in
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Clear cached images for any user IDs
        if let userId = Auth.auth().currentUser?.uid {
            UserDefaults.standard.removeObject(forKey: "cached_profile_image_\(userId)")
            UserDefaults.standard.removeObject(forKey: "profile_image_url_\(userId)")
        }
        
        UserDefaults.standard.synchronize()
        print("🧹 ProfileViewModel: Profile data cleared")
    }
    
    func saveProfile() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No authenticated user")
            return
        }
        
        print("💾 ProfileViewModel: Saving profile data...")
        
        // First, save to UserDefaults for local caching
        UserDefaults.standard.set(name, forKey: "profile_name")
        UserDefaults.standard.set(username, forKey: "profile_username")
        UserDefaults.standard.set(pronouns, forKey: "profile_pronouns")
        UserDefaults.standard.set(zodiac, forKey: "profile_zodiac")
        UserDefaults.standard.set(birthday, forKey: "profile_birthday")
        UserDefaults.standard.set(location, forKey: "profile_location")
        UserDefaults.standard.set(school, forKey: "profile_school")
        UserDefaults.standard.set(interests, forKey: "profile_interests")
        UserDefaults.standard.set(showLocation, forKey: "privacy_show_location")
        UserDefaults.standard.set(showSchool, forKey: "privacy_show_school")
        UserDefaults.standard.synchronize()
        
        // Then, save to Firestore to sync with other users
        let db = Firestore.firestore()
        let profileData: [String: Any] = [
            "name": name,
            "username": username,
            "pronouns": pronouns,
            "zodiacSign": zodiac,
            "birthday": Timestamp(date: birthday),
            "location": location,
            "school": school,
            "interests": interests,
            "showLocation": showLocation,
            "showSchool": showSchool,
            "lastUpdated": FieldValue.serverTimestamp()
        ]
        
        db.collection("users").document(userId).setData(profileData, merge: true) { error in
            if let error = error {
                print("❌ Error saving profile to Firestore: \(error.localizedDescription)")
            } else {
                print("✅ Profile saved successfully to both UserDefaults and Firestore")
                
                // Update group member information in all groups where this user is a member
                self.updateGroupMemberInformation(userId: userId)
            }
        }
    }
    
    // Method to update group member information when profile changes
    private func updateGroupMemberInformation(userId: String) {
        print("🔄 ProfileViewModel: Updating group member information for user: \(userId)")
        
        let db = Firestore.firestore()
        
        // Find all groups where this user is a member
        db.collection("groups")
            .whereField("memberIds", arrayContains: userId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error fetching user's groups: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("📭 No groups found for user")
                    return
                }
                
                print("🔍 Found \(documents.count) groups where user is a member")
                
                // Update member information in each group
                for document in documents {
                    let groupId = document.documentID
                    guard document.exists else {
                        continue
                    }
                    
                    let documentData = document.data()
                    
                    guard let members = documentData["members"] as? [[String: Any]] else {
                        continue
                    }
                    
                    // Update the member data for this user
                    let updatedMembers = members.map { memberData in
                        var updatedMemberData = memberData
                        
                        // If this is the user we're updating
                        if let memberId = memberData["id"] as? String, memberId == userId {
                            // Update with current profile data
                            updatedMemberData["name"] = self.name
                            updatedMemberData["username"] = self.username
                            updatedMemberData["pronouns"] = self.pronouns
                            updatedMemberData["zodiacSign"] = self.zodiac
                            updatedMemberData["location"] = self.location
                            updatedMemberData["school"] = self.school
                            updatedMemberData["interests"] = self.interests
                            print("✅ Updated member data for user \(userId) in group \(groupId)")
                        }
                        
                        return updatedMemberData
                    }
                    
                    // Save updated members array back to the group
                    db.collection("groups").document(groupId).updateData([
                        "members": updatedMembers,
                        "lastUpdated": FieldValue.serverTimestamp()
                    ]) { error in
                        if let error = error {
                            print("❌ Error updating member data in group \(groupId): \(error.localizedDescription)")
                        } else {
                            print("✅ Successfully updated member data in group \(groupId)")
                        }
                    }
                }
            }
    }
    
    private func savePrivacySettings() {
        // Privacy settings are saved as part of the profile
        saveProfile()
    }
    
    private func saveProfileImage() {
        guard let userId = Auth.auth().currentUser?.uid,
              let imageData = profileImageData else {
            return
        }
        
        let storage = Storage.storage()
        let storageRef = storage.reference()
        
        // Create the profile_images directory if it doesn't exist
        let profileImagesRef = storageRef.child("profile_images")
        let profileImageRef = profileImagesRef.child("\(userId).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Compress image data for better upload performance
        guard let compressedImageData = UIImage(data: imageData)?.jpegData(compressionQuality: 0.5) else {
            print("Error compressing image data")
            return
        }
        
        // Upload the new image
        profileImageRef.putData(compressedImageData, metadata: metadata) { metadata, error in
            if let error = error {
                print("Error uploading profile image: \(error.localizedDescription)")
                return
            }
            
            // Get download URL and save it to Firestore
            profileImageRef.downloadURL { url, error in
                if let error = error {
                    print("Error getting download URL: \(error.localizedDescription)")
                    return
                }
                
                if let downloadURL = url {
                    let db = Firestore.firestore()
                    let profileData: [String: Any] = [
                        "profileImageURL": downloadURL.absoluteString,
                        "lastUpdated": FieldValue.serverTimestamp()
                    ]
                    
                    db.collection("users").document(userId).setData(profileData, merge: true) { error in
                        if let error = error {
                            print("Error saving profile image URL: \(error.localizedDescription)")
                        } else {
                            print("Profile image URL saved successfully")
                            // Cache the compressed image data with user-specific key
                            UserDefaults.standard.set(compressedImageData, forKey: "cached_profile_image_\(userId)")
                            UserDefaults.standard.set(downloadURL.absoluteString, forKey: "profile_image_url_\(userId)")
                        }
                    }
                }
            }
        }
    }
    
    func updateProfileImage(_ image: UIImage) {
        if let imageData = image.jpegData(compressionQuality: 0.7) {
            self.profileImageData = imageData
        }
    }
    
    func removeProfileImage() {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        // Remove from Firebase Storage
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let profileImageRef = storageRef.child("profile_images/\(userId).jpg")
        
        profileImageRef.delete { error in
            if let error = error {
                print("Error deleting profile image: \(error.localizedDescription)")
            }
        }
        
        // Remove URL from Firestore
        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "profileImageURL": FieldValue.delete()
        ]) { error in
            if let error = error {
                print("Error removing profile image URL: \(error.localizedDescription)")
            }
        }
        
        // Clear local data
        self.profileImageData = nil
        UserDefaults.standard.removeObject(forKey: "cached_profile_image_\(userId)")
    }
    
    var profileImage: UIImage? {
        if let imageData = profileImageData {
            return UIImage(data: imageData)
        }
        return nil
    }
    
    // Public method to force refresh profile data
    func forceRefresh() {
        print("🔄 ProfileViewModel: Force refresh requested")
        
        // Allow saving during refresh
        isInitializing = false 
        
        // Reload from UserDefaults first to get any cached data
        loadInitialData()
        
        // Then reload from Firestore to get the latest data
        if Auth.auth().currentUser != nil {
            loadUserProfile()
        }
        
        // Also ensure we save UserDefaults data to Firestore if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !self.name.isEmpty || !self.username.isEmpty {
                self.saveProfile()
            }
        }
    }
    
    // Public method to force sync all profile data across systems
    func forceSyncAfterEdit() {
        print("🔄 ProfileViewModel: Force sync after profile edit")
        
        guard Auth.auth().currentUser != nil else {
            print("❌ No authenticated user for sync")
            return
        }
        
        // Save current data to all storage systems
        saveProfile()
        
        // Update SharedProfileViewModel for immediate UI updates
        DispatchQueue.main.async {
            SharedProfileViewModel.shared.name = self.name
            SharedProfileViewModel.shared.username = self.username
            SharedProfileViewModel.shared.pronouns = self.pronouns
            SharedProfileViewModel.shared.zodiac = self.zodiac
            SharedProfileViewModel.shared.location = self.location
            SharedProfileViewModel.shared.school = self.school
            SharedProfileViewModel.shared.interests = self.interests
        }
        
        print("✅ Profile sync completed - data updated across all systems")
    }
} 
