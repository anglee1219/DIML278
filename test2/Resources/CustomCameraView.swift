import SwiftUI
import UIKit
import AVFoundation

struct CustomCameraView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let completion: (UIImage) -> Void
    let frame: CGRect

    init(isPresented: Binding<Bool>, frame: CGRect = UIScreen.main.bounds, completion: @escaping (UIImage) -> Void) {
        self._isPresented = isPresented
        self.frame = frame
        self.completion = completion
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        
        // Store the picker reference in coordinator
        context.coordinator.picker = picker
        
        // Add custom overlay view
        let overlayView = UIView(frame: frame)
        overlayView.backgroundColor = .clear
        
        // Create a container view for the capture button that's larger than the button itself
        let containerSize: CGFloat = min(frame.width * 0.3, 100)
        let buttonSize: CGFloat = min(frame.width * 0.2, 70)
        let containerY = frame.height - (containerSize + 20)
        let containerView = UIView(frame: CGRect(x: (frame.width - containerSize) / 2,
                                               y: containerY,
                                               width: containerSize,
                                               height: containerSize))
        containerView.backgroundColor = .clear
        
        // Center the capture button in the container
        let captureButton = UIButton(frame: CGRect(x: (containerSize - buttonSize) / 2,
                                                  y: (containerSize - buttonSize) / 2,
                                                  width: buttonSize,
                                                  height: buttonSize))
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = buttonSize / 2
        captureButton.layer.borderWidth = 3
        captureButton.layer.borderColor = UIColor.gray.cgColor
        
        // Make the entire container tappable
        containerView.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.captureButtonTapped)))
        
        containerView.addSubview(captureButton)
        overlayView.addSubview(containerView)
        picker.cameraOverlayView = overlayView
        
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CustomCameraView
        var picker: UIImagePickerController?

        init(_ parent: CustomCameraView) {
            self.parent = parent
        }

        @objc func captureButtonTapped() {
            print("Capture button tapped")
            if let picker = self.picker {
                print("Taking picture...")
                picker.takePicture()
            } else {
                print("Picker is nil!")
            }
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            print("Image picked")
            if let originalImage = info[.originalImage] as? UIImage,
               let croppedImage = cropToPreviewAspect(image: originalImage) {
                parent.completion(croppedImage)
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("Camera cancelled")
            parent.isPresented = false
        }
        
        private func cropToPreviewAspect(image: UIImage) -> UIImage? {
            // First fix the image orientation
            let fixedImage = fixImageOrientation(image)
            let originalSize = fixedImage.size
            
            // Calculate target aspect ratio based on the frame
            let targetAspect = parent.frame.width / parent.frame.height
            
            let originalAspect = originalSize.width / originalSize.height
            var cropRect: CGRect
            
            if originalAspect > targetAspect {
                // Too wide – crop width
                let newWidth = originalSize.height * targetAspect
                let xOffset = (originalSize.width - newWidth) / 2
                cropRect = CGRect(x: xOffset, y: 0, width: newWidth, height: originalSize.height)
            } else {
                // Too tall – crop height
                let newHeight = originalSize.width / targetAspect
                let yOffset = (originalSize.height - newHeight) / 2
                cropRect = CGRect(x: 0, y: yOffset, width: originalSize.width, height: newHeight)
            }
            
            // Create the cropped image
            if let cgImage = fixedImage.cgImage?.cropping(to: cropRect) {
                let croppedImage = UIImage(cgImage: cgImage, scale: fixedImage.scale, orientation: .up)
                
                // Scale the image to the target size
                let format = UIGraphicsImageRendererFormat()
                format.scale = UIScreen.main.scale
                format.opaque = true
                
                let renderer = UIGraphicsImageRenderer(size: parent.frame.size, format: format)
                return renderer.image { context in
                    croppedImage.draw(in: CGRect(origin: .zero, size: parent.frame.size))
                }
            }
            return nil
        }
        
        private func fixImageOrientation(_ image: UIImage) -> UIImage {
            if image.imageOrientation == .up {
                return image
            }
            
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            image.draw(in: CGRect(origin: .zero, size: image.size))
            let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return normalizedImage ?? image
        }
    }
} 