import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = "Rebecca"
    @State private var pronouns: String = "she/her"
    @State private var zodiac: String = "scorpio"
    @State private var location: String = "miami, fl"
    @State private var school: String = "stanford"
    @State private var interests: String = "hiking, cooking, & taking pictures"

    var body: some View {
        VStack(spacing: 16) {
            // Header with Cancel and Save
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.orange)
                
                Spacer()
                
                Text("Edit Profile")
                    .font(.custom("Markazi Text", size: 28))
                    .foregroundColor(Color(red: 0.157, green: 0.212, blue: 0.094))
                
                Spacer()
                
                Button("Save Changes") {
                    // Save action here
                    dismiss()
                }
                .foregroundColor(.orange)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            // Profile Image with edit icon
            ZStack(alignment: .topTrailing) {
                Image("Rebecca_Profile")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.orange))
                    .offset(x: 5, y: -5)
            }
            .padding(.top, 10)

            // Editable Fields
            VStack(alignment: .leading, spacing: 20) {
                EditableField(label: "name", text: $name)
                EditableField(label: "pronouns", text: $pronouns)
                EditableField(label: "zodiac sign", text: $zodiac)
                EditableField(label: "location", text: $location)
                EditableField(label: "school", text: $school)
                EditableField(label: "interests", text: $interests)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()
        }
        .background(Color(red: 1, green: 0.988, blue: 0.929).ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

// MARK: - Reusable Field View
struct EditableField: View {
    var label: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(label):")
                .font(.custom("Markazi Text", size: 18))
                .foregroundColor(.black)

            TextField("", text: $text)
                .font(.custom("Markazi Text", size: 18))
                .foregroundColor(.orange)
                .padding(.bottom, 4)

            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.orange.opacity(0.4))
        }
    }
}

// MARK: - Preview
struct EditProfileView_Previews: PreviewProvider {
    static var previews: some View {
        EditProfileView()
    }
}
