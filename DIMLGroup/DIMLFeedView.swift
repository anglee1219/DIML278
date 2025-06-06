                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 12) { // Reduced from 16 to 12
                                // Add top padding
                                Spacer()
                                    .frame(height: 10)
                                
                                if let image = capturedImage {
                                    // ... existing code ...
                                }
                                
                                // Add bottom padding for scroll content
                                Spacer()
                                    .frame(height: 40)
                            }
                            .padding(.bottom, 20) // Extra bottom padding
                        }
                    }
                } 