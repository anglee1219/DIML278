import SwiftUI
import UIKit
import AVFoundation

// Custom Camera View that shows preview in frame
struct InFrameCameraView: View {
    @Binding var isPresented: Bool
    @Binding var capturedImage: UIImage?
    @Binding var capturedFrameSize: FrameSize
    let prompt: String
    @State private var flashMode: AVCaptureDevice.FlashMode = .auto
    @State private var isUltraWide: Bool = false
    @State private var isFrontCamera: Bool = false
    @State private var permissionGranted = false
    @State private var showPermissionAlert = false
    @State private var previewResponse: String = ""
    @State private var frameSize: FrameSize = FrameSize.random
    
    var body: some View {
        ZStack {
            Color(red: 1, green: 0.989, blue: 0.93)
                .ignoresSafeArea()
            
            if permissionGranted {
                VStack(spacing: 20) {
                    // Header with camera controls
                    VStack(spacing: 12) {
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
                        HStack(spacing: 15) {
                            // Flash control
                            Button(action: {
                                switch flashMode {
                                case .off:
                                    flashMode = .auto
                                case .auto:
                                    flashMode = .on
                                case .on:
                                    flashMode = .off
                                @unknown default:
                                    flashMode = .auto
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: flashMode == .off ? "bolt.slash" : flashMode == .auto ? "bolt.badge.a" : "bolt")
                                    Text(flashMode == .off ? "Off" : flashMode == .auto ? "Auto" : "On")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            // Camera flip button
                            Button(action: {
                                isFrontCamera.toggle()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "camera.rotate")
                                    Text(isFrontCamera ? "Front" : "Back")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            // Camera lens selector (only for back camera)
                            if !isFrontCamera {
                                Button(action: {
                                    isUltraWide.toggle()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "camera")
                                        Text(isUltraWide ? "0.5x" : "1x")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .padding()
                    
                    // Reduced top spacer to move camera higher
                    Spacer()
                        .frame(maxHeight: 20)
                    
                    // Camera preview in the yellow frame with prompt and response
                    VStack(alignment: .leading, spacing: 0) {
                        // Prompt text at the top
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Your Assigned Prompt")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(prompt)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                        
                        // Camera preview in the middle with dynamic frame size
                        CameraPreviewView(
                            flashMode: $flashMode,
                            isUltraWide: $isUltraWide,
                            isFrontCamera: $isFrontCamera,
                            frameSize: frameSize
                        ) { image in
                            capturedImage = image
                            capturedFrameSize = frameSize
                            isPresented = false
                        }
                        .frame(height: frameSize.height)
                        .cornerRadius(12)
                        .clipped()
                        .padding(.horizontal, 16)
                        
                        // Response text field at the bottom
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Add your response...")
                                .font(.caption)
                                .foregroundColor(.gray)
                            TextField("e.g., corepower w/ eliza", text: $previewResponse)
                                .font(.body)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                    }
                    .background(Color(red: 1.0, green: 0.95, blue: 0.80))
                    .cornerRadius(15)
                    .padding(.horizontal)
                    
                    // Instruction text
                    Text("Position your photo in the frame above • Tap 🎲 to change frame size")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                    
                    // Larger bottom spacer to push everything up
                    Spacer()
                        .frame(minHeight: 100)
                }
            } else {
                // Permission denied or not granted
                VStack(spacing: 20) {
                    Image(systemName: "camera")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("Camera Access Required")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Please allow camera access to take photos")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                    
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.gray)
                }
                .padding()
            }
        }
        .onAppear {
            checkCameraPermission()
            frameSize = FrameSize.random // Randomize frame size when view appears
        }
        .alert("Camera Access Required", isPresented: $showPermissionAlert) {
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {
                isPresented = false
            }
        } message: {
            Text("Please enable camera access in Settings to take photos.")
        }
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    permissionGranted = granted
                    if !granted {
                        showPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            permissionGranted = false
            showPermissionAlert = true
        @unknown default:
            permissionGranted = false
        }
    }
}

// Camera Preview with capture functionality
struct CameraPreviewView: UIViewControllerRepresentable {
    @Binding var flashMode: AVCaptureDevice.FlashMode
    @Binding var isUltraWide: Bool
    @Binding var isFrontCamera: Bool
    let frameSize: FrameSize
    let onCapture: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onCapture = { [frameSize] image in
            onCapture(image)
        }
        controller.frameSize = frameSize
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        uiViewController.updateFlashMode(flashMode)
        uiViewController.updateCameraLens(isUltraWide: isUltraWide)
        uiViewController.updateCameraPosition(isFrontCamera: isFrontCamera)
        uiViewController.frameSize = frameSize
    }
}

// Custom Camera Controller
class CameraViewController: UIViewController {
    var onCapture: ((UIImage) -> Void)?
    private var captureSession: AVCaptureSession!
    private var photoOutput: AVCapturePhotoOutput!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var captureButton: UIButton!
    private var currentDevice: AVCaptureDevice?
    private var currentInput: AVCaptureDeviceInput?
    private var currentFlashMode: AVCaptureDevice.FlashMode = .auto
    private var currentIsFrontCamera: Bool = false
    private var currentIsUltraWide: Bool = false
    var frameSize: FrameSize = FrameSize.random
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("CameraViewController viewDidLoad")
        setupCamera()
        setupCaptureButton()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("CameraViewController viewDidAppear")
        startSession()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("CameraViewController viewDidDisappear")
        stopSession()
    }
    
    private func setupCamera(isUltraWide: Bool = false, isFrontCamera: Bool = false) {
        print("Setting up camera - isUltraWide: \(isUltraWide), isFrontCamera: \(isFrontCamera)")
        
        if captureSession == nil {
            captureSession = AVCaptureSession()
            captureSession.sessionPreset = .photo
        }
        
        let position: AVCaptureDevice.Position = isFrontCamera ? .front : .back
        
        var camera: AVCaptureDevice?
        
        if isFrontCamera {
            // For front camera, try to get the best available front camera
            camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        } else {
            // For back camera, choose based on ultra-wide setting
            let deviceType: AVCaptureDevice.DeviceType = isUltraWide ? .builtInUltraWideCamera : .builtInWideAngleCamera
            camera = AVCaptureDevice.default(deviceType, for: .video, position: .back)
        }
        
        guard let selectedCamera = camera else {
            print("Failed to get \(isFrontCamera ? "front" : isUltraWide ? "ultra-wide back" : "back") camera, trying fallback")
            // Fallback to any available camera
            if let fallbackCamera = AVCaptureDevice.default(for: .video) {
                currentDevice = fallbackCamera
                setupCameraInput(with: fallbackCamera)
                return
            } else {
                print("Unable to access any camera")
                return
            }
        }
        
        print("Successfully got camera: \(selectedCamera.localizedName) at position: \(selectedCamera.position.rawValue)")
        currentDevice = selectedCamera
        currentIsFrontCamera = isFrontCamera
        currentIsUltraWide = isUltraWide
        setupCameraInput(with: selectedCamera)
    }
    
    private func setupCameraInput(with device: AVCaptureDevice) {
        print("Setting up camera input with device: \(device.localizedName)")
        
        do {
            // Remove existing input if any
            if let existingInput = currentInput {
                print("Removing existing input")
                captureSession.removeInput(existingInput)
            }
            
            let input = try AVCaptureDeviceInput(device: device)
            currentInput = input
            
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                print("Successfully added camera input")
            } else {
                print("Cannot add camera input")
            }
            
            // Setup photo output if not already done
            if photoOutput == nil {
                photoOutput = AVCapturePhotoOutput()
                if captureSession.canAddOutput(photoOutput) {
                    captureSession.addOutput(photoOutput)
                    print("Successfully added photo output")
                } else {
                    print("Cannot add photo output")
                }
            }
            
            // Setup preview layer if not already done
            if previewLayer == nil {
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.frame = view.bounds
                view.layer.insertSublayer(previewLayer, at: 0)
                print("Successfully added preview layer")
            }
            
        } catch {
            print("Error setting up camera: \(error)")
        }
    }
    
    private func setupCaptureButton() {
        print("Setting up capture button")
        captureButton = UIButton(type: .system)
        captureButton.setTitle("📸", for: .normal)
        captureButton.titleLabel?.font = UIFont.systemFont(ofSize: 30)
        captureButton.backgroundColor = UIColor.systemBlue
        captureButton.layer.cornerRadius = 30
        captureButton.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        
        view.addSubview(captureButton)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            captureButton.widthAnchor.constraint(equalToConstant: 60),
            captureButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    func updateFlashMode(_ flashMode: AVCaptureDevice.FlashMode) {
        print("Updating flash mode to: \(flashMode)")
        currentFlashMode = flashMode
    }
    
    func updateCameraLens(isUltraWide: Bool) {
        print("Updating camera lens - isUltraWide: \(isUltraWide)")
        guard captureSession != nil else { 
            print("Capture session is nil")
            return 
        }
        
        // Only update if we're on back camera and the setting actually changed
        if !currentIsFrontCamera && currentIsUltraWide != isUltraWide {
            captureSession.beginConfiguration()
            setupCamera(isUltraWide: isUltraWide, isFrontCamera: currentIsFrontCamera)
            captureSession.commitConfiguration()
        }
    }
    
    func updateCameraPosition(isFrontCamera: Bool) {
        print("Updating camera position - isFrontCamera: \(isFrontCamera)")
        guard captureSession != nil else { 
            print("Capture session is nil")
            return 
        }
        
        // Only update if the position actually changed
        if currentIsFrontCamera != isFrontCamera {
            captureSession.beginConfiguration()
            // When switching to front camera, always use standard lens (no ultra-wide for front)
            setupCamera(isUltraWide: isFrontCamera ? false : currentIsUltraWide, isFrontCamera: isFrontCamera)
            captureSession.commitConfiguration()
        }
    }
    
    @objc private func capturePhoto() {
        print("Capture photo button tapped")
        guard photoOutput != nil else {
            print("Photo output is nil")
            return
        }
        
        let settings = AVCapturePhotoSettings()
        
        // Set flash mode (front camera usually doesn't have flash)
        if currentDevice?.hasFlash == true && !currentIsFrontCamera {
            settings.flashMode = currentFlashMode
            print("Setting flash mode to: \(currentFlashMode)")
        } else {
            print("Device has no flash or is front camera")
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    private func startSession() {
        guard captureSession != nil else {
            print("Cannot start session - captureSession is nil")
            return
        }
        
        if !captureSession.isRunning {
            print("Starting capture session")
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
                DispatchQueue.main.async {
                    print("Capture session started")
                }
            }
        }
    }
    
    private func stopSession() {
        guard captureSession != nil else { return }
        
        if captureSession.isRunning {
            print("Stopping capture session")
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.stopRunning()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Error capturing photo: \(error?.localizedDescription ?? "Unknown error")")
            return
        }
        
        // Process the image (fix orientation and crop)
        let processedImage = processImageForDisplay(image)
        onCapture?(processedImage)
    }
    
    private func processImageForDisplay(_ image: UIImage) -> UIImage {
        // Fix orientation first
        let orientationFixedImage = fixImageOrientation(image)
        
        // Get the minimum dimension to create a square
        let minDimension = min(orientationFixedImage.size.width, orientationFixedImage.size.height)
        
        // Create a square crop rect
        let cropRect = CGRect(
            x: (orientationFixedImage.size.width - minDimension) / 2,
            y: (orientationFixedImage.size.height - minDimension) / 2,
            width: minDimension,
            height: minDimension
        )
        
        // Crop the image to a square
        if let croppedImage = orientationFixedImage.cgImage?.cropping(to: cropRect) {
            return UIImage(cgImage: croppedImage)
        }
        
        return orientationFixedImage
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

// Legacy CameraView for backward compatibility
struct CameraView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let completion: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                let processedImage = processImageForDisplay(image)
                parent.completion(processedImage)
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
        
        private func processImageForDisplay(_ image: UIImage) -> UIImage {
            let orientationFixedImage = fixImageOrientation(image)
            let minDimension = min(orientationFixedImage.size.width, orientationFixedImage.size.height)
            let cropRect = CGRect(
                x: (orientationFixedImage.size.width - minDimension) / 2,
                y: (orientationFixedImage.size.height - minDimension) / 2,
                width: minDimension,
                height: minDimension
            )
            
            if let croppedImage = orientationFixedImage.cgImage?.cropping(to: cropRect) {
                return UIImage(cgImage: croppedImage)
            }
            return orientationFixedImage
        }
        
        private func fixImageOrientation(_ image: UIImage) -> UIImage {
            if image.imageOrientation == .up { return image }
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            image.draw(in: CGRect(origin: .zero, size: image.size))
            let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return normalizedImage ?? image
        }
    }
} 