.frame(maxWidth: .infinity) // Ensure consistent full width
.background(backgroundColorView)
.cornerRadius(15)
.padding(.horizontal, 16) // Reduced from 20 to 16 for more space
.onAppear {
    if configuration.fields.isEmpty {
        startCameraBounceAnimation()
    }
} 