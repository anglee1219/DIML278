import SwiftUI
import MapKit
import FirebaseFirestore
import FirebaseAuth

struct BioEntryView: View {
    @StateObject private var viewModel = ProfileViewModel.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var tutorialManager = TutorialManager()
    @Environment(\.dismiss) private var dismiss
    @State private var showLocationSearch = false
    @State private var navigateToNext = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    private func saveProfileToFirebase() {
        print("🎯 saveProfileToFirebase() called")
        
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ No authenticated user found")
            alertMessage = "No authenticated user found"
            showAlert = true
            return
        }
        
        print("✅ Current user found: \(currentUser.uid)")
        isLoading = true
        
        // Get stored credentials and user data
        guard let email = UserDefaults.standard.string(forKey: "pending_email"),
              let _ = UserDefaults.standard.string(forKey: "pending_password") else {
            print("❌ Missing credentials in UserDefaults")
            alertMessage = "Missing credentials. Please try creating your account again."
            showAlert = true
            isLoading = false
            return
        }
        
        print("✅ Found credentials: \(email)")
        
        // Get the zodiac sign and username from UserDefaults
        let zodiacSign = UserDefaults.standard.string(forKey: "profile_zodiac") ?? ""
        let username = UserDefaults.standard.string(forKey: "profile_username") ?? ""
        let name = UserDefaults.standard.string(forKey: "profile_name") ?? username
        let pronouns = UserDefaults.standard.string(forKey: "profile_pronouns") ?? ""
        let birthday = UserDefaults.standard.object(forKey: "profile_birthday") as? Date ?? Date()
        
        print("✅ Profile data - username: \(username), name: \(name), zodiac: \(zodiacSign)")
        
        // Update UserDefaults with the bio entry data immediately
        UserDefaults.standard.set(viewModel.location, forKey: "profile_location")
        UserDefaults.standard.set(viewModel.school, forKey: "profile_school")
        UserDefaults.standard.set(viewModel.interests, forKey: "profile_interests")
        UserDefaults.standard.synchronize()
        
        // Update ProfileViewModel immediately with all data
        viewModel.name = name
        viewModel.username = username
        viewModel.pronouns = pronouns
        viewModel.zodiac = zodiacSign
        viewModel.birthday = birthday
        // Note: location, school, interests are already set in viewModel from the UI
        
        // Create profile data for Firestore
        let profileData: [String: Any] = [
            "username": username,
            "name": name,
            "location": viewModel.location,
            "school": viewModel.school,
            "interests": viewModel.interests,
            "zodiacSign": zodiacSign,
            "pronouns": pronouns,
            "birthday": birthday,
            "profileImageURL": UserDefaults.standard.string(forKey: "profile_image_url_\(currentUser.uid)") ?? "",
            "showLocation": true,
            "showSchool": true,
            "profileCompleted": true,
            "lastUpdated": FieldValue.serverTimestamp(),
            "isFirstTimeUser": true  // Flag for tutorial
        ]
        
        print("🔥 About to save profile data to Firestore: \(profileData)")
        
        let db = Firestore.firestore()
        
        // Save to Firestore
        db.collection("users").document(currentUser.uid).setData(profileData, merge: true) { error in            
            if let error = error {
                print("❌ Firestore save error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                    self.isLoading = false
                }
                return
            }
            
            print("✅ Successfully saved profile data to Firestore")
            
            // Complete the sign up process
            print("🔥 About to call completeSignUp...")
            self.authManager.completeSignUp { result in
                print("🔥 completeSignUp callback called")
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("✅ Successfully completed sign up")
                        print("🔥 Setting isLoading = false and navigating to main app")
                        
                        // First set loading to false
                        self.isLoading = false
                        
                        // Reset tutorial for new users to ensure it shows
                        self.tutorialManager.resetTutorial(for: "onboarding")
                        print("🎯 BioEntry: Reset tutorial for new user")
                        
                        // Navigate to main app - tutorial will start in GroupListView
                        print("🎯 BioEntry: About to navigate to main app")
                        print("🎯 BioEntry: Before - isCompletingProfile: \(self.authManager.isCompletingProfile), isAuthenticated: \(self.authManager.isAuthenticated)")
                        
                        withAnimation {
                            self.authManager.isCompletingProfile = false
                            self.authManager.isAuthenticated = true
                        }
                        
                        print("🎯 BioEntry: After - isCompletingProfile: \(self.authManager.isCompletingProfile), isAuthenticated: \(self.authManager.isAuthenticated)")
                        
                        // Double-check authentication state after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            print("🎯 BioEntry: Final check - isCompletingProfile: \(self.authManager.isCompletingProfile), isAuthenticated: \(self.authManager.isAuthenticated)")
                        }
                        
                    case .failure(let error):
                        print("❌ Failed to complete sign up: \(error.localizedDescription)")
                        self.alertMessage = error.localizedDescription
                        self.showAlert = true
                        self.isLoading = false
                    }
                }
            }
        }
        
        // Add a timeout mechanism - force navigation after 10 seconds if nothing happens
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            if self.isLoading {
                print("🎯 BioEntry: Timeout reached - forcing navigation to main app")
                self.isLoading = false
                self.tutorialManager.resetTutorial(for: "onboarding")
                withAnimation {
                    self.authManager.isCompletingProfile = false
                    self.authManager.isAuthenticated = true
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color(red: 1, green: 0.988, blue: 0.929)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    Spacer()
                        .frame(height: 20)
                    
                    Image("DIML_Logo")
                        .resizable()
                        .frame(width: 60, height: 60)
                    
                    Text("Almost there!")
                        .font(.custom("Markazi Text", size: 32))
                        .foregroundColor(Color(red: 0.969, green: 0.757, blue: 0.224))
                    
                    Text("Tell us a bit more about yourself")
                        .font(.custom("Markazi Text", size: 22))
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        showLocationSearch = true
                    }) {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.gray)
                            Text(viewModel.location.isEmpty ? "Add your location" : viewModel.location)
                                .foregroundColor(viewModel.location.isEmpty ? .gray : .black)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.05), radius: 2)
                    }
                    .padding(.horizontal)
                    
                    TextField("School", text: $viewModel.school)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .foregroundColor(.black)
                        .padding(.horizontal)
                    
                    TextField("Interests (separated by commas)", text: $viewModel.interests)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .foregroundColor(.black)
                        .padding(.horizontal)
                    
                    HStack {
                        Button(action: {
                            // Dismiss this view to go back to the previous screen
                            dismiss()
                        }) {
                            Image(systemName: "arrow.left.circle.fill")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            print("🎯 BioEntry: Check button pressed!")
                            saveProfileToFirebase()
                        }) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .frame(width: 40, height: 40)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(Color.mainBlue)
                            }
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 30)
                    
                    Spacer()
                        .frame(height: 60)
                }
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showLocationSearch) {
            if #available(iOS 16.0, *) {
                LocationSearchView(selectedLocation: $viewModel.location)
                    .presentationDetents([.height(400)])
            } else {
                LocationSearchView(selectedLocation: $viewModel.location)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .navigationBarBackButtonHidden(true)
    }
}

struct LocationSearchView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedLocation: String
    @State private var searchText = ""
    @State private var locations: [String] = []
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText)
                    .padding()
                    .onChange(of: searchText) { newValue in
                        searchLocations(query: newValue)
                    }
                
                List(locations, id: \.self) { location in
                    Button(action: {
                        selectedLocation = location
                        dismiss()
                    }) {
                        Text(location)
                            .font(.custom("Markazi Text", size: 20))
                            .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0))
                    }
                }
            }
            .navigationTitle("Choose Location")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func searchLocations(query: String) {
        guard !query.isEmpty else {
            locations = []
            return
        }
        
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = query
        searchRequest.resultTypes = .address
        
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            guard let response = response else {
                locations = []
                return
            }
            
            var uniqueLocations = Set<String>()
            locations = response.mapItems.compactMap { item -> String? in
                guard let city = item.placemark.locality,
                      let state = item.placemark.administrativeArea else {
                    return nil
                }
                let location = "\(city), \(state)"
                guard uniqueLocations.insert(location).inserted else {
                    return nil
                }
                return location
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search location...", text: $text)
                .font(.custom("Markazi Text", size: 20))
                .foregroundColor(.primary)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    NavigationView {
        BioEntryView()
    }
}


