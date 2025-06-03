import SwiftUI
import MapKit
import FirebaseFirestore
import FirebaseAuth

struct BioEntryView: View {
    @StateObject private var viewModel = ProfileViewModel.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showLocationSearch = false
    @State private var navigateToNext = false
    @State private var navigateBack = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    private func saveProfileToFirebase() {
        guard let currentUser = Auth.auth().currentUser else {
            alertMessage = "No authenticated user found"
            showAlert = true
            return
        }
        
        isLoading = true
        
        // Get stored credentials and user data
        guard let email = UserDefaults.standard.string(forKey: "pending_email"),
              let password = UserDefaults.standard.string(forKey: "pending_password") else {
            alertMessage = "Missing credentials. Please try creating your account again."
            showAlert = true
            isLoading = false
            return
        }
        
        // Get the zodiac sign and username from UserDefaults
        let zodiacSign = UserDefaults.standard.string(forKey: "profile_zodiac") ?? ""
        let username = UserDefaults.standard.string(forKey: "profile_username") ?? ""
        let name = UserDefaults.standard.string(forKey: "profile_name") ?? username
        
        // Create profile data dictionary
        let profileData: [String: Any] = [
            "uid": currentUser.uid,
            "email": email,
            "username": username,
            "name": name,
            "location": viewModel.location,
            "school": viewModel.school,
            "interests": viewModel.interests,
            "zodiacSign": zodiacSign,
            "createdAt": FieldValue.serverTimestamp(),
            "lastUpdated": FieldValue.serverTimestamp()
        ]
        
        // Save to Firestore using setData with merge
        let db = Firestore.firestore()
        db.collection("users").document(currentUser.uid).setData(profileData, merge: true) { error in
            if let error = error {
                DispatchQueue.main.async {
                    alertMessage = error.localizedDescription
                    showAlert = true
                    isLoading = false
                }
                return
            }
            
            print("Successfully saved profile data to Firestore")
            // Complete the sign up process
            authManager.completeSignUp { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("Successfully completed sign up")
                        isLoading = false
                        // Reset the completion flag to trigger app state change
                        authManager.isCompletingProfile = false
                        authManager.isAuthenticated = true
                    case .failure(let error):
                        print("Failed to complete sign up: \(error.localizedDescription)")
                        alertMessage = error.localizedDescription
                        showAlert = true
                        isLoading = false
                    }
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color(red: 1, green: 0.988, blue: 0.929)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Logo at the top
                Image("DIML_Logo")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .padding(.top, 40)
                
                Text("Almost there!")
                    .font(.custom("Markazi Text", size: 36))
                    .foregroundColor(Color(red: 0.969, green: 0.757, blue: 0.224))
                
                Text("Tell us a bit more about yourself")
                    .font(.custom("Markazi Text", size: 24))
                    .foregroundColor(.gray)
                
                // Location Button
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
                
                // School TextField
                TextField("School", text: $viewModel.school)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                // Interests TextField
                TextField("Interests (separated by commas)", text: $viewModel.interests)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Spacer()
                
                // Navigation Links
                NavigationLink(destination: BirthdayEntryView(), isActive: $navigateBack) { EmptyView() }
                
                // Navigation arrows
                HStack {
                    Button(action: {
                        navigateBack = true
                    }) {
                        Image(systemName: "arrow.left.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button(action: {
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
                .padding(.bottom, 40)
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
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
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
                .foregroundColor(Color(red: 0.722, green: 0.369, blue: 0))
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


