import Foundation
import FirebaseAuth
import FirebaseFirestore

class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    @Published var isAuthenticated = false
    @Published var isCompletingProfile = false
    @Published var currentUser: FirebaseAuth.User?
    
    private init() {
        // Set up Firebase Auth state listener
        _ = Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            // Only set isAuthenticated to true if we're not in profile completion mode
            if let self = self {
                self.currentUser = user
                if !self.isCompletingProfile {
                    self.isAuthenticated = user != nil
                }
            }
        }
    }
    
    func createAccount(email: String, password: String, completion: @escaping (Result<FirebaseAuth.User, Error>) -> Void) {
        // Set completing profile flag before creating account
        self.isCompletingProfile = true
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            if let error = error {
                self?.isCompletingProfile = false
                completion(.failure(error))
                return
            }
            
            if let user = authResult?.user {
                // Sign in immediately after creating account
                Auth.auth().signIn(withEmail: email, password: password) { signInResult, signInError in
                    if let signInError = signInError {
                        self?.isCompletingProfile = false
                        completion(.failure(signInError))
                        return
                    }
                    
                    // Create initial Firestore document
                    let db = Firestore.firestore()
                    let userData: [String: Any] = [
                        "uid": user.uid,
                        "email": email,
                        "username": UserDefaults.standard.string(forKey: "profile_username") ?? "",
                        "name": UserDefaults.standard.string(forKey: "profile_name") ?? "",
                        "pronouns": UserDefaults.standard.string(forKey: "profile_pronouns") ?? "",
                        "zodiacSign": UserDefaults.standard.string(forKey: "profile_zodiac") ?? "",
                        "location": UserDefaults.standard.string(forKey: "profile_location") ?? "",
                        "school": UserDefaults.standard.string(forKey: "profile_school") ?? "",
                        "interests": UserDefaults.standard.string(forKey: "profile_interests") ?? "",
                        "birthday": UserDefaults.standard.object(forKey: "profile_birthday") as? Date ?? Date(),
                        "profileImageURL": UserDefaults.standard.string(forKey: "profile_image_url_\(user.uid)") ?? "",
                        "showLocation": true,
                        "showSchool": true,
                        "createdAt": FieldValue.serverTimestamp(),
                        "lastUpdated": FieldValue.serverTimestamp(),
                        "profileCompleted": false
                    ]
                    
                    db.collection("users").document(user.uid).setData(userData, merge: true) { error in
                        if let error = error {
                            print("Error creating user document: \(error.localizedDescription)")
                            self?.isCompletingProfile = false
                            completion(.failure(error))
                        } else {
                            print("Successfully created user document")
                            self?.currentUser = user
                            
                            // Store credentials for later use
                            UserDefaults.standard.set(email, forKey: "pending_email")
                            UserDefaults.standard.set(password, forKey: "pending_password")
                            
                            completion(.success(user))
                        }
                    }
                }
            }
        }
    }
    
    func completeSignUp(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let email = UserDefaults.standard.string(forKey: "pending_email"),
              let password = UserDefaults.standard.string(forKey: "pending_password") else {
            let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing credentials"])
            completion(.failure(error))
            return
        }
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.isCompletingProfile = false
                    completion(.failure(error))
                    return
                }
                
                // Update Firestore to mark profile as completed
                if let userId = authResult?.user.uid {
                    let db = Firestore.firestore()
                    
                    // Get all profile data from UserDefaults
                    let profileData: [String: Any] = [
                        "uid": userId,
                        "email": email,
                        "username": UserDefaults.standard.string(forKey: "profile_username") ?? "",
                        "name": UserDefaults.standard.string(forKey: "profile_name") ?? "",
                        "pronouns": UserDefaults.standard.string(forKey: "profile_pronouns") ?? "",
                        "zodiacSign": UserDefaults.standard.string(forKey: "profile_zodiac") ?? "",
                        "location": UserDefaults.standard.string(forKey: "profile_location") ?? "",
                        "school": UserDefaults.standard.string(forKey: "profile_school") ?? "",
                        "interests": UserDefaults.standard.string(forKey: "profile_interests") ?? "",
                        "birthday": UserDefaults.standard.object(forKey: "profile_birthday") as? Date ?? Date(),
                        "profileImageURL": UserDefaults.standard.string(forKey: "profile_image_url_\(userId)") ?? "",
                        "showLocation": true,
                        "showSchool": true,
                        "profileCompleted": true,
                        "lastUpdated": FieldValue.serverTimestamp()
                    ]
                    
                    db.collection("users").document(userId).setData(profileData, merge: true) { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                print("Error updating profile completion status: \(error.localizedDescription)")
                                self?.isCompletingProfile = false
                                completion(.failure(error))
                                return
                            }
                            
                            // Set authentication state after successful profile completion
                            self?.isCompletingProfile = false
                            self?.isAuthenticated = true
                            self?.currentUser = authResult?.user
                            
                            // Clean up only the temporary credentials
                            UserDefaults.standard.removeObject(forKey: "pending_email")
                            UserDefaults.standard.removeObject(forKey: "pending_password")
                            
                            // Keep all profile data in UserDefaults for future use
                            print("Successfully completed sign up")
                            completion(.success(()))
                        }
                    }
                } else {
                    self?.isCompletingProfile = false
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User ID not found"])))
                }
            }
        }
    }
    
    func signIn(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                self?.isAuthenticated = true
                self?.currentUser = authResult?.user
                completion(.success(()))
            }
        }
    }
    
    func signOut() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            // Clear Firestore profile completion status
            let db = Firestore.firestore()
            db.collection("users").document(userId).updateData([
                "profileCompleted": false,
                "lastUpdated": FieldValue.serverTimestamp()
            ]) { error in
                if let error = error {
                    print("Error updating profile completion status: \(error.localizedDescription)")
                }
            }
            
            try Auth.auth().signOut()
            self.isAuthenticated = false
            self.isCompletingProfile = false
            self.currentUser = nil
            
            // Clear all user data from UserDefaults
            let userDefaultsKeys = [
                "profile_name",
                "profile_username",
                "profile_pronouns",
                "profile_zodiac",
                "profile_location",
                "profile_school",
                "profile_interests",
                "profile_image",
                "profile_image_url",
                "profile_birthday",
                "privacy_show_location",
                "privacy_show_school",
                "pending_email",
                "pending_password",
                "cached_profile_image_\(userId)"
            ]
            
            userDefaultsKeys.forEach { key in
                UserDefaults.standard.removeObject(forKey: key)
            }
            
            // Synchronize UserDefaults to ensure changes are saved
            UserDefaults.standard.synchronize()
            
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    func resetPassword(email: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            completion(error)
        }
    }
    
    func updatePassword(currentPassword: String, newPassword: String, completion: @escaping (Error?) -> Void) {
        guard let user = Auth.auth().currentUser,
              let email = user.email else {
            completion(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user found"]))
            return
        }
        
        // First, reauthenticate the user
        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        user.reauthenticate(with: credential) { _, error in
            if let error = error {
                completion(error)
                return
            }
            
            // Then update the password
            user.updatePassword(to: newPassword) { error in
                if let error = error {
                    completion(error)
                    return
                }
                
                // Update was successful
                completion(nil)
            }
        }
    }
} 