import SwiftUI
import AVKit
import AVFoundation
import VideoEditorSDK

struct CreateView: View {
    @State private var showCamera = false
    @State private var recordedVideoURL: URL?
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        NavigationView {
            VStack {
                if let url = recordedVideoURL {
                    NavigationLink(destination: VideoEditorSwiftUIView(video: Video(url: url))) {
                        VStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                            Text("Continue to Editor")
                                .font(.headline)
                        }
                        .padding()
                    }
                } else {
                    Button {
                        showCamera = true
                    } label: {
                        VStack {
                            Image(systemName: "video.fill")
                                .font(.system(size: 50))
                            Text("Record Video")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                        .padding()
                    }
                }
            }
            .navigationTitle("Create")
            .sheet(isPresented: $showCamera) {
                CameraRecordingView(recordedVideoURL: $recordedVideoURL)
                    .ignoresSafeArea()
            }
        }
    }
}

class CameraManager: NSObject, ObservableObject {
    @Published var recordedVideoURL: URL?
    @Published var isRecording = false
    
    let captureSession = AVCaptureSession()
    var videoOutput: AVCaptureMovieFileOutput?
    
    override init() {
        super.init()
        setupCaptureSession()
    }
    
    private func setupCaptureSession() {
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              let audioDevice = AVCaptureDevice.default(for: .audio),
              let audioInput = try? AVCaptureDeviceInput(device: audioDevice) else {
            return
        }
        
        if captureSession.canAddInput(videoInput) && captureSession.canAddInput(audioInput) {
            captureSession.addInput(videoInput)
            captureSession.addInput(audioInput)
        }
        
        let videoOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            self.videoOutput = videoOutput
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    func startRecording() {
        guard let videoOutput = videoOutput, !isRecording else { return }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        
        videoOutput.startRecording(to: tempURL, recordingDelegate: self)
        isRecording = true
    }
    
    func stopRecording() {
        guard isRecording else { return }
        videoOutput?.stopRecording()
        isRecording = false
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if error == nil {
            DispatchQueue.main.async {
                self.recordedVideoURL = outputFileURL
            }
        }
    }
}

struct CameraRecordingView: UIViewRepresentable {
    @Binding var recordedVideoURL: URL?
    @StateObject private var cameraManager = CameraManager()
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView(frame: UIScreen.main.bounds)
        
        // Setup preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.captureSession)
        previewLayer.frame = containerView.bounds
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        containerView.layer.addSublayer(previewLayer)
        
        // Create a container for the record button that sits above the home bar
        let buttonContainer = UIView(frame: CGRect(x: 0, y: 0, width: containerView.bounds.width, height: 140))
        buttonContainer.backgroundColor = .clear
        
        // Create record button with improved styling
        let buttonSize: CGFloat = 84
        let recordButton = UIButton(frame: CGRect(x: 0, y: 0, width: buttonSize, height: buttonSize))
        
        // Center horizontally and position above home bar
        recordButton.center = CGPoint(x: buttonContainer.bounds.midX, 
                                    y: buttonContainer.bounds.height - buttonSize - 30)
        
        // Style the record button
        recordButton.backgroundColor = .clear
        recordButton.layer.cornerRadius = buttonSize / 2
        recordButton.layer.borderWidth = 8
        recordButton.layer.borderColor = UIColor.white.cgColor
        
        // Add inner red circle
        let innerCircle = CALayer()
        innerCircle.frame = CGRect(x: 12, y: 12, width: buttonSize - 24, height: buttonSize - 24)
        innerCircle.cornerRadius = (buttonSize - 24) / 2
        innerCircle.backgroundColor = UIColor.red.cgColor
        recordButton.layer.addSublayer(innerCircle)
        
        // Add tap handler
        recordButton.addTarget(context.coordinator, action: #selector(Coordinator.toggleRecording), for: .touchUpInside)
        
        // Position button container at the bottom of the screen
        buttonContainer.frame.origin.y = containerView.bounds.height - buttonContainer.bounds.height
        buttonContainer.addSubview(recordButton)
        containerView.addSubview(buttonContainer)
        
        // Store references for animation
        context.coordinator.recordButton = recordButton
        context.coordinator.innerCircleLayer = innerCircle
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update recording state UI
        context.coordinator.updateRecordingState(isRecording: cameraManager.isRecording)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: CameraRecordingView
        weak var recordButton: UIButton?
        weak var innerCircleLayer: CALayer?
        
        init(_ parent: CameraRecordingView) {
            self.parent = parent
        }
        
        @objc func toggleRecording() {
            // Add haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            if parent.cameraManager.isRecording {
                parent.cameraManager.stopRecording()
            } else {
                parent.cameraManager.startRecording()
            }
            
            // Update UI immediately for better responsiveness
            updateRecordingState(isRecording: !parent.cameraManager.isRecording)
        }
        
        func updateRecordingState(isRecording: Bool) {
            guard let button = recordButton,
                  let innerCircle = innerCircleLayer else { return }
            
            UIView.animate(withDuration: 0.3) {
                if isRecording {
                    // Recording state: square shape
                    innerCircle.cornerRadius = 4
                    let inset: CGFloat = 24
                    innerCircle.frame = CGRect(x: inset,
                                            y: inset,
                                            width: button.bounds.width - (inset * 2),
                                            height: button.bounds.height - (inset * 2))
                } else {
                    // Not recording state: circle shape
                    let inset: CGFloat = 12
                    innerCircle.cornerRadius = (button.bounds.width - (inset * 2)) / 2
                    innerCircle.frame = CGRect(x: inset,
                                            y: inset,
                                            width: button.bounds.width - (inset * 2),
                                            height: button.bounds.height - (inset * 2))
                }
            }
        }
    }
} 
