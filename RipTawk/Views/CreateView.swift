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
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        let recordButton = UIButton(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        recordButton.center = CGPoint(x: view.bounds.midX, y: view.bounds.maxY - 100)
        recordButton.backgroundColor = .red
        recordButton.layer.cornerRadius = 40
        recordButton.addTarget(context.coordinator, action: #selector(Coordinator.toggleRecording), for: .touchUpInside)
        view.addSubview(recordButton)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update UI if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: CameraRecordingView
        
        init(_ parent: CameraRecordingView) {
            self.parent = parent
        }
        
        @objc func toggleRecording() {
            if parent.cameraManager.isRecording {
                parent.cameraManager.stopRecording()
            } else {
                parent.cameraManager.startRecording()
            }
        }
    }
} 
