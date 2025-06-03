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
        Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            self?.isAuthenticated = user != nil
            self?.currentUser = user
        }
    }
    
    func createAccount(email: String, password: String, completion: @escaping (Result<FirebaseAuth.User, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let user = authResult?.user {
                // Set completing profile flag before signing in
                self?.isCompletingProfile = true
                
                // Sign in immediately after creating account
                Auth.auth().signIn(withEmail: email, password: password) { signInResult, signInError in
                    if let signInError = signInError {
                        completion(.failure(signInError))
                        return
                    }
                    
                    // Create initial Firestore document
                    let db = Firestore.firestore()
                    let userData: [String: Any] = [
                        "uid": user.uid,
                        "email": email,
                        "createdAt": FieldValue.serverTimestamp(),
                        "lastUpdated": FieldValue.serverTimestamp()
                    ]
                    
                    db.collection("users").document(user.uid).setData(userData) { error in
                        if let error = error {
                            print("Error creating user document: \(error.localizedDescription)")
                        } else {
                            print("Successfully created user document")
                        }
                        
                        self?.currentUser = user
                        // Store credentials for later if needed
                UserDefaults.standard.set(email, forKey: "pending_email")
                UserDefaults.standard.set(password, forKey: "pending_password")
                completion(.success(user))
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
                    completion(.failure(error))
                    return
                }
                
                // Clean up stored credentials
                UserDefaults.standard.removeObject(forKey: "pending_email")
                UserDefaults.standard.removeObject(forKey: "pending_password")
                
                self?.currentUser = authResult?.user
                completion(.success(()))
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
        do {
            try Auth.auth().signOut()
            self.isAuthenticated = false
            self.currentUser = nil
            
            // Clear all user data
            UserDefaults.standard.removeObject(forKey: "profile_name")
            UserDefaults.standard.removeObject(forKey: "profile_username")
            UserDefaults.standard.removeObject(forKey: "profile_pronouns")
            UserDefaults.standard.removeObject(forKey: "profile_zodiac")
            UserDefaults.standard.removeObject(forKey: "profile_location")
            UserDefaults.standard.removeObject(forKey: "profile_school")
            UserDefaults.standard.removeObject(forKey: "profile_interests")
            UserDefaults.standard.removeObject(forKey: "profile_image")
            UserDefaults.standard.removeObject(forKey: "privacy_show_location")
            UserDefaults.standard.removeObject(forKey: "privacy_show_school")
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    func resetPassword(email: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            completion(error)
        }
    }
} 