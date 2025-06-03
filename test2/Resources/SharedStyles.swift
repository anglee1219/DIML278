import SwiftUI

// MARK: - Shared Text Field Style
struct UnderlineTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        VStack {
            configuration
                .font(.custom("Markazi Text", size: 18))
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.3))
        }
    }
}

// MARK: - Shared Requirement Text Component
struct RequirementText: View {
    let text: String
    let isPassed: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isPassed ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isPassed ? Color(red: 0.455, green: 0.506, blue: 0.267) : .gray)
            Text(text)
                .font(.custom("Markazi Text", size: 16))
                .foregroundColor(isPassed ? Color(red: 0.455, green: 0.506, blue: 0.267) : .gray)
        }
    }
} 