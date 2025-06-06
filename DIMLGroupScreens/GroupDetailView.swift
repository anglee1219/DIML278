                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 12) { // Reduced spacing
                                // Add top padding
                                Spacer()
                                    .frame(height: 10)
                                
                                if let image = capturedImage {
                                    capturedImageView(image: image)
                                        .transition(.opacity)
                                } else if !currentPrompt.isEmpty {
                                    // ... existing code ...
                                }
                                
                                // Entries list
                                LazyVStack(spacing: 12) { // Reduced from default spacing
                                    ForEach(filteredEntries, id: \.id) { entry in
                                        entryView(entry: entry)
                                    }
                                }
                                
                                // Add bottom padding for scroll content
                                Spacer()
                                    .frame(height: 60)
                            }
                            .padding(.bottom, 20) // Extra bottom padding
                        }
                    }
                } 