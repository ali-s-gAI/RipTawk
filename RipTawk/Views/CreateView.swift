import SwiftUI
import AVKit
import AVFoundation
import VideoEditorSDK
import Photos

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
            .fullScreenCover(isPresented: $showCamera) {
                NavigationView {
                    CameraRecordingView(recordedVideoURL: $recordedVideoURL, isPresented: $showCamera)
                        .ignoresSafeArea()
                        .navigationBarHidden(true)
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
    @State private var previewURL: URL?
    
    var body: some View {
        ZStack {
            CameraPreview(cameraManager: cameraManager)
                .ignoresSafeArea()
            
            VStack {
                if !showPreview {
                    HStack {
                        Button(action: { 
                            print("🎥 User cancelled recording session")
                            isPresented = false 
                        }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                        }
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // Record button
                    Button(action: {
                        if cameraManager.isRecording {
                            print("🎥 User stopped recording")
                            cameraManager.stopRecording()
                        } else {
                            print("🎥 User started recording")
                            cameraManager.startRecording()
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
                    .padding(.bottom, 60)
                }
            }
        }
        .onChange(of: cameraManager.recordedVideoURL) { _, url in
            if let url = url {
                print("🎥 Recording saved to: \(url.path)")
                previewURL = url
                showPreview = true
            }
        }
        .overlay {
            if showPreview, let url = previewURL {
                VideoPreviewOverlay(
                    videoURL: url,
                    onRetake: {
                        print("🎥 User chose to retake video")
                        showPreview = false
                        previewURL = nil
                        cameraManager.recordedVideoURL = nil
                    },
                    onContinue: { url in
                        print("🎥 User chose to continue with video")
                        recordedVideoURL = url
                        isPresented = false
                    }
                )
            }
        }
    }
}

struct VideoPreviewOverlay: View {
    let videoURL: URL
    let onRetake: () -> Void
    let onContinue: (URL) -> Void
    
    @State private var player: AVPlayer
    
    init(videoURL: URL, onRetake: @escaping () -> Void, onContinue: @escaping (URL) -> Void) {
        self.videoURL = videoURL
        self.onRetake = onRetake
        self.onContinue = onContinue
        self._player = State(initialValue: AVPlayer(url: videoURL))
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VideoPlayer(player: player)
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: onRetake) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Retake")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                    }
                    
                    Spacer()
                    
                    Button(action: { onContinue(videoURL) }) {
                        HStack {
                            Text("Continue")
                            Image(systemName: "arrow.right")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .onAppear {
            print("🎥 Starting video preview playback")
            player.seek(to: .zero)
            player.play()
            
            // Loop the preview
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                player.seek(to: .zero)
                player.play()
            }
        }
        .onDisappear {
            print("🎥 Stopping video preview playback")
            player.pause()
        }
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
    
    let captureSession = AVCaptureSession()
    var videoOutput: AVCaptureMovieFileOutput?
    
    override init() {
        super.init()
        setupCaptureSession()
    }
    
    private func checkPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                if status == .authorized {
                    print("📱 Photo library access granted")
                    completion(true)
                } else {
                    print("⚠️ Photo library access denied")
                    completion(false)
                }
            }
        }
    }
    
    private func setupCaptureSession() {
        print("🎥 Setting up camera session")
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              let audioDevice = AVCaptureDevice.default(for: .audio),
              let audioInput = try? AVCaptureDeviceInput(device: audioDevice) else {
            print("⚠️ Failed to set up camera inputs")
            return
        }
        
        if captureSession.canAddInput(videoInput) && captureSession.canAddInput(audioInput) {
            captureSession.addInput(videoInput)
            captureSession.addInput(audioInput)
            print("🎥 Camera inputs added successfully")
        }
        
        let videoOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            self.videoOutput = videoOutput
            print("🎥 Camera output configured")
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
            print("🎥 Camera session started")
        }
    }
    
    func startRecording() {
        guard let videoOutput = videoOutput, !isRecording else { return }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        
        print("🎥 Starting recording to: \(tempURL.path)")
        videoOutput.startRecording(to: tempURL, recordingDelegate: self)
        isRecording = true
    }
    
    func stopRecording() {
        guard isRecording else { return }
        print("🎥 Stopping recording")
        videoOutput?.stopRecording()
        isRecording = false
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("⚠️ Recording error: \(error.localizedDescription)")
            return
        }
        
        // Only request photo library access when we need to save
        checkPhotoLibraryPermission { granted in
            if granted {
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
                } completionHandler: { success, error in
                    DispatchQueue.main.async {
                        if success {
                            print("🎥 Video saved to Photos library")
                            self.recordedVideoURL = outputFileURL
                        } else if let error = error {
                            print("⚠️ Error saving to Photos: \(error.localizedDescription)")
                        }
                    }
                }
            } else {
                print("⚠️ Cannot save video: no photo library access")
                // Still set the URL so we can preview the video
                DispatchQueue.main.async {
                    self.recordedVideoURL = outputFileURL
                }
            }
        }
    }
}
