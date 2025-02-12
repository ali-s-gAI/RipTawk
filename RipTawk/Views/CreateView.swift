import SwiftUI
import AVKit
import AVFoundation
import VideoEditorSDK
import Photos

struct CreateView: View {
    @State private var showCamera = false
    @State private var recordedVideoURL: URL?
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var projectManager = ProjectManager()
    @State private var showEditor = false
    
    var body: some View {
        NavigationStack {
            VStack {
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
            .navigationTitle("Create")
            .fullScreenCover(isPresented: $showEditor) {
                if let url = recordedVideoURL {
                    VideoEditorSwiftUIView(video: url)
                        .overlay(alignment: .topLeading) {
                            Button {
                                showEditor = false
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                                    .padding()
                            }
                        }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraRecordingView(recordedVideoURL: $recordedVideoURL, isPresented: $showCamera)
                    .ignoresSafeArea()
                    .onChange(of: recordedVideoURL) { _, url in
                        if url != nil {
                            showCamera = false
                            showEditor = true
                        }
                    }
            }
        }
    }
}

struct CameraRecordingView: View {
    @Binding var recordedVideoURL: URL?
    @Binding var isPresented: Bool
    @StateObject private var cameraManager = CameraManager()
    @State private var showPreview = false
    @State private var timeElapsed: TimeInterval = 0
    @State private var timer: Timer?
    private let maxRecordingTime: TimeInterval = 60 // 1 minute
    
    var body: some View {
        ZStack {
            CameraPreview(cameraManager: cameraManager)
                .ignoresSafeArea()
            
            // Overlay controls
            VStack {
                // Top bar with close and flip camera buttons
                HStack {
                    Button(action: { 
                        print("🎥 [CAMERA] Closing camera view")
                        cameraManager.stopCaptureSession()
                        isPresented = false 
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Timer display
                    Text(timeString(from: timeElapsed))
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    // Flip camera button
                    Button(action: {
                        cameraManager.switchCamera()
                    }) {
                        Image(systemName: "camera.rotate")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                .padding(.top, 60)
                
                Spacer()
                
                // Record button
                Button(action: {
                    if cameraManager.isRecording {
                        print("🎥 [CAMERA] Stopping recording")
                        stopRecording()
                    } else {
                        print("🎥 [CAMERA] Starting recording")
                        startRecording()
                    }
                }) {
                    ZStack {
                        Circle()
                            .strokeBorder(.white, lineWidth: 8)
                            .frame(width: 84, height: 84)
                        
                        if cameraManager.isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.red)
                                .frame(width: 36, height: 36)
                        } else {
                            Circle()
                                .fill(.red)
                                .frame(width: 60, height: 60)
                        }
                    }
                }
                .disabled(timeElapsed >= maxRecordingTime)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            print("🎥 [CAMERA] View appeared, starting capture session")
            cameraManager.startCaptureSession()
        }
        .onDisappear {
            print("🎥 [CAMERA] View disappeared, stopping capture session")
            stopRecording()
            cameraManager.stopCaptureSession()
        }
        .onChange(of: cameraManager.recordedVideoURL) { _, url in
            if let url = url {
                print("🎥 [CAMERA] Recording completed, URL: \(url.path)")
                showPreview = true
            }
        }
        .fullScreenCover(isPresented: $showPreview) {
            if let url = cameraManager.recordedVideoURL {
                VideoPreviewView(
                    videoURL: url,
                    isPresented: $showPreview,
                    recordedVideoURL: $recordedVideoURL
                )
                    .onDisappear {
                        if recordedVideoURL == nil {
                            // If no video was selected (i.e., user hit retake), stay on camera
                            print("🎥 [CAMERA] User chose to retake, staying on camera")
                            cameraManager.endPreview()
                            resetTimer()
                        } else {
                            // If video was selected, close camera view
                            print("🎥 [CAMERA] Video selected, closing camera")
                            isPresented = false
                        }
                    }
            } else {
                Text("Error loading video preview")
                    .onAppear {
                        print("❌ [CAMERA] Error: recordedVideoURL was nil when trying to show preview")
                        showPreview = false
                        cameraManager.endPreview()
                    }
            }
        }
    }
    
    private func startRecording() {
        cameraManager.startRecording()
        startTimer()
    }
    
    private func stopRecording() {
        cameraManager.stopRecording()
        stopTimer()
    }
    
    private func startTimer() {
        resetTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if timeElapsed < maxRecordingTime {
                timeElapsed += 0.1
            } else {
                stopRecording()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func resetTimer() {
        stopTimer()
        timeElapsed = 0
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        let tenths = Int((timeInterval * 10).truncatingRemainder(dividingBy: 10))
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

struct CameraPreview: UIViewRepresentable {
    let cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

class CameraManager: NSObject, ObservableObject {
    @Published var recordedVideoURL: URL?
    @Published var isRecording = false
    @Published private(set) var isSetup = false
    
    let captureSession = AVCaptureSession()
    var videoOutput: AVCaptureMovieFileOutput?
    private var tempVideoURL: URL? // Track the temporary URL
    private var isPreviewingVideo = false // Track if video is being previewed
    private var audioInput: AVCaptureDeviceInput?
    private var currentPosition: AVCaptureDevice.Position = .back // Track current camera position
    
    override init() {
        super.init()
        // Don't setup capture session immediately
        checkPhotoLibraryPermission()
    }
    
    deinit {
        cleanup()
        // Stop capture session when deinited
        captureSession.stopRunning()
    }
    
    private func cleanup() {
        // Only clean up if we're not previewing the video
        guard !isPreviewingVideo else { return }
        
        // Clean up any temporary video file
        if let url = tempVideoURL {
            do {
                try FileManager.default.removeItem(at: url)
                print("🧹 [CAMERA] Cleaned up temporary video file: \(url.path)")
            } catch {
                print("⚠️ [CAMERA] Could not clean up temporary video: \(error)")
            }
        }
        tempVideoURL = nil
    }
    
    private func checkPhotoLibraryPermission() {
        PHPhotoLibrary.requestAuthorization { status in
            if status != .authorized {
                print("❌ [CAMERA] Photos access not authorized")
            }
        }
    }
    
    func startCaptureSession() {
        guard !isSetup else { return }
        setupCaptureSession()
        isSetup = true
    }
    
    func stopCaptureSession() {
        guard isSetup else { return }
        captureSession.stopRunning()
        isSetup = false
        print("✅ [CAMERA] Stopped capture session")
    }
    
    private func setupCaptureSession() {
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              let audioDevice = AVCaptureDevice.default(for: .audio),
              let audioInput = try? AVCaptureDeviceInput(device: audioDevice) else {
            print("❌ [CAMERA] Failed to setup capture devices")
            return
        }
        
        self.audioInput = audioInput
        
        // Set session preset for 720p resolution
        captureSession.sessionPreset = .hd1280x720
        print("✅ [CAMERA] Set session preset to 720p")
        
        if captureSession.canAddInput(videoInput) && captureSession.canAddInput(audioInput) {
            captureSession.addInput(videoInput)
            captureSession.addInput(audioInput)
            print("✅ [CAMERA] Added video and audio inputs")
        }
        
        setupMovieFileOutput()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
            print("✅ [CAMERA] Started capture session")
        }
    }
    
    private func setupMovieFileOutput() {
        // Remove any existing output
        if let existingOutput = videoOutput {
            captureSession.removeOutput(existingOutput)
        }
        
        let movieFileOutput = AVCaptureMovieFileOutput()
        
        if captureSession.canAddOutput(movieFileOutput) {
            captureSession.addOutput(movieFileOutput)
            print("✅ [CAMERA] Added movie file output")
            
            // --- VIDEO SETTINGS ---
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 2_000_000, // 2 Mbps
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoMaxKeyFrameIntervalKey: 30, // Keyframe every 1 second at 30fps
                    AVVideoAllowFrameReorderingKey: false // Reduce encoding latency
                ]
            ]
            
            // Configure video connection
            if let videoConnection = movieFileOutput.connection(with: .video) {
                if movieFileOutput.availableVideoCodecTypes.contains(.h264) {
                    movieFileOutput.setOutputSettings(videoSettings, for: videoConnection)
                    print("✅ [CAMERA] Set video compression settings")
                } else {
                    print("❌ [CAMERA] H.264 codec not available")
                }
            }
            
            self.videoOutput = movieFileOutput
        } else {
            print("❌ [CAMERA] Could not add movie file output to session")
        }
    }
    
    func startRecording() {
        guard let videoOutput = videoOutput, !isRecording else { return }
        
        // Clean up any previous temporary file
        cleanup()
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        
        tempVideoURL = tempURL
        print("🎥 [CAMERA] Starting recording to: \(tempURL.path)")
        
        videoOutput.startRecording(to: tempURL, recordingDelegate: self)
        isRecording = true
    }
    
    func stopRecording() {
        guard isRecording else { return }
        print("🎥 [CAMERA] Stopping recording")
        videoOutput?.stopRecording()
        isRecording = false
    }
    
    // Call this when starting to preview the video
    func startPreview() {
        isPreviewingVideo = true
    }
    
    // Call this when done with the preview
    func endPreview() {
        isPreviewingVideo = false
        cleanup()
    }
    
    func switchCamera() {
        guard !isRecording else { return }
        
        captureSession.beginConfiguration()
        
        // Remove video input
        if let currentVideoInput = captureSession.inputs.first(where: { input in
            guard let input = input as? AVCaptureDeviceInput else { return false }
            return input.device.hasMediaType(.video)
        }) {
            captureSession.removeInput(currentVideoInput)
        }
        
        // Switch position
        currentPosition = currentPosition == .front ? .back : .front
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            print("❌ [CAMERA] Failed to switch camera")
            captureSession.commitConfiguration()
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
            print("✅ [CAMERA] Switched to \(currentPosition == .front ? "front" : "back") camera")
        }
        
        captureSession.commitConfiguration()
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("❌ [CAMERA] Error recording video: \(error.localizedDescription)")
            return
        }
        
        // Start preview mode and set URL without saving to Photos library yet
        startPreview()
        recordedVideoURL = outputFileURL
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("✅ [CAMERA] Started recording to: \(fileURL.path)")
    }
}
