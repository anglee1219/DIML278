import SwiftUI

// MARK: - Shared Text Field Style
public struct UnderlineTextFieldStyle: TextFieldStyle {
    public init() {}
    
    public func _body(configuration: TextField<Self._Label>) -> some View {
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
public struct RequirementText: View {
    let text: String
    let isPassed: Bool
    
    public init(text: String, isPassed: Bool) {
        self.text = text
        self.isPassed = isPassed
    }
    
    public var body: some View {
        HStack {
            Image(systemName: isPassed ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isPassed ? Color(red: 0.455, green: 0.506, blue: 0.267) : .gray)
            Text(text)
                .font(.custom("Markazi Text", size: 16))
                .foregroundColor(isPassed ? Color(red: 0.455, green: 0.506, blue: 0.267) : .gray)
        }
    }
}

// MARK: - iOS 18.5 Compatible Button Style
public struct iOS18CompatibleButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.clear) // Explicit clear background
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Extension for easy button styling
public extension Button {
    func iOS18Compatible() -> some View {
        self.buttonStyle(iOS18CompatibleButtonStyle())
    }
} 