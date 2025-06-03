import SwiftUI

struct ImageAdjustmentView: View {
    let image: UIImage
    let onConfirm: (UIImage) -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background circle to show bounds
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                
                // Image with gestures
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                },
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale *= delta
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                }
                        )
                    )
                    .clipShape(Circle())
                    .onChange(of: scale) { _ in
                        // Ensure minimum zoom level
                        if scale < 1.0 {
                            scale = 1.0
                        }
                    }
                
                // Confirm button overlay
                VStack {
                    Spacer()
                    Button("Set Photo") {
                        let size = CGSize(width: geometry.size.width, height: geometry.size.width)
                        createAdjustedImage(size: size) { adjustedImage in
                            if let adjustedImage = adjustedImage {
                                onConfirm(adjustedImage)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 20)
                    .background(Color.mainBlue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.bottom)
                }
            }
        }
    }
    
    private func createAdjustedImage(size: CGSize, completion: @escaping (UIImage?) -> Void) {
        let renderer = UIGraphicsImageRenderer(size: size)
        let adjustedImage = renderer.image { context in
            // Create circular clipping path
            let circlePath = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
            circlePath.addClip()
            
            // Calculate the scaled image size while maintaining aspect ratio
            let imageAspect = image.size.width / image.size.height
            let viewAspect = size.width / size.height
            
            var drawSize = size
            if imageAspect > viewAspect {
                drawSize.width = size.height * imageAspect
            } else {
                drawSize.height = size.width / imageAspect
            }
            
            // Apply scale
            drawSize.width *= scale
            drawSize.height *= scale
            
            // Center the image and apply offset
            let drawPoint = CGPoint(
                x: (size.width - drawSize.width) * 0.5 + offset.width,
                y: (size.height - drawSize.height) * 0.5 + offset.height
            )
            
            // Draw the image
            image.draw(in: CGRect(origin: drawPoint, size: drawSize))
        }
        completion(adjustedImage)
    }
} 