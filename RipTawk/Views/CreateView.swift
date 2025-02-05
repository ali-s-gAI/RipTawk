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
    
    var body: some View {
        NavigationView {
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
    
    var body: some View {
        ZStack {
            CameraPreview(cameraManager: cameraManager)
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: { 
                        print("🎥 [CAMERA] Closing camera view")
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
                        print("🎥 [CAMERA] Stopping recording")
                        cameraManager.stopRecording()
                    } else {
                        print("🎥 [CAMERA] Starting recording")
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
                        } else {
                            // If video was selected, close camera view
                            print("🎥 [CAMERA] Video selected, closing camera")
                            isPresented = false
                        }
                    }
            } else {
                // Fallback if URL is nil - should never happen but better than crashing
                Text("Error loading video preview")
                    .onAppear {
                        print("❌ [CAMERA] Error: recordedVideoURL was nil when trying to show preview")
                        showPreview = false
                        cameraManager.endPreview()
                    }
            }
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
    private var tempVideoURL: URL? // Track the temporary URL
    private var isPreviewingVideo = false // Track if video is being previewed
    
    override init() {
        super.init()
        setupCaptureSession()
        checkPhotoLibraryPermission()
    }
    
    deinit {
        cleanup()
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
    
    private func setupCaptureSession() {
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              let audioDevice = AVCaptureDevice.default(for: .audio),
              let audioInput = try? AVCaptureDeviceInput(device: audioDevice) else {
            print("❌ [CAMERA] Failed to setup capture devices")
            return
        }
        
        if captureSession.canAddInput(videoInput) && captureSession.canAddInput(audioInput) {
            captureSession.addInput(videoInput)
            captureSession.addInput(audioInput)
            print("✅ [CAMERA] Added video and audio inputs")
        }
        
        let videoOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            self.videoOutput = videoOutput
            print("✅ [CAMERA] Added video output")
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
            print("✅ [CAMERA] Started capture session")
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
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("❌ [CAMERA] Error recording video: \(error.localizedDescription)")
            return
        }
        
        // Start preview mode before setting the URL
        startPreview()
        
        // Save to Photos library
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
        } completionHandler: { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ [CAMERA] Video saved to Photos library")
                    self?.recordedVideoURL = outputFileURL
                } else if let error = error {
                    print("❌ [CAMERA] Error saving to Photos: \(error.localizedDescription)")
                    // If there's an error, end preview mode and clean up
                    self?.endPreview()
                }
            }
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        print("✅ [CAMERA] Started recording to: \(fileURL.path)")
    }
}
