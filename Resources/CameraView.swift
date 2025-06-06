            if permissionGranted {
                ScrollView {
                    VStack(spacing: 16) { // Reduced from 20 to 16
                        // Add top padding
                        Spacer()
                            .frame(height: 10)
                        
                        // Header with camera controls
                        VStack(spacing: 10) { // Reduced from 12 to 10
                            HStack {
                                Button("Cancel") {
                                    isPresented = false
                                }
                                .foregroundColor(.gray)
                                
                                Spacer()
                                
                                VStack(spacing: 4) {
                                    Text("Frame Your Shot")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Text(frameSize.displayName)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Button("🎲") {
                                    frameSize = FrameSize.random
                                }
                                .font(.title2)
                            }
                            
                            // Camera settings row
                            // ... existing code ...
                        }
                        
                        // Instruction text
                        Text("Position your photo in the frame above • Tap 🎲 to change frame size")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.top, 16) // Reduced from 20 to 16
                        
                        // Bottom padding for scroll content
                        Spacer()
                            .frame(height: 60) // Reduced from minHeight: 100 to 60
                    }
                    .padding(.bottom, 20) // Extra bottom padding
                }
            } else {
                // ... existing code ...
            } 